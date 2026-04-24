# Iceberg Datalake — AWS S3 Tables + ECS + Airflow

Projeto de portfólio em Engenharia de Dados usando arquitetura medalhão com API pública, Amazon S3 Tables, Apache Iceberg, Apache Airflow, ECS/Fargate, DuckDB e dbt.

> Fonte pública utilizada: Open-Meteo Historical Weather API.

## Objetivo

Construir um datalake analítico em arquitetura medalhão:

- **Bronze**: dados brutos vindos de uma API pública.
- **Silver**: dados limpos, tipados, deduplicados e enriquecidos.
- **Gold**: agregações prontas para consumo analítico.

A arquitetura foi desenhada para separar claramente orquestração e processamento:

- **Airflow** apenas agenda e orquestra.
- **ECS/Fargate** executa o processamento.
- **DockerHub** armazena a imagem usada pela task do ECS.
- **DuckDB + dbt** rodam dentro do container executado no ECS.
- **S3 Tables** é o armazenamento lakehouse baseado em Apache Iceberg.

## Stack

| Camada | Ferramentas |
|---|---|
| Fonte pública | Open-Meteo API |
| Orquestração | Apache Airflow |
| Execução do processamento | Amazon ECS/Fargate |
| Registry da imagem | DockerHub |
| Transformação | dbt |
| Engine embarcada no container | DuckDB |
| Lakehouse | Amazon S3 Tables / Apache Iceberg |
| Artefatos operacionais | Amazon S3 |
| Query engine | Amazon Athena |
| Logs | Amazon CloudWatch Logs |
| Infraestrutura | Terraform |

## Arquitetura

```text
                 ┌──────────────────────┐
                 │ Open-Meteo Public API │
                 └───────────┬──────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│ Apache Airflow                                               │
│ DAG: iceberg_medallion_pipeline                              │
│ Operator: EcsRunTaskOperator                                 │
└───────────────────────┬─────────────────────────────────────┘
                        │ run task
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ Amazon ECS / Fargate                                         │
│ Pull image: DockerHub                                        │
│ Command: python -m app.pipeline                              │
│                                                             │
│ Steps inside container:                                      │
│  1. ingest Open-Meteo API                                    │
│  2. save raw JSONL to S3 artifacts bucket                    │
│  3. execute dbt run                                          │
│  4. execute dbt test                                         │
│  5. process data with DuckDB                                 │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ Amazon S3 Tables / Apache Iceberg                            │
│  - bronze namespace                                          │
│  - silver namespace                                          │
│  - gold namespace                                            │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
                 ┌──────────────┐
                 │ Amazon Athena │
                 └──────────────┘
```

## Estrutura

```text
.
├── dags/
│   └── iceberg_medallion_pipeline.py      # Airflow DAG com EcsRunTaskOperator
├── dbt/
│   ├── dbt_project.yml
│   ├── profiles.yml
│   └── models/
│       ├── bronze/
│       ├── silver/
│       └── gold/
├── docker/
│   ├── Dockerfile.airflow                 # Imagem apenas para Airflow
│   └── requirements.txt
├── processing/
│   ├── Dockerfile                         # Imagem publicada no DockerHub
│   ├── requirements.txt
│   └── app/
│       └── pipeline.py                    # Entrypoint executado pelo ECS
├── infra/
│   └── terraform/aws/                     # S3 Tables, ECS, IAM, Athena
├── scripts/
│   ├── ingest_open_meteo.py
│   └── query_gold.py
├── docker-compose.yml                     # Airflow local para orquestrar ECS
├── .env.example
└── README.md
```

## Como publicar a imagem de processamento no DockerHub

Substitua `gabrielrosalino` pelo seu namespace do DockerHub, se necessário:

```bash
docker build \
  -f processing/Dockerfile \
  -t gabrielrosalino/iceberg-datalake-processing:latest \
  .

docker push gabrielrosalino/iceberg-datalake-processing:latest
```

O DockerHub não executa nenhum processamento. Ele apenas armazena a imagem. Quem executa é o ECS/Fargate.

## Como provisionar a infraestrutura AWS

```bash
cd infra/terraform/aws
terraform init
terraform plan \
  -var="vpc_id=vpc-xxxxxxxx" \
  -var='subnet_ids=["subnet-xxxxxxxx","subnet-yyyyyyyy"]' \
  -var="processing_image=gabrielrosalino/iceberg-datalake-processing:latest"
terraform apply \
  -var="vpc_id=vpc-xxxxxxxx" \
  -var='subnet_ids=["subnet-xxxxxxxx","subnet-yyyyyyyy"]' \
  -var="processing_image=gabrielrosalino/iceberg-datalake-processing:latest"
```

O Terraform cria:

- S3 Tables bucket para tabelas Iceberg.
- Namespaces `bronze`, `silver` e `gold`.
- Bucket S3 comum para payloads brutos, artefatos e resultados do Athena.
- ECS Cluster.
- ECS Task Definition Fargate.
- IAM roles e policies para execução.
- CloudWatch Log Group.
- Athena Workgroup.

Após o `terraform apply`, use os outputs para preencher o `.env` do Airflow.

## Como executar o Airflow localmente

Copie as variáveis de ambiente:

```bash
cp .env.example .env
```

Edite no `.env`:

```text
PROCESSING_IMAGE
ECS_CLUSTER_NAME
ECS_TASK_DEFINITION
ECS_CONTAINER_NAME
ECS_SUBNET_IDS
ECS_SECURITY_GROUP_IDS
S3_TABLE_BUCKET_NAME
S3_ARTIFACTS_BUCKET
```

Suba o Airflow:

```bash
docker compose up --build
```

Acesse:

```text
http://localhost:8080
```

Credenciais padrão:

```text
airflow / airflow
```

No Airflow, configure a connection `aws_default` ou disponibilize credenciais AWS para o container do Airflow.

Depois execute a DAG:

```text
iceberg_medallion_pipeline
```

## Modelos dbt

### Bronze

`bronze_open_meteo_daily`

Lê os arquivos JSONL brutos gerados a partir da API pública Open-Meteo.

### Silver

`silver_daily_weather`

Aplica:

- tipagem
- deduplicação por `weather_date` + `location_id`
- classificação de precipitação
- padronização de colunas

### Gold

`gold_weather_by_city`

Agrega métricas por cidade:

- temperatura média
- temperatura máxima
- temperatura mínima
- precipitação acumulada
- dias secos
- dias com chuva forte

`gold_weather_daily_state`

Agrega métricas diárias por estado:

- temperatura média diária
- precipitação diária total
- velocidade máxima de vento
- quantidade de localidades secas/chuvosas

## Observação importante sobre DuckDB + S3 Tables

A arquitetura-alvo usa S3 Tables como camada Iceberg. O container de processamento já está isolado para rodar no ECS e receber as variáveis de S3 Tables.

Dependendo da maturidade dos conectores disponíveis no runtime escolhido, a escrita Iceberg em S3 Tables pode ser evoluída para uma destas opções:

- DuckDB para preparação/ELT local dentro do container e Athena para materialização Iceberg em S3 Tables.
- dbt-athena para materializações diretamente no Athena/S3 Tables.
- Spark ou Trino dentro de ECS/EMR/EKS para escrita Iceberg completa.

O desenho atual deixa a separação correta para produção: Airflow orquestra, ECS processa, DockerHub armazena a imagem e S3 Tables guarda as tabelas Iceberg.

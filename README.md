# Iceberg Datalake — Medallion Architecture

Projeto de portfólio em Engenharia de Dados usando arquitetura medalhão, API pública, Apache Airflow, Astronomer Cosmos, dbt, DuckDB, Apache Iceberg e AWS como provedor cloud.

> Fonte pública utilizada: Open-Meteo Historical Weather API.

## Objetivo

Construir um datalake analítico com arquitetura medalhão:

- **Bronze**: dados brutos vindos de uma API pública.
- **Silver**: dados limpos, tipados, deduplicados e enriquecidos.
- **Gold**: agregações prontas para consumo analítico.

O domínio escolhido é clima histórico diário de capitais brasileiras, permitindo responder perguntas como:

- Qual cidade teve maior temperatura média no período?
- Quais estados tiveram maior volume de precipitação?
- Quantos dias secos ou chuvosos ocorreram por cidade?
- Como consultar modelos Gold com DuckDB ou Athena?

## Stack

| Camada | Ferramentas |
|---|---|
| Ingestão | Python, Requests, Pandas, Open-Meteo API |
| Orquestração | Apache Airflow |
| dbt no Airflow | Astronomer Cosmos |
| Transformação | dbt |
| Engine local | DuckDB |
| Formato lakehouse alvo | Apache Iceberg |
| Object storage local | MinIO |
| Catálogo local | Project Nessie |
| Cloud provider | AWS |
| Cloud storage | Amazon S3 |
| Catálogo cloud | AWS Glue Data Catalog |
| Query engine cloud | Amazon Athena / Trino |
| Infraestrutura | Terraform |
| Containers | Docker Compose |

## Arquitetura

```text
Open-Meteo API
     │
     ▼
Python ingestion
     │
     ▼
data/raw/open_meteo/*.jsonl
     │
     ▼
Airflow DAG
     │
     ▼
Cosmos DbtTaskGroup
     │
     ├── Bronze: bronze_open_meteo_daily
     ├── Silver: silver_daily_weather
     └── Gold: gold_weather_by_city / gold_weather_daily_state
     │
     ▼
DuckDB local / S3 + Glue + Athena na AWS
```

## Estrutura

```text
.
├── dags/
│   └── iceberg_medallion_pipeline.py
├── dbt/
│   ├── dbt_project.yml
│   ├── profiles.yml
│   └── models/
│       ├── bronze/
│       ├── silver/
│       └── gold/
├── docker/
│   ├── Dockerfile.airflow
│   └── requirements.txt
├── infra/
│   └── terraform/aws/
├── scripts/
│   ├── ingest_open_meteo.py
│   └── query_gold.py
├── data/
│   ├── raw/
│   ├── warehouse/
│   └── duckdb/
├── docker-compose.yml
├── .env.example
└── README.md
```

## Como executar localmente

Copie as variáveis de ambiente:

```bash
cp .env.example .env
```

Suba o ambiente:

```bash
docker compose up --build
```

Acesse os serviços:

```text
Airflow: http://localhost:8080
MinIO:   http://localhost:9001
Nessie:  http://localhost:19120
```

Credenciais locais:

```text
Airflow: airflow / airflow
MinIO: minioadmin / minioadmin
```

No Airflow, ative e execute a DAG:

```text
iceberg_medallion_pipeline
```

## Executando sem Airflow

Também é possível executar os passos manualmente dentro do container do Airflow:

```bash
python /opt/airflow/scripts/ingest_open_meteo.py
cd /opt/airflow/dbt
dbt run
dbt test
```

Para consultar as tabelas Gold:

```bash
python /opt/airflow/scripts/query_gold.py
```

## Modelos dbt

### Bronze

`bronze_open_meteo_daily`

Lê os arquivos JSONL brutos gerados a partir da API pública Open-Meteo e adiciona estrutura inicial para a camada Bronze.

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

## Sobre Iceberg

Este projeto foi estruturado para demonstrar uma arquitetura lakehouse com Apache Iceberg. A execução local usa DuckDB para simplificar o desenvolvimento e reduzir dependências pesadas.

Para uso produtivo com Iceberg completo, a evolução recomendada é:

```text
Airflow + Cosmos
     │
     ├── Spark / Trino / Athena Iceberg
     ├── S3 como storage
     ├── Glue Data Catalog ou Nessie REST Catalog
     └── dbt-trino / dbt-athena / dbt-spark
```

## AWS

A pasta `infra/terraform/aws` cria uma base cloud com:

- bucket S3 versionado e criptografado
- bloqueio de acesso público
- Glue databases para Bronze, Silver e Gold
- Athena Workgroup para consultas analíticas

Executar Terraform:

```bash
cd infra/terraform/aws
terraform init
terraform plan
terraform apply
```

## Próximas melhorias

- Adicionar Spark para escrita Iceberg local completa.
- Adicionar Trino conectado ao MinIO + Nessie.
- Adicionar dbt-trino para modelos Iceberg reais.
- Criar CI/CD com GitHub Actions.
- Adicionar OpenLineage + Marquez para observabilidade.
- Adicionar Great Expectations ou Soda para qualidade de dados.

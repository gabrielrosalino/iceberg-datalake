from __future__ import annotations

import os
from datetime import datetime

from airflow import DAG
from airflow.providers.amazon.aws.operators.ecs import EcsRunTaskOperator


def _csv_env(name: str) -> list[str]:
    value = os.getenv(name, "")
    return [item.strip() for item in value.split(",") if item.strip()]


AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
ECS_CLUSTER_NAME = os.getenv("ECS_CLUSTER_NAME", "iceberg-datalake-dev-cluster")
ECS_TASK_DEFINITION = os.getenv("ECS_TASK_DEFINITION", "iceberg-datalake-dev-processing")
ECS_CONTAINER_NAME = os.getenv("ECS_CONTAINER_NAME", "processing")
ECS_LAUNCH_TYPE = os.getenv("ECS_LAUNCH_TYPE", "FARGATE")
ECS_ASSIGN_PUBLIC_IP = os.getenv("ECS_ASSIGN_PUBLIC_IP", "ENABLED")

PROCESSING_ENVIRONMENT = [
    {"name": "AWS_REGION", "value": AWS_REGION},
    {"name": "S3_TABLE_BUCKET_NAME", "value": os.getenv("S3_TABLE_BUCKET_NAME", "iceberg-datalake-dev-tables")},
    {"name": "S3_TABLE_WAREHOUSE", "value": os.getenv("S3_TABLE_WAREHOUSE", "s3tables://iceberg-datalake-dev-tables")},
    {"name": "S3_TABLE_NAMESPACE_BRONZE", "value": os.getenv("S3_TABLE_NAMESPACE_BRONZE", "bronze")},
    {"name": "S3_TABLE_NAMESPACE_SILVER", "value": os.getenv("S3_TABLE_NAMESPACE_SILVER", "silver")},
    {"name": "S3_TABLE_NAMESPACE_GOLD", "value": os.getenv("S3_TABLE_NAMESPACE_GOLD", "gold")},
    {"name": "S3_ARTIFACTS_BUCKET", "value": os.getenv("S3_ARTIFACTS_BUCKET", "iceberg-datalake-dev-artifacts")},
    {"name": "RAW_DATA_PREFIX", "value": os.getenv("RAW_DATA_PREFIX", "raw/open_meteo")},
    {"name": "ATHENA_RESULTS_PREFIX", "value": os.getenv("ATHENA_RESULTS_PREFIX", "athena-results")},
    {"name": "DUCKDB_DATABASE", "value": os.getenv("DUCKDB_DATABASE", "/app/data/duckdb/lakehouse.duckdb")},
    {"name": "DBT_PROJECT_DIR", "value": os.getenv("DBT_PROJECT_DIR", "/app/dbt")},
    {"name": "DBT_PROFILES_DIR", "value": os.getenv("DBT_PROFILES_DIR", "/app/dbt")},
    {"name": "OPEN_METEO_DAYS_BACK", "value": os.getenv("OPEN_METEO_DAYS_BACK", "30")},
]

with DAG(
    dag_id="iceberg_medallion_pipeline",
    description="Orchestrates an ECS/Fargate processing task that runs API ingestion, DuckDB and dbt for a S3 Tables medallion lakehouse.",
    start_date=datetime(2026, 1, 1),
    schedule="@daily",
    catchup=False,
    tags=["aws", "ecs", "s3-tables", "iceberg", "duckdb", "dbt", "medallion"],
) as dag:
    run_medallion_processing = EcsRunTaskOperator(
        task_id="run_medallion_processing_on_ecs",
        aws_conn_id="aws_default",
        region_name=AWS_REGION,
        cluster=ECS_CLUSTER_NAME,
        task_definition=ECS_TASK_DEFINITION,
        launch_type=ECS_LAUNCH_TYPE,
        wait_for_completion=True,
        awslogs_group=f"/ecs/{ECS_TASK_DEFINITION}",
        awslogs_stream_prefix=f"ecs/{ECS_CONTAINER_NAME}",
        network_configuration={
            "awsvpcConfiguration": {
                "subnets": _csv_env("ECS_SUBNET_IDS"),
                "securityGroups": _csv_env("ECS_SECURITY_GROUP_IDS"),
                "assignPublicIp": ECS_ASSIGN_PUBLIC_IP,
            }
        },
        overrides={
            "containerOverrides": [
                {
                    "name": ECS_CONTAINER_NAME,
                    "command": ["python", "-m", "app.pipeline"],
                    "environment": PROCESSING_ENVIRONMENT,
                }
            ]
        },
    )

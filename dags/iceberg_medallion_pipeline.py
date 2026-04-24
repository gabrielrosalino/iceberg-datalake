from __future__ import annotations

from datetime import datetime
from pathlib import Path

from airflow.decorators import dag, task
from cosmos import DbtTaskGroup, ProjectConfig, ProfileConfig, ExecutionConfig
from cosmos.profiles import DuckDBUserPasswordProfileMapping

AIRFLOW_HOME = Path('/opt/airflow')
DBT_PROJECT_DIR = AIRFLOW_HOME / 'dbt'
DBT_PROFILES_DIR = AIRFLOW_HOME / 'dbt'


@dag(
    dag_id='iceberg_medallion_pipeline',
    description='Public API ingestion with medallion architecture using Airflow, Cosmos, dbt and DuckDB.',
    start_date=datetime(2026, 1, 1),
    schedule='@daily',
    catchup=False,
    tags=['lakehouse', 'iceberg', 'dbt', 'cosmos', 'duckdb', 'medallion'],
)
def iceberg_medallion_pipeline():
    @task
    def ingest_open_meteo_api() -> None:
        import subprocess
        subprocess.run(['python', '/opt/airflow/scripts/ingest_open_meteo.py'], check=True)

    dbt_models = DbtTaskGroup(
        group_id='dbt_medallion_models',
        project_config=ProjectConfig(str(DBT_PROJECT_DIR)),
        profile_config=ProfileConfig(
            profile_name='iceberg_datalake',
            target_name='dev',
            profiles_yml_filepath=str(DBT_PROFILES_DIR / 'profiles.yml'),
        ),
        execution_config=ExecutionConfig(
            dbt_executable_path='/home/airflow/.local/bin/dbt',
        ),
        operator_args={
            'install_deps': False,
        },
    )

    ingest_open_meteo_api() >> dbt_models


iceberg_medallion_pipeline()

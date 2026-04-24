from __future__ import annotations

import os
import subprocess
from pathlib import Path

import boto3

APP_DIR = Path('/app')
RAW_DIR = APP_DIR / 'data' / 'raw' / 'open_meteo'
DBT_DIR = APP_DIR / 'dbt'


def run(command: list[str], cwd: Path | None = None) -> None:
    print(f"Running command: {' '.join(command)}")
    subprocess.run(command, cwd=cwd, check=True)


def upload_raw_files_to_s3() -> None:
    bucket = os.getenv('S3_ARTIFACTS_BUCKET')
    prefix = os.getenv('RAW_DATA_PREFIX', 'raw/open_meteo').strip('/')

    if not bucket:
        print('S3_ARTIFACTS_BUCKET not configured; skipping raw file upload.')
        return

    s3 = boto3.client('s3')

    for path in RAW_DIR.glob('*.jsonl'):
        key = f"{prefix}/{path.name}"
        print(f"Uploading {path} to s3://{bucket}/{key}")
        s3.upload_file(str(path), bucket, key)


def run_pipeline() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    (APP_DIR / 'data' / 'duckdb').mkdir(parents=True, exist_ok=True)

    run(['python', '/app/scripts/ingest_open_meteo.py'])
    upload_raw_files_to_s3()

    run(['dbt', 'deps'], cwd=DBT_DIR)
    run(['dbt', 'run'], cwd=DBT_DIR)
    run(['dbt', 'test'], cwd=DBT_DIR)


if __name__ == '__main__':
    run_pipeline()

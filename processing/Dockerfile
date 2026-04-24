FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends gcc g++ curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY processing/requirements.txt /app/processing/requirements.txt
RUN pip install -r /app/processing/requirements.txt

COPY processing/app /app/app
COPY scripts /app/scripts
COPY dbt /app/dbt

CMD ["python", "-m", "app.pipeline"]

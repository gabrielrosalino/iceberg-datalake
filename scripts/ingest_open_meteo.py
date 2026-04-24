from __future__ import annotations

import json
import os
from datetime import date, timedelta, datetime, timezone
from pathlib import Path
from typing import Any

import pandas as pd
import requests

BASE_DIR = Path(__file__).resolve().parents[1]
RAW_DIR = BASE_DIR / "data" / "raw" / "open_meteo"

OPEN_METEO_ARCHIVE_URL = "https://archive-api.open-meteo.com/v1/archive"

LOCATIONS = [
    {"location_id": "sao_paulo", "city": "São Paulo", "state": "SP", "country": "BR", "latitude": -23.5505, "longitude": -46.6333},
    {"location_id": "rio_de_janeiro", "city": "Rio de Janeiro", "state": "RJ", "country": "BR", "latitude": -22.9068, "longitude": -43.1729},
    {"location_id": "belo_horizonte", "city": "Belo Horizonte", "state": "MG", "country": "BR", "latitude": -19.9167, "longitude": -43.9345},
    {"location_id": "curitiba", "city": "Curitiba", "state": "PR", "country": "BR", "latitude": -25.4284, "longitude": -49.2733},
    {"location_id": "porto_alegre", "city": "Porto Alegre", "state": "RS", "country": "BR", "latitude": -30.0346, "longitude": -51.2177},
    {"location_id": "florianopolis", "city": "Florianópolis", "state": "SC", "country": "BR", "latitude": -27.5949, "longitude": -48.5482},
]

DAILY_VARIABLES = [
    "temperature_2m_max",
    "temperature_2m_min",
    "temperature_2m_mean",
    "precipitation_sum",
    "rain_sum",
    "wind_speed_10m_max",
]


def fetch_daily_weather(location: dict[str, Any], start_date: date, end_date: date) -> pd.DataFrame:
    params = {
        "latitude": location["latitude"],
        "longitude": location["longitude"],
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "daily": ",".join(DAILY_VARIABLES),
        "timezone": "America/Sao_Paulo",
    }

    response = requests.get(OPEN_METEO_ARCHIVE_URL, params=params, timeout=60)
    response.raise_for_status()
    payload = response.json()

    daily = payload.get("daily", {})
    dataframe = pd.DataFrame(daily)

    for key, value in location.items():
        dataframe[key] = value

    dataframe["source"] = "open-meteo"
    dataframe["source_url"] = response.url
    dataframe["_ingested_at"] = datetime.now(timezone.utc).isoformat()
    dataframe["_batch_id"] = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")

    return dataframe


def write_jsonl(dataframe: pd.DataFrame, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    records = dataframe.to_dict(orient="records")

    with output_path.open("w", encoding="utf-8") as file:
        for record in records:
            file.write(json.dumps(record, ensure_ascii=False, default=str) + "\n")


def main() -> None:
    days_back = int(os.getenv("OPEN_METEO_DAYS_BACK", "30"))
    end_date = date.today() - timedelta(days=2)
    start_date = end_date - timedelta(days=days_back)

    frames = [fetch_daily_weather(location, start_date, end_date) for location in LOCATIONS]
    result = pd.concat(frames, ignore_index=True)

    batch_id = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    output_path = RAW_DIR / f"daily_weather_{batch_id}.jsonl"
    write_jsonl(result, output_path)
    print(f"Wrote {len(result)} records to {output_path}")


if __name__ == "__main__":
    main()

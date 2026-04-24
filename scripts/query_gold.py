from __future__ import annotations

import os

import duckdb

DATABASE_PATH = os.getenv("DUCKDB_DATABASE", "data/duckdb/lakehouse.duckdb")

QUERIES = {
    "weather_by_city": "select * from gold.gold_weather_by_city order by avg_temperature_celsius desc",
    "daily_state": "select * from gold.gold_weather_daily_state order by weather_date desc, state",
}


def main() -> None:
    with duckdb.connect(DATABASE_PATH) as connection:
        for name, query in QUERIES.items():
            print(f"\n== {name} ==")
            print(connection.sql(query).df().to_string(index=False))


if __name__ == "__main__":
    main()

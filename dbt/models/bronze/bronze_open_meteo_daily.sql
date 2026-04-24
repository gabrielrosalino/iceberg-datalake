{{ config(materialized='table') }}

with source_files as (
    select *
    from read_json_auto('/opt/airflow/data/raw/open_meteo/*.jsonl')
)

select
    cast(time as date) as weather_date,
    cast(location_id as varchar) as location_id,
    cast(city as varchar) as city,
    cast(state as varchar) as state,
    cast(country as varchar) as country,
    cast(latitude as double) as latitude,
    cast(longitude as double) as longitude,
    cast(temperature_2m_max as double) as temperature_2m_max,
    cast(temperature_2m_min as double) as temperature_2m_min,
    cast(temperature_2m_mean as double) as temperature_2m_mean,
    cast(precipitation_sum as double) as precipitation_sum,
    cast(rain_sum as double) as rain_sum,
    cast(wind_speed_10m_max as double) as wind_speed_10m_max,
    cast(source as varchar) as source,
    cast(source_url as varchar) as source_url,
    cast(_ingested_at as timestamp) as ingested_at,
    cast(_batch_id as varchar) as batch_id
from source_files

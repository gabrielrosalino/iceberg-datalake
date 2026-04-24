{{ config(materialized='table') }}

select
    location_id,
    city,
    state,
    country,
    min(weather_date) as first_weather_date,
    max(weather_date) as last_weather_date,
    count(*) as total_days,
    round(avg(temperature_2m_mean), 2) as avg_temperature_celsius,
    round(max(temperature_2m_max), 2) as max_temperature_celsius,
    round(min(temperature_2m_min), 2) as min_temperature_celsius,
    round(sum(precipitation_sum), 2) as total_precipitation_mm,
    round(avg(wind_speed_10m_max), 2) as avg_max_wind_speed_kmh,
    sum(case when precipitation_class = 'dry' then 1 else 0 end) as dry_days,
    sum(case when precipitation_class = 'heavy_rain' then 1 else 0 end) as heavy_rain_days
from {{ ref('silver_daily_weather') }}
group by 1, 2, 3, 4

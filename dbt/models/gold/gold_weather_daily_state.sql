{{ config(materialized='table') }}

select
    weather_date,
    state,
    country,
    count(distinct location_id) as monitored_locations,
    round(avg(temperature_2m_mean), 2) as avg_temperature_celsius,
    round(sum(precipitation_sum), 2) as total_precipitation_mm,
    round(max(wind_speed_10m_max), 2) as max_wind_speed_kmh,
    sum(case when precipitation_class = 'dry' then 1 else 0 end) as dry_locations,
    sum(case when precipitation_class in ('moderate_rain', 'heavy_rain') then 1 else 0 end) as rainy_locations
from {{ ref('silver_daily_weather') }}
group by 1, 2, 3

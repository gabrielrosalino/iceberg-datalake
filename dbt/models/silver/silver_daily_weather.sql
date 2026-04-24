{{ config(materialized='table') }}

with ranked as (
    select
        *,
        row_number() over (
            partition by weather_date, location_id
            order by ingested_at desc, batch_id desc
        ) as row_number
    from {{ ref('bronze_open_meteo_daily') }}
    where weather_date is not null
      and location_id is not null
)

select
    weather_date,
    location_id,
    city,
    state,
    country,
    latitude,
    longitude,
    temperature_2m_max,
    temperature_2m_min,
    temperature_2m_mean,
    precipitation_sum,
    rain_sum,
    wind_speed_10m_max,
    case
        when precipitation_sum = 0 then 'dry'
        when precipitation_sum < 5 then 'light_rain'
        when precipitation_sum < 20 then 'moderate_rain'
        else 'heavy_rain'
    end as precipitation_class,
    ingested_at,
    batch_id
from ranked
where row_number = 1

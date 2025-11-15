{{
  config(
    materialized='view',
    tags=['staging', 'reference', 'very_low_cost']
  )
}}

-- Small reference table
-- Expected cost: VERY LOW (small lookup table)

SELECT
    geo_id,
    country,
    state,
    city,
    region,
    timezone,
    population,
    median_income,
    CASE 
        WHEN population > 1000000 THEN 'Large Metro'
        WHEN population > 100000 THEN 'Metro'
        WHEN population > 10000 THEN 'Small City'
        ELSE 'Town'
    END as city_size
FROM {{ source('reference', 'geography') }}


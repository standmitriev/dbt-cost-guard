{{
  config(
    materialized='view',
    tags=['staging', 'analytics', 'high_cost']
  )
}}

-- Large web events table staging
-- Expected cost: HIGH (1M+ rows, aggregations)

SELECT
    event_id,
    customer_id,
    session_id,
    event_timestamp,
    DATE(event_timestamp) as event_date,
    HOUR(event_timestamp) as event_hour,
    event_type,
    page_url,
    referrer_url,
    device_type,
    browser,
    country,
    CASE 
        WHEN event_type IN ('purchase', 'checkout_start') THEN TRUE
        ELSE FALSE
    END as is_conversion_event,
    created_at
FROM {{ source('analytics', 'web_events') }}
WHERE event_timestamp >= DATEADD(day, -90, CURRENT_DATE())


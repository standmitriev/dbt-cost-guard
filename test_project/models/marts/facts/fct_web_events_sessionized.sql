{{
  config(
    materialized='incremental',
    unique_key='event_id',
    tags=['marts', 'facts', 'incremental', 'high_cost'],
    meta={
      'description': 'Incremental fact table for sessionized web events',
      'expected_cost': 'HIGH (but lower on incremental runs)'
    }
  )
}}

-- INCREMENTAL MODEL - Should show lower cost on subsequent runs
-- Large dataset (1M+ rows) with sessionization logic
-- Expected cost: HIGH on full refresh, LOW-MEDIUM on incremental

WITH sessionized_events AS (
    SELECT
        we.event_id,
        we.customer_id,
        we.session_id,
        we.event_timestamp,
        we.event_date,
        we.event_hour,
        we.event_type,
        we.page_url,
        we.device_type,
        we.browser,
        we.country,
        we.is_conversion_event,
        
        -- Session-level metrics using window functions
        MIN(we.event_timestamp) OVER (PARTITION BY we.session_id) as session_start_time,
        MAX(we.event_timestamp) OVER (PARTITION BY we.session_id) as session_end_time,
        COUNT(*) OVER (PARTITION BY we.session_id) as events_in_session,
        ROW_NUMBER() OVER (PARTITION BY we.session_id ORDER BY we.event_timestamp) as event_sequence_in_session,
        
        -- Customer journey metrics
        ROW_NUMBER() OVER (PARTITION BY we.customer_id ORDER BY we.event_timestamp) as customer_event_sequence,
        COUNT(DISTINCT we.session_id) OVER (PARTITION BY we.customer_id ORDER BY we.event_timestamp ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as customer_total_sessions,
        
        -- Conversion tracking
        MAX(CASE WHEN we.event_type = 'purchase' THEN 1 ELSE 0 END) OVER (PARTITION BY we.session_id) as session_has_purchase,
        
        we.created_at
    FROM {{ ref('stg_analytics__web_events') }} we
    
    {% if is_incremental() %}
    -- Only process new events on incremental runs
    WHERE we.event_timestamp > (SELECT MAX(event_timestamp) FROM {{ this }})
    {% endif %}
)

SELECT
    event_id,
    customer_id,
    session_id,
    event_timestamp,
    event_date,
    event_hour,
    event_type,
    page_url,
    device_type,
    browser,
    country,
    is_conversion_event,
    session_start_time,
    session_end_time,
    DATEDIFF(second, session_start_time, session_end_time) as session_duration_seconds,
    events_in_session,
    event_sequence_in_session,
    customer_event_sequence,
    customer_total_sessions,
    session_has_purchase,
    
    -- Derived flags
    CASE WHEN event_sequence_in_session = 1 THEN TRUE ELSE FALSE END as is_session_start,
    CASE WHEN event_sequence_in_session = events_in_session THEN TRUE ELSE FALSE END as is_session_end,
    
    created_at,
    CURRENT_TIMESTAMP() as updated_at

FROM sessionized_events


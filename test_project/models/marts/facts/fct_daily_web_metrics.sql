{{
  config(
    materialized='table',
    tags=['marts', 'aggregates', 'very_high_cost']
  )
}}

-- VERY EXPENSIVE AGGREGATION MODEL
-- Time-series aggregations with multiple window functions
-- Expected cost: VERY HIGH

WITH daily_metrics AS (
    SELECT
        DATE(we.event_timestamp) as event_date,
        we.country,
        we.device_type,
        COUNT(*) as total_events,
        COUNT(DISTINCT we.customer_id) as unique_customers,
        COUNT(DISTINCT we.session_id) as unique_sessions,
        SUM(CASE WHEN we.event_type = 'page_view' THEN 1 ELSE 0 END) as page_views,
        SUM(CASE WHEN we.event_type = 'purchase' THEN 1 ELSE 0 END) as purchases,
        SUM(CASE WHEN we.is_conversion_event THEN 1 ELSE 0 END) as conversions
    FROM {{ ref('stg_analytics__web_events') }} we
    GROUP BY 1, 2, 3
),

rolling_metrics AS (
    SELECT
        dm.*,
        
        -- 7-day rolling averages
        AVG(dm.total_events) OVER (
            PARTITION BY dm.country, dm.device_type 
            ORDER BY dm.event_date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) as rolling_7d_avg_events,
        
        AVG(dm.unique_customers) OVER (
            PARTITION BY dm.country, dm.device_type 
            ORDER BY dm.event_date 
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) as rolling_7d_avg_customers,
        
        -- 30-day rolling averages
        AVG(dm.total_events) OVER (
            PARTITION BY dm.country, dm.device_type 
            ORDER BY dm.event_date 
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ) as rolling_30d_avg_events,
        
        -- Year-over-year comparisons
        LAG(dm.total_events, 365) OVER (
            PARTITION BY dm.country, dm.device_type 
            ORDER BY dm.event_date
        ) as total_events_yoy,
        
        -- Running totals
        SUM(dm.total_events) OVER (
            PARTITION BY dm.country, dm.device_type 
            ORDER BY dm.event_date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) as cumulative_events,
        
        SUM(dm.purchases) OVER (
            PARTITION BY dm.country, dm.device_type 
            ORDER BY dm.event_date 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) as cumulative_purchases,
        
        -- Rank metrics
        ROW_NUMBER() OVER (
            PARTITION BY dm.event_date 
            ORDER BY dm.total_events DESC
        ) as daily_country_device_rank,
        
        PERCENT_RANK() OVER (
            PARTITION BY dm.country 
            ORDER BY dm.total_events
        ) as event_percentile_by_country
        
    FROM daily_metrics dm
)

SELECT
    rm.*,
    
    -- Growth rates
    CASE 
        WHEN rm.total_events_yoy > 0 THEN 
            ((rm.total_events - rm.total_events_yoy)::FLOAT / rm.total_events_yoy) * 100
        ELSE NULL
    END as yoy_growth_rate_percent,
    
    -- Conversion rate
    CASE 
        WHEN rm.unique_sessions > 0 THEN 
            (rm.purchases::FLOAT / rm.unique_sessions) * 100
        ELSE 0
    END as conversion_rate_percent,
    
    CURRENT_TIMESTAMP() as created_at

FROM rolling_metrics rm


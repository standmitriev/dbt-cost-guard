{{
  config(
    materialized='table',
    tags=['expensive', 'demo_only']
  )
}}

/*
  Ultra Expensive Model - Designed for Cost Demonstration
  
  ⚠️  WARNING: This model is designed to be VERY EXPENSIVE!
  
  To demonstrate costs over $20, you need to:
  1. Resize your warehouse to LARGE or X-LARGE
  2. Run this model
  3. Let it run for at least 50+ minutes
  
  Or, resize to X-LARGE ($48/hour) and run for 30 minutes = $24
*/

WITH base_events AS (
    SELECT 
        event_id,
        user_id,
        session_id,
        event_timestamp,
        event_type,
        page_url,
        referrer_url
    FROM {{ source('analytics', 'web_events') }}
    -- NO FILTER - Process ALL 1 MILLION events! VERY EXPENSIVE!
),

-- Self-join to create event pairs (will create millions of rows)
event_pairs AS (
    SELECT
        e1.event_id as event1_id,
        e1.user_id,
        e1.session_id as session1_id,
        e1.event_timestamp as event1_timestamp,
        e1.event_type as event1_type,
        e1.page_url as event1_page,
        e2.event_id as event2_id,
        e2.session_id as session2_id,
        e2.event_timestamp as event2_timestamp,
        e2.event_type as event2_type,
        e2.page_url as event2_page,
        DATEDIFF(second, e1.event_timestamp, e2.event_timestamp) as seconds_between,
        DATEDIFF(minute, e1.event_timestamp, e2.event_timestamp) as minutes_between,
        -- Add distance calculations for complexity
        CASE 
            WHEN e1.session_id = e2.session_id THEN 'same_session'
            ELSE 'different_session'
        END as session_relationship
    FROM base_events e1
    INNER JOIN base_events e2
        ON e1.user_id = e2.user_id
        AND e2.event_timestamp > e1.event_timestamp
        AND e2.event_timestamp <= DATEADD(day, 7, e1.event_timestamp)  -- 7-day window
    -- This will create: 200K × avg_events_per_user_in_7_days rows
    -- With 200K events spread across users, this could be 10M-100M rows
),

-- Add 20+ window functions to make it extremely compute-intensive
enriched_pairs AS (
    SELECT
        *,
        -- Window functions (each one is expensive on large datasets)
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event1_timestamp) as user_event_sequence,
        DENSE_RANK() OVER (PARTITION BY user_id, event1_type ORDER BY event1_timestamp) as type_rank,
        RANK() OVER (PARTITION BY user_id ORDER BY seconds_between DESC) as time_gap_rank,
        
        -- Lag/Lead functions (look backward/forward)
        LAG(event1_timestamp, 1) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as prev_event_1,
        LAG(event1_timestamp, 2) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as prev_event_2,
        LAG(event1_timestamp, 3) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as prev_event_3,
        LAG(event1_timestamp, 5) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as prev_event_5,
        LEAD(event1_timestamp, 1) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as next_event_1,
        LEAD(event1_timestamp, 2) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as next_event_2,
        LEAD(event1_timestamp, 3) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as next_event_3,
        
        -- Aggregate window functions (very expensive)
        SUM(seconds_between) OVER (PARTITION BY user_id ORDER BY event1_timestamp 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as cumulative_seconds,
        AVG(seconds_between) OVER (PARTITION BY user_id ORDER BY event1_timestamp 
            ROWS BETWEEN 100 PRECEDING AND CURRENT ROW) as rolling_avg_100,
        AVG(seconds_between) OVER (PARTITION BY user_id ORDER BY event1_timestamp 
            ROWS BETWEEN 500 PRECEDING AND CURRENT ROW) as rolling_avg_500,
        AVG(seconds_between) OVER (PARTITION BY user_id ORDER BY event1_timestamp 
            ROWS BETWEEN 1000 PRECEDING AND CURRENT ROW) as rolling_avg_1000,
        
        -- Min/Max windows
        MAX(seconds_between) OVER (PARTITION BY user_id ORDER BY event1_timestamp 
            ROWS BETWEEN 100 PRECEDING AND 100 FOLLOWING) as max_window_200,
        MIN(seconds_between) OVER (PARTITION BY user_id ORDER BY event1_timestamp 
            ROWS BETWEEN 100 PRECEDING AND 100 FOLLOWING) as min_window_200,
        
        -- Statistical functions (extremely expensive)
        STDDEV(seconds_between) OVER (PARTITION BY user_id ORDER BY event1_timestamp 
            ROWS BETWEEN 200 PRECEDING AND CURRENT ROW) as rolling_stddev_200,
        VARIANCE(seconds_between) OVER (PARTITION BY user_id ORDER BY event1_timestamp 
            ROWS BETWEEN 200 PRECEDING AND CURRENT ROW) as rolling_variance_200,
        
        -- Percentile functions (very expensive)
        PERCENT_RANK() OVER (PARTITION BY event1_type ORDER BY seconds_between) as percentile_rank_type,
        PERCENT_RANK() OVER (PARTITION BY user_id ORDER BY seconds_between) as percentile_rank_user,
        CUME_DIST() OVER (PARTITION BY event1_type ORDER BY seconds_between) as cumulative_dist,
        
        -- Bucketing (expensive with large N)
        NTILE(100) OVER (ORDER BY seconds_between DESC) as time_bucket_100,
        NTILE(1000) OVER (ORDER BY seconds_between DESC) as time_bucket_1000,
        
        -- Count windows
        COUNT(*) OVER (PARTITION BY user_id) as total_user_pairs,
        COUNT(DISTINCT event1_type) OVER (PARTITION BY user_id) as distinct_event_types,
        
        -- Running totals by type
        SUM(CASE WHEN event1_type = 'page_view' THEN 1 ELSE 0 END) 
            OVER (PARTITION BY user_id ORDER BY event1_timestamp) as running_page_views,
        SUM(CASE WHEN event1_type = 'click' THEN 1 ELSE 0 END) 
            OVER (PARTITION BY user_id ORDER BY event1_timestamp) as running_clicks
    FROM event_pairs
),

-- Add more calculations
final AS (
    SELECT
        *,
        -- Mathematical operations to increase compute
        SQRT(ABS(seconds_between)) as sqrt_seconds,
        LN(ABS(seconds_between) + 1) as log_seconds,
        POWER(ABS(seconds_between) / 60.0, 2) as squared_minutes,
        EXP(LEAST(seconds_between / 3600.0, 10)) as exp_hours,  -- Cap to avoid overflow
        
        -- String operations (expensive)
        CONCAT(event1_type, '_to_', event2_type) as event_transition,
        LENGTH(event1_page) + LENGTH(event2_page) as total_url_length,
        
        -- Case statements for categorization
        CASE 
            WHEN seconds_between < 60 THEN 'immediate'
            WHEN seconds_between < 300 THEN 'quick'
            WHEN seconds_between < 1800 THEN 'moderate'
            WHEN seconds_between < 3600 THEN 'slow'
            ELSE 'very_slow'
        END as response_speed,
        
        CASE
            WHEN rolling_avg_100 < 60 THEN 'fast_user'
            WHEN rolling_avg_100 < 300 THEN 'normal_user'
            ELSE 'slow_user'
        END as user_speed_category
    FROM enriched_pairs
    -- NO FILTER - Process ALL rows! VERY EXPENSIVE!
    -- WHERE user_event_sequence <= 100000
)

SELECT * FROM final


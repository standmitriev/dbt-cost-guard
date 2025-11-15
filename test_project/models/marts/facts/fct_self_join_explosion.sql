-- 🔥 INSANELY EXPENSIVE MODEL - MULTIPLE SELF-JOINS! 🔥
-- This model does 5 self-joins on a 1M row table = exponential explosion!
-- DO NOT RUN IN PRODUCTION!

{{ config(
    materialized='table',
    tags=['extremely_expensive', 'test_only', 'self_joins']
) }}

WITH web_events AS (
    SELECT 
        event_id,
        session_id,
        user_id,
        event_timestamp,
        event_type,
        page_url,
        referrer_url
    FROM {{ ref('stg_analytics__web_events') }}
),

-- 🔥 SELF-JOIN 1: Match events with same user (1M × 1M potential)
same_user_events AS (
    SELECT
        e1.event_id as event1_id,
        e1.user_id,
        e1.event_timestamp as event1_timestamp,
        e1.event_type as event1_type,
        e2.event_id as event2_id,
        e2.event_timestamp as event2_timestamp,
        e2.event_type as event2_type,
        DATEDIFF(second, e1.event_timestamp, e2.event_timestamp) as time_diff_seconds
    FROM web_events e1
    INNER JOIN web_events e2
        ON e1.user_id = e2.user_id
        AND e2.event_timestamp > e1.event_timestamp
        AND e2.event_timestamp <= DATEADD(hour, 1, e1.event_timestamp)  -- Events within 1 hour
),

-- 🔥 SELF-JOIN 2: Match by session (on top of previous join)
session_patterns AS (
    SELECT
        sue.*,
        e3.event_id as event3_id,
        e3.event_type as event3_type,
        e3.event_timestamp as event3_timestamp
    FROM same_user_events sue
    INNER JOIN web_events e3
        ON sue.user_id = e3.user_id
        AND e3.event_timestamp BETWEEN sue.event1_timestamp AND sue.event2_timestamp
),

-- 🔥 SELF-JOIN 3: Match by page URL patterns
url_patterns AS (
    SELECT
        sp.*,
        e4.event_id as event4_id,
        e4.page_url as event4_page_url,
        e4.event_timestamp as event4_timestamp
    FROM session_patterns sp
    INNER JOIN web_events e4
        ON sp.user_id = e4.user_id
        AND e4.event_timestamp >= sp.event1_timestamp
),

-- 🔥 SELF-JOIN 4: Match by referrer patterns
referrer_patterns AS (
    SELECT
        up.*,
        e5.event_id as event5_id,
        e5.referrer_url as event5_referrer,
        e5.event_timestamp as event5_timestamp
    FROM url_patterns up
    INNER JOIN web_events e5
        ON up.user_id = e5.user_id
        AND e5.event_timestamp <= up.event2_timestamp
),

-- Add massive aggregations and window functions
final_explosion AS (
    SELECT
        user_id,
        event1_id,
        event2_id,
        event3_id,
        event4_id,
        event5_id,
        COUNT(*) as pattern_count,
        AVG(time_diff_seconds) as avg_time_diff,
        -- 🔥 20+ window functions on the exploded dataset
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event1_timestamp) as event_sequence,
        DENSE_RANK() OVER (PARTITION BY event1_type ORDER BY event1_timestamp) as type_rank,
        LAG(event1_timestamp, 1) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as prev_event_time,
        LAG(event1_timestamp, 2) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as prev_event_time_2,
        LAG(event1_timestamp, 3) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as prev_event_time_3,
        LEAD(event1_timestamp, 1) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as next_event_time,
        LEAD(event1_timestamp, 2) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as next_event_time_2,
        LEAD(event1_timestamp, 3) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as next_event_time_3,
        SUM(time_diff_seconds) OVER (PARTITION BY user_id ORDER BY event1_timestamp ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as running_total_time,
        AVG(time_diff_seconds) OVER (PARTITION BY user_id ORDER BY event1_timestamp ROWS BETWEEN 50 PRECEDING AND CURRENT ROW) as rolling_avg_50,
        AVG(time_diff_seconds) OVER (PARTITION BY user_id ORDER BY event1_timestamp ROWS BETWEEN 100 PRECEDING AND CURRENT ROW) as rolling_avg_100,
        MAX(time_diff_seconds) OVER (PARTITION BY user_id ORDER BY event1_timestamp ROWS BETWEEN 30 PRECEDING AND 30 FOLLOWING) as max_window_60,
        MIN(time_diff_seconds) OVER (PARTITION BY user_id ORDER BY event1_timestamp ROWS BETWEEN 30 PRECEDING AND 30 FOLLOWING) as min_window_60,
        STDDEV(time_diff_seconds) OVER (PARTITION BY user_id ORDER BY event1_timestamp ROWS BETWEEN 100 PRECEDING AND CURRENT ROW) as rolling_stddev,
        PERCENT_RANK() OVER (PARTITION BY event1_type ORDER BY time_diff_seconds) as percentile_rank,
        NTILE(1000) OVER (ORDER BY time_diff_seconds DESC) as time_bucket,
        FIRST_VALUE(event1_type) OVER (PARTITION BY user_id ORDER BY event1_timestamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as first_event_type,
        LAST_VALUE(event1_type) OVER (PARTITION BY user_id ORDER BY event1_timestamp ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) as last_event_type,
        COUNT(*) OVER (PARTITION BY user_id) as total_user_patterns,
        SUM(pattern_count) OVER (PARTITION BY event1_type ORDER BY event1_timestamp) as cumulative_type_patterns
    FROM referrer_patterns
    GROUP BY 
        user_id, 
        event1_id, 
        event2_id, 
        event3_id, 
        event4_id, 
        event5_id,
        event1_timestamp,
        event1_type,
        time_diff_seconds
)

SELECT * FROM final_explosion
WHERE event_sequence <= 100  -- Still processes EVERYTHING


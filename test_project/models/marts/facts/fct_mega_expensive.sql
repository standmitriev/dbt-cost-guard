{{
  config(
    materialized='table',
    tags=['expensive', 'large_data']
  )
}}

/*
  MEGA Expensive Query - Designed for 5-20 minute runtime
  
  ⚠️  VERSION 2: EVEN MORE EXPENSIVE! ⚠️
  
  Changes from v1:
  - 24-hour window → 30-DAY window (30x more data!)
  - Removed event_type filter (3x more events)
  - Removed product_id filter in order items (10x more joins)
  - Extended order window: 7 days → 30 days (4x more orders)
  
  Uses:
  - 10M web events (50% sample)
  - 100M product views (within 30-day windows!)
  - 5M orders (within 30-day windows!)
  - 20M order items (ALL items per order!)
  
  Expected Data Volume:
  - Initial join: 5M events × ~10M product views (in 30-day windows)
  - Creates: 50-100M intermediate rows
  - Then joins to orders: another 10x expansion
  - Final result: Could be 500M-1B rows!
  
  Expected runtime:
  - X-Small:  20-60 minutes  → $1.00-3.00 🔥
  - Medium:   5-15 minutes   → $1.00-3.00 🔥
  - Large:    3-8 minutes    → $1.20-3.20 🔥
  - X-Large:  1-4 minutes    → $0.80-3.20 🔥
  - 3X-Large: 30-120 seconds → $1.60-6.40 🔥🔥
  
  ⚠️  DO NOT RUN THIS WITHOUT UNDERSTANDING THE COST! ⚠️
  ⚠️  This is designed for ESTIMATION and DEMONSTRATION only! ⚠️
*/

WITH user_events AS (
    -- 10M rows
    SELECT 
        user_id,
        event_id,
        session_id,
        event_timestamp,
        event_type,
        page_url
    FROM {{ source('analytics', 'web_events_large') }}
),

product_engagement AS (
    -- 100M rows - this is the BIG one!
    SELECT
        user_id,
        product_id,
        view_time,
        view_duration_seconds,
        engagement_score
    FROM {{ source('analytics', 'product_views') }}
),

-- Create user-product pairs (MASSIVE JOIN - millions × millions)
-- ⚠️  WARNING: This will process HUGE amounts of data!
user_product_interactions AS (
    SELECT
        ue.user_id,
        pe.product_id,
        ue.event_timestamp,
        pe.view_time,
        pe.view_duration_seconds,
        pe.engagement_score,
        ue.event_type,
        ue.session_id,
        DATEDIFF(second, pe.view_time, ue.event_timestamp) as time_to_event_seconds
    FROM user_events ue
    INNER JOIN product_engagement pe
        ON ue.user_id = pe.user_id
        AND pe.view_time <= ue.event_timestamp
        AND pe.view_time >= DATEADD(day, -30, ue.event_timestamp)  -- 30-DAY window (was 24 hours!)
    -- REMOVED event_type filter - process ALL events now!
    WHERE ue.user_id % 2 = 0  -- Sample 50% of users to prevent total explosion
),

-- Add MANY expensive window functions
enriched_interactions AS (
    SELECT
        *,
        -- Basic window functions
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event_timestamp) as user_event_sequence,
        ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY view_time) as product_view_sequence,
        ROW_NUMBER() OVER (PARTITION BY user_id, product_id ORDER BY event_timestamp) as user_product_seq,
        
        -- Dense rank and rank (expensive)
        DENSE_RANK() OVER (PARTITION BY user_id, event_type ORDER BY event_timestamp) as event_type_rank,
        RANK() OVER (PARTITION BY product_id ORDER BY engagement_score DESC) as engagement_rank,
        
        -- Lag/Lead (expensive with large partitions)
        LAG(event_timestamp, 1) OVER (PARTITION BY user_id ORDER BY event_timestamp) as prev_event_1,
        LAG(event_timestamp, 2) OVER (PARTITION BY user_id ORDER BY event_timestamp) as prev_event_2,
        LAG(event_timestamp, 3) OVER (PARTITION BY user_id ORDER BY event_timestamp) as prev_event_3,
        LEAD(event_timestamp, 1) OVER (PARTITION BY user_id ORDER BY event_timestamp) as next_event_1,
        LEAD(event_timestamp, 2) OVER (PARTITION BY user_id ORDER BY event_timestamp) as next_event_2,
        
        -- Aggregate window functions (VERY expensive on large datasets)
        SUM(view_duration_seconds) OVER (
            PARTITION BY user_id 
            ORDER BY event_timestamp 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) as cumulative_view_time,
        
        AVG(engagement_score) OVER (
            PARTITION BY user_id 
            ORDER BY event_timestamp 
            ROWS BETWEEN 1000 PRECEDING AND CURRENT ROW
        ) as rolling_avg_engagement_1000,
        
        AVG(view_duration_seconds) OVER (
            PARTITION BY product_id 
            ORDER BY view_time 
            ROWS BETWEEN 5000 PRECEDING AND CURRENT ROW
        ) as rolling_avg_view_time_5000,
        
        MAX(engagement_score) OVER (
            PARTITION BY user_id 
            ORDER BY event_timestamp 
            ROWS BETWEEN 500 PRECEDING AND 500 FOLLOWING
        ) as max_engagement_window_1000,
        
        MIN(view_duration_seconds) OVER (
            PARTITION BY user_id 
            ORDER BY event_timestamp 
            ROWS BETWEEN 500 PRECEDING AND 500 FOLLOWING
        ) as min_view_time_window_1000,
        
        -- Statistical functions (extremely expensive)
        STDDEV(engagement_score) OVER (
            PARTITION BY user_id 
            ORDER BY event_timestamp 
            ROWS BETWEEN 2000 PRECEDING AND CURRENT ROW
        ) as rolling_stddev_engagement_2000,
        
        VARIANCE(view_duration_seconds) OVER (
            PARTITION BY product_id 
            ORDER BY view_time 
            ROWS BETWEEN 1000 PRECEDING AND CURRENT ROW
        ) as rolling_variance_view_time_1000,
        
        -- Percentile functions (VERY expensive)
        PERCENT_RANK() OVER (PARTITION BY event_type ORDER BY engagement_score) as engagement_percentile,
        CUME_DIST() OVER (PARTITION BY user_id ORDER BY engagement_score) as user_engagement_distribution,
        
        -- Bucketing (expensive with large N)
        NTILE(1000) OVER (ORDER BY engagement_score DESC) as engagement_bucket_1000,
        NTILE(100) OVER (PARTITION BY product_id ORDER BY view_duration_seconds DESC) as product_view_bucket_100,
        
        -- Count windows
        COUNT(*) OVER (PARTITION BY user_id) as total_user_interactions,
        COUNT(*) OVER (PARTITION BY product_id) as total_product_interactions,
        COUNT(DISTINCT session_id) OVER (PARTITION BY user_id) as user_session_count
    FROM user_product_interactions
),

-- Add order data (another MASSIVE join - will process millions of combinations)
-- ⚠️  WARNING: This joins a huge intermediate result to 20M order items!
with_orders AS (
    SELECT
        ei.*,
        o.order_id,
        o.order_date,
        o.total_amount as order_amount,
        o.status as order_status,
        oi.quantity,
        oi.unit_price,
        oi.discount_amount,
        
        -- More window functions over order data (expensive on large result set)
        SUM(oi.quantity * oi.unit_price) OVER (
            PARTITION BY ei.user_id 
            ORDER BY o.order_date
        ) as cumulative_spend,
        
        AVG(o.total_amount) OVER (
            PARTITION BY ei.user_id 
            ORDER BY o.order_date 
            ROWS BETWEEN 10 PRECEDING AND CURRENT ROW
        ) as rolling_avg_order_value_10
    FROM enriched_interactions ei
    LEFT JOIN {{ source('sales', 'orders_large') }} o
        ON ei.user_id = o.customer_id
        AND o.order_date >= DATE_TRUNC('day', ei.event_timestamp)
        AND o.order_date <= DATEADD(day, 30, ei.event_timestamp)  -- Extended to 30 days!
    LEFT JOIN {{ source('sales', 'order_items_large') }} oi
        ON o.order_id = oi.order_id
        -- REMOVED product_id filter - join ALL order items for each order!
)

SELECT
    *,
    -- Final calculations
    CASE 
        WHEN cumulative_spend > 10000 THEN 'whale'
        WHEN cumulative_spend > 1000 THEN 'high_value'
        WHEN cumulative_spend > 100 THEN 'medium_value'
        ELSE 'low_value'
    END as customer_segment,
    
    CASE
        WHEN rolling_avg_engagement_1000 > 80 THEN 'highly_engaged'
        WHEN rolling_avg_engagement_1000 > 50 THEN 'engaged'
        ELSE 'casual'
    END as engagement_level
FROM with_orders
-- Don't filter - process everything!
WHERE user_event_sequence IS NOT NULL


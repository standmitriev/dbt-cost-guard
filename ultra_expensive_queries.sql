-- ============================================================================
-- 💰 EXTREMELY EXPENSIVE QUERY - WILL COST $20+ 💰
-- ============================================================================
-- 
-- ⚠️  WARNING: This query is designed to be VERY EXPENSIVE!
-- 
-- On X-Small warehouse ($3/hour):
--   - To cost $20: Need ~400 minutes (6.6 hours)
--   - To cost $1: Need ~20 minutes
-- 
-- On MEDIUM warehouse ($12/hour):
--   - To cost $20: Need ~100 minutes (1.6 hours)
--   - To cost $1: Need ~5 minutes
-- 
-- OPTIONS TO MAKE IT EXPENSIVE:
-- ============================================================================

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- OPTION 1: Use a LARGER WAREHOUSE (FASTEST way to increase cost)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- First, resize your warehouse:
-- ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'MEDIUM';  -- $12/hour ($0.20/min)
-- ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'LARGE';   -- $24/hour ($0.40/min)
-- ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'X-LARGE'; -- $48/hour ($0.80/min)

-- On X-LARGE, a 30-minute query would cost $24!


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- OPTION 2: MASSIVE CARTESIAN PRODUCT (will run for HOURS on X-Small)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- ⚠️  This will create BILLIONS of rows and run for hours!
-- ⚠️  Estimated cost on X-Small: $20-50+ (6-15 hours)
-- ⚠️  You should probably NOT run this to completion!

/*
CREATE OR REPLACE TABLE ANALYTICS_DB.DBT_COST_GUARD_TEST.expensive_cartesian AS
SELECT
    c.customer_id,
    c.customer_name,
    o.order_id,
    o.order_date,
    o.total_amount,
    oi.product_id,
    oi.quantity,
    p.product_name,
    -- Add some calculations to make it even more expensive
    c.customer_id * o.order_id * oi.product_id as combined_key,
    ROW_NUMBER() OVER (PARTITION BY c.customer_id ORDER BY o.order_date) as order_seq,
    SUM(o.total_amount) OVER (PARTITION BY c.customer_id ORDER BY o.order_date 
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as running_total,
    AVG(oi.quantity) OVER (PARTITION BY p.product_id ORDER BY o.order_date 
        ROWS BETWEEN 30 PRECEDING AND CURRENT ROW) as rolling_avg_qty
FROM SALES_DB.RAW.customers c
CROSS JOIN SALES_DB.RAW.orders o          -- 50K × 150K = 7.5 BILLION rows!
CROSS JOIN SALES_DB.RAW.order_items oi    -- × 500K = 3.75 TRILLION rows!
INNER JOIN SALES_DB.RAW.products p ON oi.product_id = p.product_id
WHERE c.customer_id <= 100  -- Limit to make it slightly safer
  AND o.order_id <= 1000
  AND oi.order_item_id <= 1000;
*/


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- OPTION 3: CONTROLLED EXPENSIVE QUERY (5-10 minute runtime)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- This is designed to run for several minutes (not hours)
-- Cost on X-Small: ~$0.25-0.50 (5-10 minutes)
-- Cost on MEDIUM: ~$1-2 (5-10 minutes)
-- Cost on LARGE: ~$2-4 (5-10 minutes)

CREATE OR REPLACE TABLE ANALYTICS_DB.DBT_COST_GUARD_TEST.controlled_expensive_query AS
WITH expanded_events AS (
    -- Create 1M × 1M self-join (will be reduced by filters)
    SELECT
        e1.event_id as event1_id,
        e1.user_id,
        e1.event_timestamp as event1_timestamp,
        e1.event_type as event1_type,
        e1.page_url as event1_page,
        e2.event_id as event2_id,
        e2.event_timestamp as event2_timestamp,
        e2.event_type as event2_type,
        e2.page_url as event2_page,
        DATEDIFF(second, e1.event_timestamp, e2.event_timestamp) as time_diff_seconds
    FROM ANALYTICS_DB.RAW.web_events e1
    INNER JOIN ANALYTICS_DB.RAW.web_events e2
        ON e1.user_id = e2.user_id
        AND e2.event_timestamp > e1.event_timestamp
        AND e2.event_timestamp <= DATEADD(hour, 24, e1.event_timestamp)  -- 24-hour window
    WHERE e1.event_id % 10 = 0  -- Reduce to 10% of events for e1
      AND e2.event_id % 5 = 0   -- Reduce to 20% of events for e2
),

-- Add multiple expensive aggregations
event_pairs_with_stats AS (
    SELECT
        user_id,
        event1_id,
        event2_id,
        event1_type,
        event2_type,
        time_diff_seconds,
        -- Multiple window functions (EXPENSIVE!)
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event1_timestamp) as event_sequence,
        DENSE_RANK() OVER (PARTITION BY user_id, event1_type ORDER BY event1_timestamp) as type_sequence,
        LAG(event1_timestamp, 1) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as prev_event_time_1,
        LAG(event1_timestamp, 2) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as prev_event_time_2,
        LAG(event1_timestamp, 3) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as prev_event_time_3,
        LEAD(event1_timestamp, 1) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as next_event_time_1,
        LEAD(event1_timestamp, 2) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as next_event_time_2,
        LEAD(event1_timestamp, 3) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as next_event_time_3,
        SUM(time_diff_seconds) OVER (PARTITION BY user_id ORDER BY event1_timestamp 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as running_total_time,
        AVG(time_diff_seconds) OVER (PARTITION BY user_id ORDER BY event1_timestamp 
            ROWS BETWEEN 100 PRECEDING AND CURRENT ROW) as rolling_avg_100,
        AVG(time_diff_seconds) OVER (PARTITION BY user_id ORDER BY event1_timestamp 
            ROWS BETWEEN 500 PRECEDING AND CURRENT ROW) as rolling_avg_500,
        MAX(time_diff_seconds) OVER (PARTITION BY user_id ORDER BY event1_timestamp 
            ROWS BETWEEN 100 PRECEDING AND 100 FOLLOWING) as max_window_200,
        MIN(time_diff_seconds) OVER (PARTITION BY user_id ORDER BY event1_timestamp 
            ROWS BETWEEN 100 PRECEDING AND 100 FOLLOWING) as min_window_200,
        STDDEV(time_diff_seconds) OVER (PARTITION BY user_id ORDER BY event1_timestamp 
            ROWS BETWEEN 200 PRECEDING AND CURRENT ROW) as rolling_stddev,
        PERCENT_RANK() OVER (PARTITION BY event1_type ORDER BY time_diff_seconds) as percentile_rank,
        NTILE(1000) OVER (ORDER BY time_diff_seconds DESC) as time_bucket,
        COUNT(*) OVER (PARTITION BY user_id) as total_user_events,
        SUM(time_diff_seconds) OVER (PARTITION BY event1_type ORDER BY event1_timestamp) as cumulative_type_time
    FROM expanded_events
)

SELECT 
    *,
    -- Add more calculations to increase compute
    SQRT(time_diff_seconds) as sqrt_time,
    LN(time_diff_seconds + 1) as log_time,
    POWER(time_diff_seconds / 60.0, 2) as squared_minutes
FROM event_pairs_with_stats
WHERE event_sequence <= 10000;  -- Limit output but process everything


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- OPTION 4: MULTIPLE SEQUENTIAL EXPENSIVE QUERIES (10-20 minutes total)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Run multiple expensive operations in sequence
-- Total time: 10-20 minutes on X-Small = $0.50-1.00
-- Total time: 10-20 minutes on LARGE = $4-8

/*
-- Query 1: Customer analysis (2-3 minutes)
CREATE OR REPLACE TABLE ANALYTICS_DB.DBT_COST_GUARD_TEST.expensive_customer_analysis AS
SELECT
    c.customer_id,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(o.total_amount) as lifetime_value,
    AVG(oi.quantity) as avg_quantity,
    COUNT(DISTINCT we.event_id) as web_events_count,
    LISTAGG(DISTINCT p.product_name, ', ') WITHIN GROUP (ORDER BY p.product_name) as products_purchased
FROM SALES_DB.RAW.customers c
LEFT JOIN SALES_DB.RAW.orders o ON c.customer_id = o.customer_id
LEFT JOIN SALES_DB.RAW.order_items oi ON o.order_id = oi.order_id
LEFT JOIN SALES_DB.RAW.products p ON oi.product_id = p.product_id
LEFT JOIN ANALYTICS_DB.RAW.web_events we ON c.customer_id = we.user_id
GROUP BY c.customer_id;

-- Query 2: Product analysis (2-3 minutes)
CREATE OR REPLACE TABLE ANALYTICS_DB.DBT_COST_GUARD_TEST.expensive_product_analysis AS
SELECT
    p.product_id,
    p.product_name,
    COUNT(DISTINCT oi.order_id) as orders_count,
    SUM(oi.quantity) as total_quantity_sold,
    COUNT(DISTINCT oi.customer_id) as unique_customers,
    AVG(o.total_amount) as avg_order_value,
    LISTAGG(DISTINCT g.city, ', ') WITHIN GROUP (ORDER BY g.city) as cities_sold_in
FROM SALES_DB.RAW.products p
LEFT JOIN SALES_DB.RAW.order_items oi ON p.product_id = oi.product_id
LEFT JOIN SALES_DB.RAW.orders o ON oi.order_id = o.order_id
LEFT JOIN REFERENCE_DB.RAW.geography g ON o.customer_id = g.geo_id
GROUP BY p.product_id, p.product_name;

-- Query 3: Event analysis (3-5 minutes)
CREATE OR REPLACE TABLE ANALYTICS_DB.DBT_COST_GUARD_TEST.expensive_event_analysis AS
SELECT
    user_id,
    event_type,
    DATE_TRUNC('day', event_timestamp) as event_day,
    COUNT(*) as event_count,
    COUNT(DISTINCT session_id) as session_count,
    AVG(DATEDIFF(second, 
        LAG(event_timestamp) OVER (PARTITION BY user_id ORDER BY event_timestamp),
        event_timestamp)) as avg_seconds_between_events
FROM ANALYTICS_DB.RAW.web_events
GROUP BY user_id, event_type, DATE_TRUNC('day', event_timestamp);

-- Query 4: Final join (3-5 minutes)
CREATE OR REPLACE TABLE ANALYTICS_DB.DBT_COST_GUARD_TEST.expensive_final_rollup AS
SELECT
    ca.*,
    pa.orders_count as product_orders,
    ea.event_count as total_events,
    ea.session_count as total_sessions
FROM ANALYTICS_DB.DBT_COST_GUARD_TEST.expensive_customer_analysis ca
LEFT JOIN ANALYTICS_DB.DBT_COST_GUARD_TEST.expensive_product_analysis pa
    ON 1=1  -- Cartesian join for demonstration
LEFT JOIN ANALYTICS_DB.DBT_COST_GUARD_TEST.expensive_event_analysis ea
    ON ca.customer_id = ea.user_id;
*/


-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- RECOMMENDED: RESIZE WAREHOUSE + RUN OPTION 3
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Step 1: Resize to LARGE or X-LARGE
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'LARGE';  -- $24/hour = $0.40/min

-- Step 2: Get the estimate from dbt-cost-guard
-- dbt-cost-guard --project-dir test_project analyze -m fct_self_join_explosion

-- Step 3: Run the controlled expensive query (OPTION 3 above)
-- Should run for 5-10 minutes = $2-4 on LARGE warehouse

-- Step 4: Check the cost afterward:
SELECT
    total_elapsed_time / 1000.0 / 60.0 as runtime_minutes,
    GREATEST(CEIL((total_elapsed_time / 1000.0) / 60.0), 1) * (8.0 / 60.0) * 3.0 as cost_on_large,
    warehouse_size,
    rows_produced
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    END_TIME_RANGE_START => DATEADD(hour, -1, CURRENT_TIMESTAMP())
))
WHERE query_text ILIKE '%controlled_expensive_query%'
    AND execution_status = 'SUCCESS'
ORDER BY start_time DESC
LIMIT 1;

-- Step 5: Resize back to X-Small to save money!
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'X-Small';


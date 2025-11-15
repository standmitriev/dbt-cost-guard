-- ============================================================================
-- CREATE MASSIVE DATASETS FOR 5-20 MINUTE QUERIES
-- ============================================================================
--
-- GOAL: Create datasets large enough that complex queries take 5-20 minutes
--
-- STRATEGY:
--   1. Use Snowflake's GENERATOR function to create millions/billions of rows
--   2. Add realistic relationships between tables
--   3. Create tables that will cause expensive JOINs and aggregations
--
-- ⚠️  WARNING: This will create LARGE tables (10M+ rows each)
-- ⚠️  This WILL cost money to run and store
-- ============================================================================

USE DATABASE ANALYTICS_DB;
USE SCHEMA RAW;

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- STEP 1: Create HUGE fact tables (millions of rows)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Create 10 MILLION web events (was 1M)
CREATE OR REPLACE TABLE web_events_large AS
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ8()) as event_id,
    UNIFORM(1, 100000, RANDOM()) as user_id,  -- 100K unique users
    UNIFORM(1, 200000, RANDOM()) as session_id,
    DATEADD(
        second,
        UNIFORM(0, 31536000, RANDOM()),  -- Random time in past year
        DATEADD(year, -1, CURRENT_TIMESTAMP())
    ) as event_timestamp,
    CASE UNIFORM(1, 10, RANDOM())
        WHEN 1 THEN 'page_view'
        WHEN 2 THEN 'click'
        WHEN 3 THEN 'scroll'
        WHEN 4 THEN 'form_submit'
        WHEN 5 THEN 'search'
        WHEN 6 THEN 'add_to_cart'
        WHEN 7 THEN 'purchase'
        WHEN 8 THEN 'video_play'
        WHEN 9 THEN 'download'
        ELSE 'other'
    END as event_type,
    '/page/' || UNIFORM(1, 1000, RANDOM()) as page_url,
    'https://referrer.com/' || UNIFORM(1, 500, RANDOM()) as referrer_url,
    UNIFORM(1, 300, RANDOM()) as time_on_page_seconds,
    UNIFORM(0, 100, RANDOM()) as scroll_depth_percent
FROM TABLE(GENERATOR(ROWCOUNT => 10000000));  -- 10 MILLION rows

-- Create 5 MILLION orders (was 150K)
CREATE OR REPLACE TABLE orders_large AS
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ8()) as order_id,
    UNIFORM(1, 100000, RANDOM()) as customer_id,
    DATEADD(
        day,
        UNIFORM(0, 730, RANDOM()),  -- Random time in past 2 years
        DATEADD(year, -2, CURRENT_TIMESTAMP())
    ) as order_date,
    UNIFORM(10, 5000, RANDOM()) / 100.0 as total_amount,
    CASE UNIFORM(1, 5, RANDOM())
        WHEN 1 THEN 'pending'
        WHEN 2 THEN 'processing'
        WHEN 3 THEN 'shipped'
        WHEN 4 THEN 'delivered'
        ELSE 'cancelled'
    END as status,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'credit_card'
        WHEN 2 THEN 'paypal'
        WHEN 3 THEN 'bank_transfer'
        ELSE 'crypto'
    END as payment_method
FROM TABLE(GENERATOR(ROWCOUNT => 5000000));  -- 5 MILLION rows

-- Create 20 MILLION order items (was 500K)
CREATE OR REPLACE TABLE order_items_large AS
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ8()) as order_item_id,
    UNIFORM(1, 5000000, RANDOM()) as order_id,  -- Reference orders_large
    UNIFORM(1, 100000, RANDOM()) as customer_id,
    UNIFORM(1, 50000, RANDOM()) as product_id,
    UNIFORM(1, 10, RANDOM()) as quantity,
    UNIFORM(5, 500, RANDOM()) / 100.0 as unit_price,
    UNIFORM(0, 50, RANDOM()) / 100.0 as discount_amount
FROM TABLE(GENERATOR(ROWCOUNT => 20000000));  -- 20 MILLION rows

-- Create 100K customers (was 50K)
CREATE OR REPLACE TABLE customers_large AS
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ8()) as customer_id,
    'customer_' || customer_id as customer_name,
    'customer' || customer_id || '@example.com' as email,
    DATEADD(
        day,
        UNIFORM(0, 3650, RANDOM()),  -- Random time in past 10 years
        DATEADD(year, -10, CURRENT_TIMESTAMP())
    ) as created_at,
    CASE UNIFORM(1, 5, RANDOM())
        WHEN 1 THEN 'bronze'
        WHEN 2 THEN 'silver'
        WHEN 3 THEN 'gold'
        WHEN 4 THEN 'platinum'
        ELSE 'diamond'
    END as customer_tier,
    UNIFORM(0, 100000, RANDOM()) / 100.0 as lifetime_value
FROM TABLE(GENERATOR(ROWCOUNT => 100000));

-- Create 50K products (was 10K)
CREATE OR REPLACE TABLE products_large AS
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ8()) as product_id,
    'Product ' || product_id as product_name,
    CASE UNIFORM(1, 10, RANDOM())
        WHEN 1 THEN 'Electronics'
        WHEN 2 THEN 'Clothing'
        WHEN 3 THEN 'Food'
        WHEN 4 THEN 'Books'
        WHEN 5 THEN 'Toys'
        WHEN 6 THEN 'Sports'
        WHEN 7 THEN 'Home'
        WHEN 8 THEN 'Beauty'
        WHEN 9 THEN 'Automotive'
        ELSE 'Other'
    END as category,
    UNIFORM(5, 1000, RANDOM()) / 100.0 as price,
    UNIFORM(0, 10000, RANDOM()) as stock_quantity
FROM TABLE(GENERATOR(ROWCOUNT => 50000));

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- STEP 2: Create tables optimized for EXPENSIVE queries
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Time series data (great for window functions)
CREATE OR REPLACE TABLE time_series_metrics AS
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ8()) as metric_id,
    UNIFORM(1, 10000, RANDOM()) as entity_id,
    DATEADD(
        minute,
        UNIFORM(0, 525600, RANDOM()),  -- Every minute in a year
        DATEADD(year, -1, CURRENT_TIMESTAMP())
    ) as timestamp,
    UNIFORM(0, 1000, RANDOM()) / 10.0 as value,
    CASE UNIFORM(1, 5, RANDOM())
        WHEN 1 THEN 'cpu_usage'
        WHEN 2 THEN 'memory_usage'
        WHEN 3 THEN 'disk_io'
        WHEN 4 THEN 'network_traffic'
        ELSE 'error_rate'
    END as metric_type
FROM TABLE(GENERATOR(ROWCOUNT => 50000000));  -- 50 MILLION time series points!

-- User interactions (many-to-many relationships)
CREATE OR REPLACE TABLE user_interactions AS
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ8()) as interaction_id,
    UNIFORM(1, 100000, RANDOM()) as user_id,
    UNIFORM(1, 100000, RANDOM()) as target_user_id,  -- Another user
    DATEADD(
        hour,
        UNIFORM(0, 8760, RANDOM()),
        DATEADD(year, -1, CURRENT_TIMESTAMP())
    ) as interaction_time,
    CASE UNIFORM(1, 6, RANDOM())
        WHEN 1 THEN 'like'
        WHEN 2 THEN 'comment'
        WHEN 3 THEN 'share'
        WHEN 4 THEN 'follow'
        WHEN 5 THEN 'message'
        ELSE 'block'
    END as interaction_type,
    UNIFORM(1, 50, RANDOM()) as duration_seconds
FROM TABLE(GENERATOR(ROWCOUNT => 30000000));  -- 30 MILLION interactions

-- Product views (for recommendation engines)
CREATE OR REPLACE TABLE product_views AS
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ8()) as view_id,
    UNIFORM(1, 100000, RANDOM()) as user_id,
    UNIFORM(1, 50000, RANDOM()) as product_id,
    DATEADD(
        second,
        UNIFORM(0, 31536000, RANDOM()),
        DATEADD(year, -1, CURRENT_TIMESTAMP())
    ) as view_time,
    UNIFORM(1, 300, RANDOM()) as view_duration_seconds,
    UNIFORM(0, 100, RANDOM()) as engagement_score
FROM TABLE(GENERATOR(ROWCOUNT => 100000000));  -- 100 MILLION product views!

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- STEP 3: Verify table sizes
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SELECT
    table_name,
    row_count,
    ROUND(bytes / (1024 * 1024 * 1024), 2) as size_gb,
    ROUND(bytes / row_count, 0) as avg_bytes_per_row
FROM ANALYTICS_DB.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'RAW'
  AND table_type = 'BASE TABLE'
  AND table_name LIKE '%_large'
ORDER BY row_count DESC;

-- Expected output:
--   product_views:          100M rows, ~15 GB
--   time_series_metrics:     50M rows, ~8 GB
--   user_interactions:       30M rows, ~5 GB
--   order_items_large:       20M rows, ~3 GB
--   web_events_large:        10M rows, ~2 GB
--   orders_large:             5M rows, ~1 GB
--   TOTAL:                  215M rows, ~34 GB

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- STEP 4: Update sources in dbt to use _large tables
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- After running this, update test_project/models/sources.yml to reference:
--   - web_events_large
--   - orders_large
--   - order_items_large
--   - customers_large
--   - products_large
--   - time_series_metrics (new!)
--   - user_interactions (new!)
--   - product_views (new!)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- BONUS: Test query to verify it's expensive
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- This query should take 2-5 minutes on X-Small warehouse
-- (or 30-60 seconds on Large warehouse)
/*
SELECT
    u.user_id,
    COUNT(DISTINCT pv.product_id) as products_viewed,
    COUNT(DISTINCT we.event_id) as total_events,
    COUNT(DISTINCT o.order_id) as total_orders,
    SUM(oi.quantity * oi.unit_price) as total_spent,
    
    -- Expensive window functions
    ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT pv.product_id) DESC) as view_rank,
    PERCENT_RANK() OVER (ORDER BY SUM(oi.quantity * oi.unit_price)) as spending_percentile,
    AVG(COUNT(DISTINCT we.event_id)) OVER (
        ORDER BY u.user_id 
        ROWS BETWEEN 1000 PRECEDING AND 1000 FOLLOWING
    ) as rolling_avg_events
    
FROM customers_large u
LEFT JOIN web_events_large we ON u.customer_id = we.user_id
LEFT JOIN product_views pv ON u.customer_id = pv.user_id
LEFT JOIN orders_large o ON u.customer_id = o.customer_id
LEFT JOIN order_items_large oi ON o.order_id = oi.order_id
GROUP BY u.user_id;
*/

-- ============================================================================
-- CLEANUP (run this to remove large tables and save storage costs)
-- ============================================================================
/*
DROP TABLE IF EXISTS web_events_large;
DROP TABLE IF EXISTS orders_large;
DROP TABLE IF EXISTS order_items_large;
DROP TABLE IF EXISTS customers_large;
DROP TABLE IF EXISTS products_large;
DROP TABLE IF EXISTS time_series_metrics;
DROP TABLE IF EXISTS user_interactions;
DROP TABLE IF EXISTS product_views;
*/


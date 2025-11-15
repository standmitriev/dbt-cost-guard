-- ============================================================================
-- VALIDATE dbt-cost-guard ESTIMATES vs ACTUAL COSTS
-- ============================================================================

-- Step 1: Note the current time
SELECT CURRENT_TIMESTAMP() as start_time;

-- Step 2: Run one of the staging models manually
-- This mimics what dbt would do
CREATE OR REPLACE TABLE ANALYTICS_DB.DBT_COST_GUARD_TEST.stg_sales__customers_test AS
SELECT
    customer_id,
    customer_name,
    customer_email,
    signup_date,
    DATE_PART('year', signup_date) as signup_year,
    DATE_PART('month', signup_date) as signup_month
FROM SALES_DB.RAW.customers;

-- Step 3: Note the end time
SELECT CURRENT_TIMESTAMP() as end_time;

-- Step 4: Wait a few seconds for QUERY_HISTORY to update
SELECT SYSTEM$WAIT(5, 'SECONDS');

-- Step 5: Check the query history for our query
-- Look at the last few queries from this session
SELECT
    query_id,
    query_text,
    warehouse_name,
    warehouse_size,
    database_name,
    schema_name,
    start_time,
    end_time,
    total_elapsed_time / 1000 as execution_seconds,
    credits_used_cloud_services,
    bytes_scanned,
    rows_produced,
    -- Calculate cost
    (total_elapsed_time / 1000.0 / 3600.0) * 
        CASE warehouse_size
            WHEN 'X-Small' THEN 1
            WHEN 'Small' THEN 2
            WHEN 'Medium' THEN 4
            WHEN 'Large' THEN 8
            WHEN 'X-Large' THEN 16
            ELSE 1
        END * 3.0 as estimated_cost_dollars
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_text LIKE '%stg_sales__customers_test%'
    AND query_text LIKE '%CREATE OR REPLACE TABLE%'
    AND start_time >= DATEADD(minute, -5, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 1;

-- Step 6: Also check warehouse metering history
SELECT
    warehouse_name,
    start_time,
    end_time,
    credits_used,
    credits_used * 3.0 as cost_dollars
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'COMPUTE_WH'
    AND start_time >= DATEADD(hour, -1, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 10;


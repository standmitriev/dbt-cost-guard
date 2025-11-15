-- ============================================================================
-- TEST INSANE QUERY: Run a CONTROLLED expensive query
-- This is a SAFE version that won't actually run for hours
-- ============================================================================

-- Step 1: Get dbt-cost-guard estimate for one of the insane models
-- Run this first: dbt-cost-guard --project-dir test_project analyze -m fct_self_join_explosion

-- Step 2: Run a CONTROLLED expensive query (not the full insane one!)
-- This version limits the data to make it safe to run
CREATE OR REPLACE TABLE ANALYTICS_DB.DBT_COST_GUARD_TEST.test_expensive_query AS
WITH limited_events AS (
    -- Only use 1000 rows instead of 1M!
    SELECT * FROM ANALYTICS_DB.RAW.web_events
    LIMIT 1000
),

-- Self-join on the limited dataset
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
    FROM limited_events e1
    INNER JOIN limited_events e2
        ON e1.user_id = e2.user_id
        AND e2.event_timestamp > e1.event_timestamp
        AND e2.event_timestamp <= DATEADD(hour, 1, e1.event_timestamp)
),

-- Add window functions
with_analytics AS (
    SELECT
        *,
        ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY event1_timestamp) as event_sequence,
        LAG(event1_timestamp, 1) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as prev_event,
        LEAD(event1_timestamp, 1) OVER (PARTITION BY user_id ORDER BY event1_timestamp) as next_event,
        SUM(time_diff_seconds) OVER (PARTITION BY user_id ORDER BY event1_timestamp ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as running_total,
        AVG(time_diff_seconds) OVER (PARTITION BY user_id ORDER BY event1_timestamp ROWS BETWEEN 10 PRECEDING AND CURRENT ROW) as rolling_avg
    FROM same_user_events
)

SELECT * FROM with_analytics
WHERE event_sequence <= 50;

-- Step 3: Check the actual cost
SELECT
    '═════════════════════════════════════════════════════════════' as separator,
    'EXPENSIVE QUERY VALIDATION' as title,
    '═════════════════════════════════════════════════════════════' as separator;

SELECT
    query_id,
    LEFT(query_text, 80) as query_preview,
    warehouse_size,
    execution_status,
    total_elapsed_time / 1000.0 as execution_seconds,
    bytes_scanned / (1024.0 * 1024.0) as mb_scanned,
    rows_produced,
    rows_inserted,
    -- Calculate cost
    ROUND((total_elapsed_time / 1000.0 / 3600.0) * 
        CASE warehouse_size
            WHEN 'X-Small' THEN 1
            WHEN 'Small' THEN 2
            WHEN 'Medium' THEN 4
            WHEN 'Large' THEN 8
            WHEN 'X-Large' THEN 16
            ELSE 1
        END * 3.0, 4) as actual_cost_raw,
    -- Billed cost (1-minute minimum)
    GREATEST(
        CEIL((total_elapsed_time / 1000.0) / 60.0), 1
    ) * (1.0 / 60.0) * 
        CASE warehouse_size
            WHEN 'X-Small' THEN 1
            WHEN 'Small' THEN 2
            WHEN 'Medium' THEN 4
            WHEN 'Large' THEN 8
            WHEN 'X-Large' THEN 16
            ELSE 1
        END * 3.0 as billed_cost_dollars
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    END_TIME_RANGE_START => DATEADD(minute, -10, CURRENT_TIMESTAMP())
))
WHERE query_text ILIKE '%test_expensive_query%'
    AND query_text LIKE '%CREATE OR REPLACE TABLE%'
    AND query_text NOT ILIKE '%INFORMATION_SCHEMA%'
    AND execution_status = 'SUCCESS'
ORDER BY start_time DESC
LIMIT 1;

-- Step 4: Detailed comparison
SELECT
    '═════════════════════════════════════════════════════════════' as separator,
    'COST BREAKDOWN' as title,
    '═════════════════════════════════════════════════════════════' as separator;

SELECT
    -- Actual metrics
    ROUND(total_elapsed_time / 1000.0, 2) as actual_seconds,
    ROUND((total_elapsed_time / 1000.0 / 3600.0) * 1 * 3.0, 4) as actual_cost_raw,
    GREATEST(CEIL((total_elapsed_time / 1000.0) / 60.0), 1) as billed_minutes,
    ROUND(GREATEST(CEIL((total_elapsed_time / 1000.0) / 60.0), 1) * (1.0 / 60.0) * 1 * 3.0, 2) as billed_cost,
    
    -- Complexity indicators
    ROUND(bytes_scanned / (1024.0 * 1024.0), 2) as mb_scanned,
    rows_produced,
    rows_inserted,
    
    -- Cost components
    '1 credit/hour (X-Small)' as warehouse_rate,
    '$3.00/credit' as credit_cost,
    CASE 
        WHEN total_elapsed_time / 1000.0 < 60 THEN 'Hit 1-minute minimum'
        ELSE 'Actual time billing'
    END as billing_note
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    END_TIME_RANGE_START => DATEADD(minute, -10, CURRENT_TIMESTAMP())
))
WHERE query_text ILIKE '%test_expensive_query%'
    AND query_text LIKE '%CREATE OR REPLACE TABLE%'
    AND query_text NOT ILIKE '%INFORMATION_SCHEMA%'
    AND execution_status = 'SUCCESS'
ORDER BY start_time DESC
LIMIT 1;

-- Cleanup
-- DROP TABLE IF EXISTS ANALYTICS_DB.DBT_COST_GUARD_TEST.test_expensive_query;


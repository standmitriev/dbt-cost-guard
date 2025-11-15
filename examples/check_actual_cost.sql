-- ============================================================================
-- CHECK ACTUAL COST FOR stg_sales__customers
-- Run this in Snowflake SQL Worksheet IMMEDIATELY after running the model
-- ============================================================================

-- Get the most recent execution
-- Note: Use the database you're connected to, or specify fully qualified name
SELECT
    query_id,
    LEFT(query_text, 100) as query_preview,
    warehouse_name,
    warehouse_size,
    execution_status,
    start_time,
    end_time,
    total_elapsed_time / 1000.0 as execution_seconds,
    bytes_scanned,
    bytes_scanned / (1024.0 * 1024.0) as mb_scanned,
    rows_produced
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    END_TIME_RANGE_START => DATEADD(hour, -1, CURRENT_TIMESTAMP())
))
WHERE query_text ILIKE '%stg_sales__customers%'
    AND query_text NOT ILIKE '%INFORMATION_SCHEMA%'  -- Exclude this query itself
    AND execution_status = 'SUCCESS'
ORDER BY start_time DESC
LIMIT 5;

-- Calculate the cost
SELECT
    '═════════════════════════════════════════════════════════════' as separator,
    'COST CALCULATION FOR stg_sales__customers' as title,
    '═════════════════════════════════════════════════════════════' as separator;

SELECT
    warehouse_size,
    total_elapsed_time / 1000.0 as actual_execution_seconds,
    
    -- Actual cost (based on actual time)
    ROUND((total_elapsed_time / 1000.0 / 3600.0) * 
        CASE warehouse_size
            WHEN 'X-Small' THEN 1
            WHEN 'Small' THEN 2
            WHEN 'Medium' THEN 4
            WHEN 'Large' THEN 8
            WHEN 'X-Large' THEN 16
            ELSE 1
        END * 3.0, 4) as actual_cost_dollars,
    
    -- Billed cost (Snowflake bills per minute, 60s minimum)
    GREATEST(
        CEIL((total_elapsed_time / 1000.0) / 60.0),  -- Round up to minutes
        1  -- Minimum 1 minute
    ) * (1.0 / 60.0) * 
        CASE warehouse_size
            WHEN 'X-Small' THEN 1
            WHEN 'Small' THEN 2
            WHEN 'Medium' THEN 4
            WHEN 'Large' THEN 8
            WHEN 'X-Large' THEN 16
            ELSE 1
        END * 3.0 as billed_cost_dollars,
    
    -- For comparison
    '1.7s' as dbt_cost_guard_estimate_time,
    '$0.05' as dbt_cost_guard_estimate_cost,
    
    -- Difference
    ROUND(total_elapsed_time / 1000.0 - 1.7, 2) as time_diff_seconds,
    ROUND((GREATEST(CEIL((total_elapsed_time / 1000.0) / 60.0), 1) * (1.0 / 60.0) * 1 * 3.0) - 0.05, 4) as cost_diff_dollars
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    END_TIME_RANGE_START => DATEADD(hour, -1, CURRENT_TIMESTAMP())
))
WHERE query_text ILIKE '%stg_sales__customers%'
    AND query_text NOT ILIKE '%INFORMATION_SCHEMA%'
    AND execution_status = 'SUCCESS'
ORDER BY start_time DESC
LIMIT 1;

-- Summary
SELECT
    '═════════════════════════════════════════════════════════════' as separator,
    'VALIDATION SUMMARY' as title,
    '═════════════════════════════════════════════════════════════' as separator;

SELECT
    CASE 
        WHEN ABS(total_elapsed_time / 1000.0 - 1.7) <= 1.0 THEN '✅ ACCURATE'
        WHEN ABS(total_elapsed_time / 1000.0 - 1.7) <= 5.0 THEN '⚠️  CLOSE'
        ELSE '❌ OFF'
    END as time_accuracy,
    CASE 
        WHEN GREATEST(CEIL((total_elapsed_time / 1000.0) / 60.0), 1) * (1.0 / 60.0) * 1 * 3.0 = 0.05 THEN '✅ ACCURATE'
        ELSE '❌ OFF'
    END as cost_accuracy,
    ROUND(total_elapsed_time / 1000.0, 2) as actual_seconds,
    1.7 as estimated_seconds,
    ROUND(GREATEST(CEIL((total_elapsed_time / 1000.0) / 60.0), 1) * (1.0 / 60.0) * 1 * 3.0, 2) as actual_cost,
    0.05 as estimated_cost
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    END_TIME_RANGE_START => DATEADD(hour, -1, CURRENT_TIMESTAMP())
))
WHERE query_text ILIKE '%stg_sales__customers%'
    AND query_text NOT ILIKE '%INFORMATION_SCHEMA%'
    AND execution_status = 'SUCCESS'
ORDER BY start_time DESC
LIMIT 1;


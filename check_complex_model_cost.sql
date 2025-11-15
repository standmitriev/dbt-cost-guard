-- ============================================================================
-- CHECK ACTUAL COST FOR fct_orders_enriched
-- Run this in Snowflake SQL Worksheet
-- ============================================================================

-- Quick summary
SELECT
    '══════════════════════════════════════════════════════════════════════' as separator,
    'VALIDATION: fct_orders_enriched' as title,
    '══════════════════════════════════════════════════════════════════════' as separator;

-- Get actual metrics
SELECT
    query_id,
    LEFT(query_text, 100) as query_preview,
    warehouse_size,
    total_elapsed_time / 1000.0 as actual_seconds,
    bytes_scanned / (1024.0 * 1024.0) as mb_scanned,
    rows_produced,
    rows_inserted,
    
    -- Calculate costs
    ROUND((total_elapsed_time / 1000.0 / 3600.0) * 1 * 3.0, 4) as actual_cost_raw,
    GREATEST(CEIL((total_elapsed_time / 1000.0) / 60.0), 1) * 0.05 as billed_cost,
    
    -- Compare with estimate
    1.8 as estimated_seconds,
    0.05 as estimated_cost,
    ROUND(total_elapsed_time / 1000.0 - 1.8, 2) as time_diff_seconds,
    
    -- Accuracy
    CASE 
        WHEN ABS(total_elapsed_time / 1000.0 - 1.8) <= 2.0 THEN '✅ ACCURATE'
        WHEN ABS(total_elapsed_time / 1000.0 - 1.8) <= 5.0 THEN '⚠️  CLOSE'
        ELSE '❌ OFF'
    END as time_accuracy,
    
    CASE 
        WHEN GREATEST(CEIL((total_elapsed_time / 1000.0) / 60.0), 1) * 0.05 = 0.05 THEN '✅ ACCURATE'
        ELSE '❌ OFF'
    END as cost_accuracy

FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    END_TIME_RANGE_START => DATEADD(minute, -10, CURRENT_TIMESTAMP())
))
WHERE query_text ILIKE '%fct_orders_enriched%'
    AND query_text LIKE '%CREATE TABLE%'
    AND query_text NOT ILIKE '%INFORMATION_SCHEMA%'
    AND execution_status = 'SUCCESS'
ORDER BY start_time DESC
LIMIT 1;

-- Detailed breakdown
SELECT
    '══════════════════════════════════════════════════════════════════════' as separator,
    'DETAILED COST BREAKDOWN' as title,
    '══════════════════════════════════════════════════════════════════════' as separator;

SELECT
    -- Actual execution
    ROUND(total_elapsed_time / 1000.0, 2) as actual_execution_seconds,
    ROUND((total_elapsed_time / 1000.0 / 3600.0), 6) as actual_hours,
    
    -- Billing calculation
    CEIL((total_elapsed_time / 1000.0) / 60.0) as computed_minutes,
    GREATEST(CEIL((total_elapsed_time / 1000.0) / 60.0), 1) as billed_minutes,
    
    -- Cost calculation
    ROUND((1.0 / 60.0) * 1 * 3.0, 4) as cost_per_minute,
    ROUND(GREATEST(CEIL((total_elapsed_time / 1000.0) / 60.0), 1) * (1.0 / 60.0) * 1 * 3.0, 2) as total_billed_cost,
    
    -- Metadata
    '1 credit/hour (X-Small)' as warehouse_rate,
    '$3.00/credit' as credit_cost,
    
    -- Explanation
    CASE 
        WHEN total_elapsed_time / 1000.0 < 60 THEN 'Hit 1-minute billing minimum ($0.05)'
        ELSE 'Billed for actual time (rounded to minutes)'
    END as billing_explanation

FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    END_TIME_RANGE_START => DATEADD(minute, -10, CURRENT_TIMESTAMP())
))
WHERE query_text ILIKE '%fct_orders_enriched%'
    AND query_text LIKE '%CREATE TABLE%'
    AND query_text NOT ILIKE '%INFORMATION_SCHEMA%'
    AND execution_status = 'SUCCESS'
ORDER BY start_time DESC
LIMIT 1;

-- Final summary
SELECT
    '══════════════════════════════════════════════════════════════════════' as separator,
    'VALIDATION RESULT' as title,
    '══════════════════════════════════════════════════════════════════════' as separator;

SELECT
    'fct_orders_enriched (6 JOINs, 8 windows, Complexity 100)' as model,
    CONCAT(ROUND(total_elapsed_time / 1000.0, 2), 's') as actual_time,
    '1.8s' as estimated_time,
    CONCAT('$', ROUND(GREATEST(CEIL((total_elapsed_time / 1000.0) / 60.0), 1) * 0.05, 2)) as actual_cost,
    '$0.05' as estimated_cost,
    CASE 
        WHEN ABS(total_elapsed_time / 1000.0 - 1.8) <= 2.0 
             AND GREATEST(CEIL((total_elapsed_time / 1000.0) / 60.0), 1) * 0.05 = 0.05
        THEN '✅ COST CALCULATION IS ACCURATE!'
        ELSE '⚠️  Check calculations'
    END as validation_result
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY(
    END_TIME_RANGE_START => DATEADD(minute, -10, CURRENT_TIMESTAMP())
))
WHERE query_text ILIKE '%fct_orders_enriched%'
    AND query_text LIKE '%CREATE TABLE%'
    AND query_text NOT ILIKE '%INFORMATION_SCHEMA%'
    AND execution_status = 'SUCCESS'
ORDER BY start_time DESC
LIMIT 1;


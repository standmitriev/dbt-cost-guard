# Validate dbt-cost-guard Accuracy

This guide will help you run actual models in Snowflake and compare the real costs with dbt-cost-guard estimates.

## Step 1: Get dbt-cost-guard Estimate

First, let's see what dbt-cost-guard predicts:

```bash
cd /Users/stan.dmitriev/Documents/dbt-cost
source venv/bin/activate

# Estimate a simple staging model
dbt-cost-guard --project-dir test_project analyze -m stg_sales__customers
```

**Note the:**
- Estimated Cost
- Estimated Time
- Complexity Score

---

## Step 2: Run the Model with dbt

Now run the actual model:

```bash
# Make sure warehouse is running
dbt-cost-guard --project-dir test_project run --select stg_sales__customers
```

**Or run without cost guard to see raw dbt output:**

```bash
cd test_project
dbt run --select stg_sales__customers --profiles-dir .
```

---

## Step 3: Check Actual Cost in Snowflake

### Option A: Using INFORMATION_SCHEMA.QUERY_HISTORY (Immediate)

Run this in Snowflake SQL Worksheet:

```sql
-- Get the most recent query for stg_sales__customers
SELECT
    query_id,
    query_text,
    warehouse_name,
    warehouse_size,
    execution_status,
    start_time,
    end_time,
    total_elapsed_time / 1000.0 as execution_seconds,
    bytes_scanned,
    rows_produced
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE query_text ILIKE '%stg_sales__customers%'
    AND execution_status = 'SUCCESS'
    AND start_time >= DATEADD(minute, -10, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 5;
```

### Option B: Using ACCOUNT_USAGE.QUERY_HISTORY (More detailed, 45min latency)

```sql
SELECT
    query_id,
    query_text,
    warehouse_name,
    warehouse_size,
    database_name,
    execution_status,
    start_time,
    end_time,
    total_elapsed_time / 1000.0 as execution_seconds,
    credits_used_cloud_services,
    bytes_scanned,
    rows_produced,
    rows_inserted,
    -- Calculate actual cost
    (total_elapsed_time / 1000.0 / 3600.0) * 
        CASE warehouse_size
            WHEN 'X-Small' THEN 1
            WHEN 'Small' THEN 2
            WHEN 'Medium' THEN 4
            WHEN 'Large' THEN 8
            WHEN 'X-Large' THEN 16
            ELSE 1
        END * 3.0 as estimated_cost_dollars,
    -- Snowflake bills per minute with 60s minimum
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
        END * 3.0 as billed_cost_dollars
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_text ILIKE '%stg_sales__customers%'
    AND execution_status = 'SUCCESS'
    AND start_time >= DATEADD(hour, -1, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 5;
```

---

## Step 4: Compare Results

Create a comparison table:

| Metric | dbt-cost-guard Estimate | Actual (Snowflake) | Difference |
|--------|------------------------|-------------------|------------|
| Execution Time | ? seconds | ? seconds | ? |
| Cost (actual time) | $?.?? | $?.?? | ? |
| Cost (billed - 1min min) | $?.?? | $?.?? | ? |

---

## Step 5: Test a Complex Model

Repeat the process with a more complex model:

```bash
# Estimate
dbt-cost-guard --project-dir test_project analyze -m fct_orders_enriched

# Run
dbt-cost-guard --project-dir test_project run --select fct_orders_enriched
```

Then check in Snowflake:

```sql
SELECT
    query_text,
    warehouse_size,
    total_elapsed_time / 1000.0 as execution_seconds,
    rows_produced,
    GREATEST(
        CEIL((total_elapsed_time / 1000.0) / 60.0), 1
    ) * (1.0 / 60.0) * 
        CASE warehouse_size
            WHEN 'X-Small' THEN 1 ELSE 1 END * 3.0 as billed_cost_dollars
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE query_text ILIKE '%fct_orders_enriched%'
    AND execution_status = 'SUCCESS'
    AND start_time >= DATEADD(minute, -10, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 1;
```

---

## Step 6: Check Warehouse Credits Used

To see total credits consumed:

```sql
-- Warehouse metering (1-hour granularity)
SELECT
    warehouse_name,
    start_time,
    end_time,
    credits_used,
    credits_used * 3.0 as cost_dollars
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'COMPUTE_WH'
    AND start_time >= DATEADD(hour, -2, CURRENT_TIMESTAMP())
ORDER BY start_time DESC;
```

---

## Expected Results

For **stg_sales__customers** on X-Small warehouse:
- **Estimated**: 1.7s, $0.05 (1-minute minimum)
- **Actual**: ~1-2s, $0.05 (1-minute minimum)
- **Accuracy**: ✅ Should match closely

For **fct_orders_enriched** on X-Small warehouse:
- **Estimated**: 6.0s, $0.05 (1-minute minimum)
- **Actual**: ~5-10s, $0.05 (1-minute minimum)
- **Accuracy**: ✅ Should match the billing

---

## Notes

1. **ACCOUNT_USAGE views have 45min-3hr latency** - use INFORMATION_SCHEMA for immediate results
2. **Snowflake bills per minute** - anything under 60s costs the same
3. **Cloud services credits** are separate and sometimes free (up to 10% of compute)
4. **Estimates are conservative** - actual may be faster due to caching

---

## Validation Script

You can also run: `validate_costs.sql` in Snowflake to automate the comparison.


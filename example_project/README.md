# Example dbt Project for Cost Guard Testing

This is a sample dbt project that demonstrates various cost scenarios for testing dbt-cost-guard.

## Project Structure

```
example_project/
├── models/
│   ├── staging/
│   │   ├── stg_users.sql          # Low cost - simple view
│   │   ├── stg_orders.sql         # Low cost - simple view
│   │   └── stg_products.sql       # Skips cost check
│   └── marts/
│       ├── dim_customers.sql      # Medium cost - aggregations
│       ├── fct_order_items.sql    # High cost - complex joins & windows
│       └── daily_product_metrics.sql  # Very high cost - multiple windows
├── dbt_project.yml
└── profiles.yml
```

## Models Overview

### Staging Models (Low Cost)
- **stg_users**: Simple SELECT with WHERE clause
- **stg_orders**: Simple SELECT with WHERE clause  
- **stg_products**: Demonstrates cost_guard_skip config

### Mart Models (Varying Cost)
- **dim_customers** (Medium): 
  - Aggregations with GROUP BY
  - CTEs
  - CASE statements
  - Expected cost: ~$1-2

- **fct_order_items** (High):
  - Multiple table joins
  - Window functions (ROW_NUMBER, LAG, LEAD, DENSE_RANK)
  - Running totals
  - Expected cost: ~$5-7 (should trigger warning)

- **daily_product_metrics** (Very High):
  - Complex aggregations over large datasets
  - Multiple rolling window calculations (7-day, 30-day)
  - Year-over-year comparisons
  - Cumulative metrics
  - Expected cost: ~$10-15 (should definitely trigger warning)

## Setup

1. Update `profiles.yml` with your Snowflake credentials:

```yaml
example_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: YOUR_ACCOUNT
      user: YOUR_USER
      password: YOUR_PASSWORD
      role: YOUR_ROLE
      database: YOUR_DATABASE
      warehouse: YOUR_WAREHOUSE
      schema: dbt_cost_guard_demo
```

2. Create sample tables (or use your own):

```sql
-- Create raw schema and sample tables
CREATE SCHEMA IF NOT EXISTS raw;

CREATE TABLE raw.users AS
SELECT 
    SEQ4() as id,
    'user' || SEQ4() || '@example.com' as email,
    'First' || SEQ4() as first_name,
    'Last' || SEQ4() as last_name,
    DATEADD(day, -UNIFORM(1, 1000, RANDOM()), CURRENT_DATE()) as created_at,
    CURRENT_TIMESTAMP() as updated_at,
    NULL as deleted_at
FROM TABLE(GENERATOR(ROWCOUNT => 10000));

CREATE TABLE raw.orders AS
SELECT
    SEQ4() as id,
    UNIFORM(1, 10000, RANDOM()) as user_id,
    DATEADD(day, -UNIFORM(1, 365, RANDOM()), CURRENT_DATE()) as order_date,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'pending'
        WHEN 2 THEN 'completed'
        WHEN 3 THEN 'shipped'
        ELSE 'delivered'
    END as status,
    UNIFORM(10, 1000, RANDOM()) as total_amount,
    CURRENT_TIMESTAMP() as created_at,
    NULL as deleted_at
FROM TABLE(GENERATOR(ROWCOUNT => 50000));
```

## Testing Cost Guard

### Test 1: Run All Models (Should Trigger Warnings)

```bash
dbt-cost-guard run --project-dir example_project

# Expected: Total cost > $5, fct_order_items > $5
# Should prompt for confirmation
```

### Test 2: Run Only Low-Cost Models

```bash
dbt-cost-guard run --project-dir example_project --models staging

# Expected: Total cost < $1
# Should run without warnings
```

### Test 3: Estimate Without Running

```bash
dbt-cost-guard estimate --project-dir example_project

# Shows cost breakdown without executing
```

### Test 4: Force Run (Skip Checks)

```bash
dbt-cost-guard run --project-dir example_project --force

# Bypasses all cost checks
```

### Test 5: Run Expensive Model Only

```bash
dbt-cost-guard run --project-dir example_project --models daily_product_metrics

# Expected: High cost warning for single model
```

## Expected Cost Breakdown

When running all models on a MEDIUM warehouse ($3/credit):

| Model | Complexity | Est. Time | Est. Cost | Warning |
|-------|------------|-----------|-----------|---------|
| stg_users | Low | 2s | $0.007 | ✓ |
| stg_orders | Low | 3s | $0.010 | ✓ |
| stg_products | Low | 0s | $0.000 (skipped) | ✓ |
| dim_customers | Medium | 45s | $0.15 | ✓ |
| fct_order_items | High | 320s | $1.07 | ⚠️ |
| daily_product_metrics | Very High | 180s | $0.60 | ⚠️ |
| **TOTAL** | | | **$1.90** | ✓ |

*Note: Actual costs will vary based on your warehouse size, data volume, and Snowflake optimization.*

## Customizing Thresholds

Edit `dbt_project.yml` to adjust warning thresholds:

```yaml
vars:
  cost_guard:
    warning_threshold_per_model: 2.0  # Lower threshold
    warning_threshold_total_run: 10.0  # Higher total threshold
```


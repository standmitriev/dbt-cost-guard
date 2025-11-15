# dbt-cost-guard Enhanced Test Project

This is a comprehensive test project for `dbt-cost-guard` featuring:

## Project Structure

```
test_project/
├── models/
│   ├── staging/              # Simple views from source data
│   │   ├── stg_sales__*.sql          # From SALES_DB
│   │   ├── stg_analytics__*.sql      # From ANALYTICS_DB
│   │   └── stg_reference__*.sql      # From REFERENCE_DB
│   │
│   ├── intermediate/         # Ephemeral transformation models
│   │
│   └── marts/
│       ├── facts/           # Fact tables with various complexities
│       └── dimensions/      # Dimension tables
```

## Data Sources

### SALES_DB (Transactional Data)
- **customers**: 50,000 records
- **orders**: 150,000 records  
- **order_items**: 500,000 records
- **products**: 10,000 records

### ANALYTICS_DB (Behavioral Data)
- **web_events**: 1,000,000 records (large!)
- **marketing_campaigns**: 200 records
- **campaign_attributions**: 100,000 records

### REFERENCE_DB (Lookup Data)
- **geography**: 1,000 records
- **product_categories**: 100 records
- **date_dimension**: 1,095 records (3 years)

**Total: ~1.76 million records across 3 databases**

## Model Complexity Levels

### 🟢 LOW COST Models
- `stg_sales__customers` - Simple view, small table
- `stg_reference__geography` - Tiny lookup table

### 🟡 MEDIUM COST Models
- `stg_sales__orders` - Moderate table size with transformations
- `stg_sales__order_items` - JOIN with products table
- `dim_customers` - Aggregations across multiple tables

### 🟠 HIGH COST Models
- `stg_analytics__web_events` - Very large table (1M rows)
- `fct_web_events_sessionized` - Incremental with window functions
- `fct_daily_web_metrics` - Time-series with rolling averages

### 🔴 VERY HIGH COST Models
- `fct_orders_enriched` - Cross-database joins with many CTEs
- `fct_customer_analytics_extreme` - Kitchen sink (intentionally expensive!)

### 🔥 INSANELY EXPENSIVE Models (Test Only - DO NOT RUN!)
- `fct_cartesian_nightmare` - **CARTESIAN PRODUCT** (75 trillion potential rows!)
- `fct_self_join_explosion` - **5 SELF-JOINS** on 1M row table (exponential explosion!)
- `fct_cross_database_monster` - **CROSS-DB JOINS** with loose conditions + 30+ window functions

**⚠️ See [INSANE_MODELS.md](INSANE_MODELS.md) for details on these test models**

## Special Features Tested

### Cross-Database Queries
- `fct_orders_enriched` joins SALES_DB + ANALYTICS_DB + REFERENCE_DB
- Tests cost estimation across database boundaries

### Incremental Models
- `fct_web_events_sessionized` uses incremental materialization
- Tests cost difference between full-refresh and incremental runs

### Window Functions Galore
- Multiple models use 5-10+ window functions
- Tests complexity scoring for expensive operations

### Large Datasets
- `web_events` table has 1M rows
- Tests cost estimation on realistic data volumes

## Setup Instructions

1. **Run Snowflake setup:**
   ```sql
   -- In Snowflake SQL worksheet
   -- Run: setup_enhanced_snowflake.sql
   ```

2. **Configure credentials:**
   ```bash
   # Set environment variables
   export SNOWFLAKE_ACCOUNT="your_account"
   export SNOWFLAKE_USER="your_user"
   export SNOWFLAKE_PASSWORD="your_password"
   ```

3. **Test cost estimation:**
   ```bash
   # Estimate all models
   dbt-cost-guard --project-dir test_project estimate

   # Analyze specific expensive model
   dbt-cost-guard --project-dir test_project analyze -m fct_customer_analytics_extreme

   # Run with cost protection
   dbt-cost-guard --project-dir test_project run
   ```

## Expected Cost Estimates

| Model | Expected Cost | Why |
|-------|--------------|-----|
| stg_reference__geography | < $0.01 | Small lookup table |
| stg_sales__customers | ~$0.05 | Simple view |
| stg_analytics__web_events | ~$1.00 | 1M row scan |
| dim_customers | ~$2.00 | Multiple aggregations |
| fct_orders_enriched | ~$20.00 | Cross-DB joins + window functions |
| fct_customer_analytics_extreme | ~$50.00+ | Everything expensive |

## Testing Scenarios

### Scenario 1: Basic Estimation
```bash
dbt-cost-guard --project-dir test_project estimate
```
Should show costs ranging from $0.01 to $50+

### Scenario 2: Cost Warnings
```bash
dbt-cost-guard --threshold 5.0 --project-dir test_project run
```
Should warn about expensive models exceeding $5 threshold

### Scenario 3: Incremental Runs
```bash
# First run (full refresh - expensive)
dbt-cost-guard --project-dir test_project run --select fct_web_events_sessionized --full-refresh

# Second run (incremental - cheap)
dbt-cost-guard --project-dir test_project run --select fct_web_events_sessionized
```
Second run should be much cheaper!

### Scenario 4: Cross-Database Analysis
```bash
dbt-cost-guard --project-dir test_project analyze -m fct_orders_enriched
```
Should show dependencies across all 3 databases

### Scenario 5: Extreme Cost Detection
```bash
dbt-cost-guard --project-dir test_project analyze -m fct_customer_analytics_extreme
```
Should trigger high-cost warnings and recommendations

### Scenario 6: Insane Query Detection 🔥
```bash
# View estimates for the insanely expensive models
dbt-cost-guard --project-dir test_project estimate

# Trigger warnings with low threshold
dbt-cost-guard --threshold 0.04 --project-dir test_project estimate

# Analyze the cartesian product nightmare
dbt-cost-guard --project-dir test_project analyze -m fct_cartesian_nightmare
```
Should show:
- Complexity score: 100 (High)
- Execution time: 16.7+ seconds
- Multiple CROSS JOINs detected
- ⚠️ Warning symbols when threshold is low

**See [INSANE_MODELS.md](INSANE_MODELS.md) for detailed explanation of these test models**

## Configuration

Edit `.dbt-cost-guard.yml` to test different configurations:

```yaml
version: 1
cost_per_credit: 3.0

thresholds:
  per_model_warning: 10.00
  total_run_warning: 50.00

model_overrides:
  "fct_customer_analytics_extreme":
    threshold: 100.00  # Allow this one to be expensive
  "stg_*":
    threshold: 1.00    # Staging should be cheap

skip_models:
  - "test_*"
```

## Troubleshooting

### No data in tables
Run `setup_enhanced_snowflake.sql` in Snowflake

### Permission errors
Ensure SYSADMIN role has access to all 3 databases

### High costs on staging models
Check if tables are actually populated with data

---

**This test project demonstrates dbt-cost-guard's ability to:**
✅ Estimate costs across multiple databases
✅ Handle various materialization types
✅ Detect expensive operations (window functions, cross-database joins)
✅ Differentiate between incremental and full-refresh runs
✅ Provide accurate cost warnings before execution


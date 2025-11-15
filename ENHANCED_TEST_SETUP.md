# Enhanced Test Setup Guide

## Quick Start

This creates a comprehensive test environment for dbt-cost-guard with:
- **3 databases** (SALES_DB, ANALYTICS_DB, REFERENCE_DB)
- **1.76 million records** across 10 tables
- **Cross-database queries** to test complex scenarios
- **Various cost levels** from $0.01 to $50+

## Step 1: Run Snowflake Setup

```bash
# Copy the SQL to your clipboard
cat setup_enhanced_snowflake.sql | pbcopy  # Mac
# or
cat setup_enhanced_snowflake.sql | xclip -selection clipboard  # Linux

# Then in Snowflake web UI:
# 1. Open a SQL worksheet
# 2. Paste the SQL
# 3. Run all statements (this will take 2-3 minutes)
```

The script will:
- Create 3 databases (SALES_DB, ANALYTICS_DB, REFERENCE_DB)
- Create schemas in each database
- Create 10 tables with realistic structure
- Populate ~1.76M records total
- Grant necessary permissions

## Step 2: Verify Data

In Snowflake, run:
```sql
SELECT 'SALES_DB.RAW.customers' as table_name, COUNT(*) FROM SALES_DB.RAW.customers
UNION ALL
SELECT 'SALES_DB.RAW.orders', COUNT(*) FROM SALES_DB.RAW.orders
UNION ALL  
SELECT 'ANALYTICS_DB.RAW.web_events', COUNT(*) FROM ANALYTICS_DB.RAW.web_events;
```

Expected output:
- customers: 50,000
- orders: 150,000
- web_events: 1,000,000

## Step 3: Test with dbt-cost-guard

```bash
cd /Users/stan.dmitriev/Documents/dbt-cost
source venv/bin/activate

# Estimate all models
dbt-cost-guard --project-dir test_project estimate

# Analyze a specific expensive model
dbt-cost-guard --project-dir test_project analyze -m fct_orders_enriched

# Run with low threshold to see warnings
dbt-cost-guard --threshold 5.0 --project-dir test_project run --select stg_*
```

## What to Expect

### Low Cost Models (~$0.01 - $0.10)
- `stg_reference__geography` - Small lookup table
- `stg_sales__customers` - Simple view

### Medium Cost Models (~$0.50 - $5.00)
- `stg_sales__orders` - 150K rows
- `stg_sales__order_items` - 500K rows with JOIN
- `dim_customers` - Aggregations

### High Cost Models (~$5.00 - $20.00)
- `stg_analytics__web_events` - 1M rows!
- `fct_web_events_sessionized` - Window functions on 1M rows
- `fct_daily_web_metrics` - Time-series rolling aggregations

### Very High Cost Models (~$20.00+)
- `fct_orders_enriched` - Cross-database with 7+ CTEs
- `fct_customer_analytics_extreme` - Intentionally expensive!

## Test Scenarios

### Test 1: Cross-Database Estimation
```bash
dbt-cost-guard --project-dir test_project analyze -m fct_orders_enriched
```
Should show dependencies from SALES_DB, ANALYTICS_DB, and REFERENCE_DB

### Test 2: Large Dataset Handling
```bash
dbt-cost-guard --project-dir test_project analyze -m stg_analytics__web_events
```
Should correctly estimate 1M row scan

### Test 3: Incremental Models
```bash
# Full refresh (expensive)
dbt-cost-guard --project-dir test_project run --select fct_web_events_sessionized --full-refresh

# Incremental (cheap)
dbt-cost-guard --project-dir test_project run --select fct_web_events_sessionized
```

### Test 4: Cost Warnings
```bash
# This should trigger multiple warnings
dbt-cost-guard --threshold 1.0 --project-dir test_project run
```

### Test 5: Extreme Cost Detection
```bash
# This is the most expensive model
dbt-cost-guard --project-dir test_project analyze -m fct_customer_analytics_extreme
```
Should show:
- 100+ complexity score
- Multiple window functions
- Cross-database joins
- Recommendations to optimize

## Troubleshooting

**Error: "Database SALES_DB does not exist"**
→ Run `setup_enhanced_snowflake.sql` in Snowflake

**Error: "Permission denied"**
→ Ensure you're using SYSADMIN role

**All costs show $0.00**
→ Check if tables have data: `SELECT COUNT(*) FROM SALES_DB.RAW.customers`

**Models compile but don't run**
→ Check profiles.yml has correct Snowflake credentials

## Project Structure

```
test_project/
├── dbt_project.yml           # Project config
├── profiles.yml              # Snowflake connection
├── models/
│   ├── sources.yml           # Source definitions (3 databases)
│   ├── staging/              # 5 staging models
│   └── marts/
│       ├── facts/            # 4 fact tables
│       └── dimensions/       # 1 dimension table
└── README.md                 # Detailed documentation
```

## Success Criteria

✅ All 3 databases created with data
✅ dbt can compile all models
✅ Cost estimates show wide range ($0.01 to $50+)
✅ Cross-database models work correctly
✅ Warnings trigger for expensive models
✅ Analyze command shows detailed breakdown

---

**Once setup is complete, you'll have a production-grade test environment for dbt-cost-guard!**


# 🔥 INSANE COST TEST MODELS 🔥

These models are intentionally designed to be **EXTREMELY EXPENSIVE** for testing dbt-cost-guard's warning capabilities. 

**⚠️ DO NOT RUN THESE IN PRODUCTION! ⚠️**

## Models Overview

### 1. `fct_cartesian_nightmare.sql` 💣
**The Cartesian Product Disaster**

**What it does:**
- Creates a cartesian product: `customers × orders × products`
- 50,000 customers × 150,000 orders × 10,000 products = **75 TRILLION potential rows**
- Adds 9 window functions on top of the explosion
- Multiple aggregations with GROUP BY

**Why it's insane:**
- Uses `CROSS JOIN` with **NO JOIN CONDITIONS**
- Snowflake will try to create every possible combination
- Could run for hours and consume massive amounts of credits

**Complexity Score:** 100 (High)
**Estimated Time:** 16.7 seconds (likely MUCH longer in reality)
**Features:**
- ❌ 2 CROSS JOINs (no join conditions)
- 🔴 9 window functions
- 🔴 Aggregations on billions of rows
- 🔴 Multiple DISTINCT operations
- 🔴 String aggregation (LISTAGG)

---

### 2. `fct_self_join_explosion.sql` 💥
**The Recursive Self-Join Nightmare**

**What it does:**
- Performs **5 consecutive self-joins** on the 1M row `web_events` table
- Each self-join multiplies the dataset exponentially
- Adds 20+ window functions on the exploded dataset
- Multiple LAG/LEAD operations with various offsets

**Why it's insane:**
- First self-join: 1M × 1M potential rows
- Second self-join: Results × 1M more
- Third self-join: Results × 1M more
- Fourth self-join: Results × 1M more
- Fifth self-join: Results × 1M more
- **Potential: QUADRILLIONS of intermediate rows**

**Complexity Score:** 100 (High)
**Estimated Time:** 16.7 seconds (likely MUCH longer in reality)
**Features:**
- ❌ 5 self-joins on 1M row table
- 🔴 20+ window functions
- 🔴 Multiple LAG/LEAD with offsets 1, 2, 3
- 🔴 Rolling averages (50, 100 row windows)
- 🔴 Running totals and aggregations
- 🔴 STDDEV and statistical functions

---

### 3. `fct_cross_database_monster.sql` 🌪️
**The Cross-Database Aggregation Apocalypse**

**What it does:**
- Joins **ALL 3 databases** (SALES_DB, ANALYTICS_DB, REFERENCE_DB)
- Uses very loose join conditions (7-day window)
- Performs massive aggregations across all dimensions
- Adds 30+ window functions on the aggregated results
- Final self-join on the window results

**Why it's insane:**
- Loose time-based joins create massive fan-out
- Aggregates across multiple dimensions (customer, order, product, country, city)
- 30+ window functions with various partitions
- Multiple rolling windows (10, 30, 90, 180 rows)
- LAG/LEAD functions with offsets 1, 2, 3, 5
- Global ranking across entire dataset

**Complexity Score:** 100 (High)
**Estimated Time:** 16.7 seconds (likely MUCH longer in reality)
**Features:**
- ❌ Cross-database joins with loose conditions
- 🔴 30+ window functions
- 🔴 Multiple GROUP BY dimensions
- 🔴 Rolling windows (10, 30, 90, 180)
- 🔴 Global PERCENT_RANK and CUME_DIST
- 🔴 STDDEV and VAR_POP calculations
- 🔴 Final self-join on results
- 🔴 String aggregation (LISTAGG)

---

## Testing Cost Warnings

### Test 1: View Estimates
```bash
cd /Users/stan.dmitriev/Documents/dbt-cost
source venv/bin/activate
dbt-cost-guard --project-dir test_project estimate
```

**Expected Results:**
```
fct_cartesian_nightmare        $0.05      16.7s    High    ✓
fct_self_join_explosion        $0.05      16.7s    High    ✓
fct_cross_database_monster     $0.05      16.7s    High    ✓
```

---

### Test 2: Trigger Warnings (Low Threshold)
```bash
dbt-cost-guard --threshold 0.04 --project-dir test_project estimate
```

**Expected Results:**
All three insane models should show **⚠️** warnings!

---

### Test 3: Analyze Specific Model
```bash
dbt-cost-guard --project-dir test_project analyze -m fct_cartesian_nightmare
```

**Expected Output:**
- Complexity Score: 100 (High)
- Estimated Time: 16.7 seconds
- JOINs: 4+
- Window Functions: 9+
- Recommendations: Break into multiple models

---

### Test 4: Try to Run (Will Ask for Confirmation)
```bash
dbt-cost-guard --threshold 0.04 --project-dir test_project run --select fct_cartesian_nightmare
```

**Expected Behavior:**
```
⚠️  WARNING: Model 'fct_cartesian_nightmare' estimated to cost $0.05
This exceeds the threshold of $0.04

❌ Aborting due to cost threshold (use --skip-cost-check to override)
```

---

## Why These Models Are Educational

### 1. Cartesian Products
Real-world scenario: Accidentally forgetting join conditions in multi-table queries.

**Example:**
```sql
-- BAD: Forgot the join condition!
SELECT * FROM orders
CROSS JOIN products
```

**Cost Guard catches this!** The complexity score will be very high, and the estimated time will be astronomical.

---

### 2. Self-Joins
Real-world scenario: User behavior analysis, time-series comparisons, graph traversal.

**Example:**
```sql
-- Finding pairs of events from the same user
SELECT e1.*, e2.* 
FROM events e1
JOIN events e2 ON e1.user_id = e2.user_id
```

Without proper time/filter constraints, this creates N² rows!

---

### 3. Cross-Database Aggregations
Real-world scenario: Joining operational data with analytics data with loose time windows.

**Example:**
```sql
-- Joining sales with web events in a week window
SELECT * FROM sales
LEFT JOIN web_events 
  ON sales.customer_id = web_events.user_id
  AND web_events.timestamp >= sales.date - INTERVAL '7 days'
```

This can create massive fan-out if not carefully designed!

---

## Key Learnings

### What dbt-cost-guard Detects:
✅ High complexity scores (window functions, joins, aggregations)
✅ Execution time estimates based on data volume
✅ Cartesian products (CROSS JOINs)
✅ Self-joins with large datasets
✅ Cross-database operations
✅ Multiple window functions compounding costs

### What to Watch For:
- Complexity score > 80 = Very expensive
- Execution time > 10 seconds = Warning
- Multiple JOINs without filters = Danger
- Window functions on large datasets = Expensive
- Self-joins = Exponential growth potential

---

## Production Best Practices

Based on these test models, here's what to avoid in production:

### ❌ DON'T:
1. Use CROSS JOIN without understanding the implications
2. Self-join large tables without strict filters
3. Join tables with loose time windows (> 1 day)
4. Add 10+ window functions to a single query
5. Aggregate across many dimensions without materialization

### ✅ DO:
1. Always include join conditions
2. Use narrow time windows for time-based joins
3. Materialize intermediate results for complex pipelines
4. Partition large tables before joining
5. Use incremental models for large datasets
6. Run dbt-cost-guard BEFORE deploying to production
7. Set appropriate thresholds in CI/CD

---

## Warehouse Size Impact

These estimates are for **X-Small warehouse** (1 credit/hour = $3-4.50/hour).

### On Larger Warehouses:
- **MEDIUM (4 credits/hour):** $0.05 → **$0.20 per model**
- **LARGE (8 credits/hour):** $0.05 → **$0.40 per model**
- **X-LARGE (16 credits/hour):** $0.05 → **$0.80 per model**

Running all 3 insane models on an X-LARGE warehouse could cost **$2.40+** per run!

---

## Conclusion

These models demonstrate:
1. ✅ dbt-cost-guard successfully detects expensive queries
2. ✅ Complexity scoring accurately identifies dangerous patterns
3. ✅ Execution time estimates help predict costs
4. ✅ Warning system prevents accidental expensive runs
5. ✅ Analysis provides actionable optimization recommendations

**Use these models to test and tune your cost guard thresholds!** 🚀


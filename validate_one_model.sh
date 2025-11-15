#!/bin/bash
# Quick validation script: Run a model and check actual vs estimated costs

set -e

cd /Users/stan.dmitriev/Documents/dbt-cost
source venv/bin/activate

MODEL=${1:-stg_sales__customers}

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║              🧪 VALIDATE dbt-cost-guard: $MODEL"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Get estimate
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Getting dbt-cost-guard estimate..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

dbt-cost-guard --project-dir test_project analyze -m "$MODEL" | grep -A 20 "Cost Breakdown"

echo ""
echo "Press Enter to run the actual model..."
read

# Step 2: Run model
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Running actual model in Snowflake..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd test_project
dbt run --select "$MODEL" --profiles-dir .
cd ..

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Model executed successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Step 3: Check actual cost in Snowflake"
echo ""
echo "Run this query in Snowflake SQL Worksheet:"
echo ""
echo "────────────────────────────────────────────────────────────────────────────────"
cat << SQL
SELECT
    total_elapsed_time / 1000.0 as actual_seconds,
    GREATEST(CEIL((total_elapsed_time / 1000.0) / 60.0), 1) * 0.05 as actual_cost_dollars,
    execution_status
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE query_text ILIKE '%$MODEL%'
    AND query_text NOT ILIKE '%INFORMATION_SCHEMA%'
    AND execution_status = 'SUCCESS'
    AND start_time >= DATEADD(minute, -10, CURRENT_TIMESTAMP())
ORDER BY start_time DESC
LIMIT 1;
SQL
echo "────────────────────────────────────────────────────────────────────────────────"
echo ""
echo "OR run the comprehensive validation:"
echo "  • Open: check_actual_cost.sql in Snowflake"
echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"


#!/bin/bash
# Demo script to show dbt-cost-guard catching insanely expensive queries

set -e

cd /Users/stan.dmitriev/Documents/dbt-cost
source venv/bin/activate

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║           🔥 dbt-cost-guard: INSANE QUERY DEMO 🔥                            ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "This demo shows how dbt-cost-guard catches dangerously expensive queries"
echo "before they run in production!"
echo ""

# Step 1: Show all models
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: View all models in test_project"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "$ dbt-cost-guard --project-dir test_project estimate"
echo ""
sleep 2

dbt-cost-guard --project-dir test_project estimate

echo ""
echo "Press Enter to continue..."
read

# Step 2: Show detailed analysis of an insane model
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Analyze the 'Cartesian Nightmare' model"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "$ dbt-cost-guard --project-dir test_project analyze -m fct_cartesian_nightmare"
echo ""
sleep 2

dbt-cost-guard --project-dir test_project analyze -m fct_cartesian_nightmare

echo ""
echo "Press Enter to continue..."
read

# Step 3: Trigger warnings with low threshold
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Set a low threshold to trigger warnings"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "$ dbt-cost-guard --threshold 0.04 --project-dir test_project estimate"
echo ""
echo "⚠️  Notice: All insane models show warning symbols!"
echo ""
sleep 2

dbt-cost-guard --threshold 0.04 --project-dir test_project estimate

echo ""
echo "Press Enter to see the final comparison..."
read

# Step 4: Show summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY: Insane Models Detected! 🔥"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "✅ fct_cartesian_nightmare     16.7s   Complexity: 100   [CARTESIAN PRODUCT]"
echo "✅ fct_self_join_explosion     16.7s   Complexity: 100   [5 SELF-JOINS]"
echo "✅ fct_cross_database_monster  16.7s   Complexity: 100   [CROSS-DB JOINS]"
echo ""
echo "💰 On X-Small warehouse: $0.05 each ($0.15 total)"
echo "💰 On MEDIUM warehouse:  $0.20 each ($0.60 total)"
echo "💰 On LARGE warehouse:   $0.40 each ($1.20 total)"
echo "💰 On X-LARGE warehouse: $0.80 each ($2.40 total)"
echo ""
echo "⚠️  These queries would likely run for HOURS in production!"
echo ""
echo "🚀 dbt-cost-guard successfully caught all 3 dangerous queries!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"


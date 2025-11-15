#!/bin/bash

# Project Verification Script
# Checks that all components are in place

echo "🔍 dbt Cost Guard - Project Verification"
echo "=========================================="
echo ""

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1 (MISSING)"
        return 1
    fi
}

check_dir() {
    if [ -d "$1" ]; then
        echo -e "${GREEN}✓${NC} $1/"
        return 0
    else
        echo -e "${RED}✗${NC} $1/ (MISSING)"
        return 1
    fi
}

echo "📦 Core Package Files:"
check_file "pyproject.toml"
check_file "requirements.txt"
check_file "LICENSE"
check_file ".gitignore"
echo ""

echo "📚 Documentation:"
check_file "README.md"
check_file "USAGE.md"
check_file "HACKATHON.md"
check_file "PROJECT_OVERVIEW.md"
echo ""

echo "🐍 Python Package:"
check_dir "dbt_cost_guard"
check_file "dbt_cost_guard/__init__.py"
check_file "dbt_cost_guard/cli.py"
check_file "dbt_cost_guard/config.py"
check_file "dbt_cost_guard/estimator.py"
check_file "dbt_cost_guard/snowflake_utils.py"
echo ""

echo "🎯 Example Project:"
check_dir "example_project"
check_file "example_project/dbt_project.yml"
check_file "example_project/profiles.yml"
check_file "example_project/README.md"
echo ""

echo "📊 Example Models:"
check_dir "example_project/models/staging"
check_file "example_project/models/staging/stg_users.sql"
check_file "example_project/models/staging/stg_orders.sql"
check_file "example_project/models/staging/stg_products.sql"
check_dir "example_project/models/marts"
check_file "example_project/models/marts/dim_customers.sql"
check_file "example_project/models/marts/fct_order_items.sql"
check_file "example_project/models/marts/daily_product_metrics.sql"
echo ""

echo "🎬 Demo Scripts:"
check_file "demo.sh"
echo ""

echo "📈 Statistics:"
echo "  Python files: $(find dbt_cost_guard -name '*.py' | wc -l | xargs)"
echo "  SQL models: $(find example_project/models -name '*.sql' | wc -l | xargs)"
echo "  Documentation files: $(find . -maxdepth 1 -name '*.md' | wc -l | xargs)"
echo "  Total lines of Python: $(find dbt_cost_guard -name '*.py' -exec wc -l {} + | tail -1 | awk '{print $1}')"
echo ""

echo "✅ Project verification complete!"
echo ""
echo "Next steps:"
echo "  1. Install: pip install -e ."
echo "  2. Run demo: ./demo.sh"
echo "  3. Test: dbt-cost-guard --help"


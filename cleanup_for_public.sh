#!/bin/bash
# cleanup_for_public.sh - Remove unnecessary files for public release

set -e

echo "🧹 Cleaning up repository for public release..."
echo ""

# Files to DELETE (internal/hackathon-specific)
FILES_TO_DELETE=(
    "README_OLD.md"
    "HACKATHON.md"
    "PROJECT_OVERVIEW.md"
    "COMPLETE.md"
    "IMPLEMENTATION_SUMMARY.md"
    "QUICK_SUMMARY.md"
    "QUICK_REFERENCE.md"
    "SUCCESS_SUMMARY.md"
    "HOW_TO_USE.md"
    "demo.sh"
    "demo_insane_models.sh"
    "setup_demo.sh"
    "verify.sh"
    "validate_one_model.sh"
    "check_complex_model_cost.sql"
    "check_table_stats.sql"
    "test_expensive_query.sql"
    "ultra_expensive_queries.sql"
    "prepare_for_github.sh"
)

echo "📁 Removing internal/demo files..."
for file in "${FILES_TO_DELETE[@]}"; do
    if [ -f "$file" ]; then
        rm "$file"
        echo "  ✓ Removed: $file"
    fi
done
echo ""

# Move some files to docs/ directory for better organization
echo "📂 Organizing documentation..."
mkdir -p docs

# Keep these but move to docs/
if [ -f "ENHANCED_TEST_SETUP.md" ]; then
    mv ENHANCED_TEST_SETUP.md docs/
    echo "  ✓ Moved: ENHANCED_TEST_SETUP.md → docs/"
fi

if [ -f "LARGE_DATA_GUIDE.md" ]; then
    mv LARGE_DATA_GUIDE.md docs/
    echo "  ✓ Moved: LARGE_DATA_GUIDE.md → docs/"
fi

if [ -f "RUN_AND_VALIDATE.md" ]; then
    mv RUN_AND_VALIDATE.md docs/
    echo "  ✓ Moved: RUN_AND_VALIDATE.md → docs/"
fi

if [ -f "REAL_WORLD_USAGE.md" ]; then
    mv REAL_WORLD_USAGE.md docs/
    echo "  ✓ Moved: REAL_WORLD_USAGE.md → docs/"
fi

if [ -f "IMPROVEMENTS.md" ]; then
    mv IMPROVEMENTS.md docs/ROADMAP.md
    echo "  ✓ Moved: IMPROVEMENTS.md → docs/ROADMAP.md"
fi

if [ -f "ARCHITECTURE.md" ]; then
    mv ARCHITECTURE.md docs/
    echo "  ✓ Moved: ARCHITECTURE.md → docs/"
fi

echo ""

# Move SQL setup files to examples/
echo "📂 Organizing SQL files..."
mkdir -p examples/snowflake_setup

if [ -f "setup_snowflake.sql" ]; then
    mv setup_snowflake.sql examples/snowflake_setup/
    echo "  ✓ Moved: setup_snowflake.sql → examples/snowflake_setup/"
fi

if [ -f "setup_enhanced_snowflake.sql" ]; then
    mv setup_enhanced_snowflake.sql examples/snowflake_setup/
    echo "  ✓ Moved: setup_enhanced_snowflake.sql → examples/snowflake_setup/"
fi

if [ -f "scale_up_data.sql" ]; then
    mv scale_up_data.sql examples/snowflake_setup/
    echo "  ✓ Moved: scale_up_data.sql → examples/snowflake_setup/"
fi

if [ -f "create_large_datasets.sql" ]; then
    mv create_large_datasets.sql examples/snowflake_setup/
    echo "  ✓ Moved: create_large_datasets.sql → examples/snowflake_setup/"
fi

# Keep useful validation scripts
if [ -f "check_actual_cost.sql" ]; then
    mv check_actual_cost.sql examples/
    echo "  ✓ Moved: check_actual_cost.sql → examples/"
fi

if [ -f "validate_costs.sql" ]; then
    mv validate_costs.sql examples/
    echo "  ✓ Moved: validate_costs.sql → examples/"
fi

echo ""

# Simplify helper scripts
if [ -f "setup_venv.sh" ]; then
    mv setup_venv.sh examples/
    echo "  ✓ Moved: setup_venv.sh → examples/"
fi

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📊 Current structure:"
echo ""
echo "Root level (clean):"
echo "  README.md           - Main documentation"
echo "  CONTRIBUTING.md     - For contributors"
echo "  INSTALLATION.md     - Setup guide"
echo "  SETUP.md            - Quick start"
echo "  USAGE.md            - Command reference"
echo "  LICENSE             - MIT license"
echo "  pyproject.toml      - Package config"
echo ""
echo "docs/ (detailed docs):"
echo "  ARCHITECTURE.md"
echo "  ROADMAP.md"
echo "  REAL_WORLD_USAGE.md"
echo "  RUN_AND_VALIDATE.md"
echo "  ENHANCED_TEST_SETUP.md"
echo "  LARGE_DATA_GUIDE.md"
echo ""
echo "examples/ (helpful examples):"
echo "  check_actual_cost.sql"
echo "  validate_costs.sql"
echo "  setup_venv.sh"
echo "  snowflake_setup/*.sql"
echo ""


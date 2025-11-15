#!/bin/bash

# Quick demo script for dbt-cost-guard

echo "🚀 dbt Cost Guard Demo"
echo "====================="
echo ""

# Check if in correct directory
if [ ! -f "pyproject.toml" ]; then
    echo "❌ Please run this script from the dbt-cost directory"
    exit 1
fi

# Install package
echo "📦 Installing dbt-cost-guard..."
pip install -e . > /dev/null 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Installation failed"
    exit 1
fi

echo "✓ Installed successfully"
echo ""

# Check if example project has Snowflake credentials
echo "📝 Checking example project configuration..."
if grep -q "YOUR_ACCOUNT" example_project/profiles.yml; then
    echo ""
    echo "⚠️  Warning: Example project needs Snowflake credentials"
    echo ""
    echo "To use the example project:"
    echo "1. Edit example_project/profiles.yml"
    echo "2. Add your Snowflake credentials"
    echo "3. Run: dbt-cost-guard run --project-dir example_project"
    echo ""
fi

# Show help
echo "📖 Available commands:"
echo ""
dbt-cost-guard --help
echo ""

# Show config command
echo "📊 Checking configuration:"
echo ""
dbt-cost-guard config --project-dir example_project
echo ""

echo "✅ Demo complete!"
echo ""
echo "Next steps:"
echo "  1. Configure your Snowflake credentials in example_project/profiles.yml"
echo "  2. Run: dbt-cost-guard estimate --project-dir example_project"
echo "  3. Run: dbt-cost-guard run --project-dir example_project"
echo ""


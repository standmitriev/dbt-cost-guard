#!/bin/bash

# Setup script with virtual environment
# This creates a clean Python environment and installs dbt-cost-guard

echo "🐍 Setting up Python virtual environment..."
echo ""

# Navigate to project directory
cd /Users/stan.dmitriev/Documents/dbt-cost

# Create virtual environment
echo "Creating virtual environment..."
python3 -m venv venv

if [ $? -ne 0 ]; then
    echo "❌ Failed to create virtual environment"
    echo "Make sure Python 3 is installed: python3 --version"
    exit 1
fi

echo "✓ Virtual environment created"
echo ""

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate

echo "✓ Virtual environment activated"
echo ""

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip --quiet

echo "✓ pip upgraded"
echo ""

# Install dbt-cost-guard
echo "Installing dbt-cost-guard and dependencies..."
echo "(This may take 2-3 minutes for dbt packages...)"
pip install -e .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Installation complete!"
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          Virtual Environment is Ready!                   ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""
    echo "To use dbt-cost-guard in the future:"
    echo ""
    echo "1. Activate the virtual environment:"
    echo "   cd /Users/stan.dmitriev/Documents/dbt-cost"
    echo "   source venv/bin/activate"
    echo ""
    echo "2. Then run your commands:"
    echo "   dbt-cost-guard --help"
    echo "   dbt-cost-guard estimate --project-dir example_project"
    echo ""
    echo "3. To deactivate when done:"
    echo "   deactivate"
    echo ""
    echo "🚀 You're currently IN the virtual environment now!"
    echo "   Try: dbt-cost-guard --help"
    echo ""
else
    echo "❌ Installation failed"
    exit 1
fi


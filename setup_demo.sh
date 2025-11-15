#!/bin/bash

# Complete Setup and Demo Script for dbt Cost Guard
# This script will install and demo the project with your Snowflake instance

set -e  # Exit on error

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     dbt Cost Guard - Complete Setup & Demo Script           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Install dbt-cost-guard
echo -e "${BLUE}Step 1: Installing dbt-cost-guard...${NC}"
cd /Users/stan.dmitriev/Documents/dbt-cost
pip install -e . --quiet

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ dbt-cost-guard installed successfully${NC}"
else
    echo -e "${RED}✗ Installation failed${NC}"
    exit 1
fi
echo ""

# Step 2: Verify installation
echo -e "${BLUE}Step 2: Verifying installation...${NC}"
if command -v dbt-cost-guard &> /dev/null; then
    echo -e "${GREEN}✓ dbt-cost-guard command is available${NC}"
else
    echo -e "${RED}✗ dbt-cost-guard command not found${NC}"
    exit 1
fi
echo ""

# Step 3: Show Snowflake setup instructions
echo -e "${BLUE}Step 3: Setting up Snowflake test data...${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: Run this SQL in your Snowflake worksheet:${NC}"
echo -e "${YELLOW}File: /Users/stan.dmitriev/Documents/dbt-cost/setup_snowflake.sql${NC}"
echo ""
echo "This will create:"
echo "  • DEMO_DB database"
echo "  • RAW schema with sample tables"
echo "  • 10,000 users"
echo "  • 50,000 orders"
echo "  • 1,000 products"
echo "  • 100,000 order items"
echo ""
read -p "Press Enter once you've run the SQL setup in Snowflake..."
echo ""

# Step 4: Test dbt connection
echo -e "${BLUE}Step 4: Testing dbt connection...${NC}"
cd /Users/stan.dmitriev/Documents/dbt-cost/example_project
dbt debug --profiles-dir .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ dbt connection successful${NC}"
else
    echo -e "${RED}✗ dbt connection failed - check your credentials${NC}"
    exit 1
fi
echo ""

# Step 5: Show current configuration
echo -e "${BLUE}Step 5: Current configuration:${NC}"
cd /Users/stan.dmitriev/Documents/dbt-cost
dbt-cost-guard config --project-dir example_project
echo ""

# Step 6: Demo - Estimate costs
echo -e "${BLUE}Step 6: DEMO - Estimating costs (dry run)...${NC}"
echo ""
dbt-cost-guard estimate --project-dir example_project
echo ""

# Step 7: Demo - Run with cost checks
echo -e "${BLUE}Step 7: DEMO - Running dbt with cost checks...${NC}"
echo ""
echo -e "${YELLOW}This will show cost warnings and require confirmation${NC}"
echo ""
dbt-cost-guard run --project-dir example_project
echo ""

# Step 8: Show what was created
echo -e "${BLUE}Step 8: Verifying created models...${NC}"
cd example_project
dbt ls --profiles-dir . --resource-type model
echo ""

# Success!
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    ✅ DEMO COMPLETE! ✅                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "🎉 Your dbt Cost Guard is fully set up and working!"
echo ""
echo "Next steps for demos:"
echo ""
echo "1. Run specific models:"
echo "   dbt-cost-guard run --project-dir example_project --models staging"
echo ""
echo "2. Run expensive models (will trigger warnings):"
echo "   dbt-cost-guard run --project-dir example_project --models fct_order_items"
echo ""
echo "3. Force run (skip cost checks):"
echo "   dbt-cost-guard run --project-dir example_project --force"
echo ""
echo "4. Just estimate without running:"
echo "   dbt-cost-guard estimate --project-dir example_project"
echo ""
echo "5. Adjust thresholds:"
echo "   dbt-cost-guard run --threshold 1.0 --project-dir example_project"
echo ""


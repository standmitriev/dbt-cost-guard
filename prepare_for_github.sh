#!/bin/bash
# prepare_for_github.sh - Script to prepare dbt-cost-guard for public GitHub

set -e

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║              Preparing dbt-cost-guard for Public GitHub                     ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Remove sensitive files from git if they were added
echo "🔒 Step 1: Removing sensitive files..."
git rm --cached example_project/profiles.yml 2>/dev/null || true
git rm --cached test_project/profiles.yml 2>/dev/null || true
git rm --cached *.log 2>/dev/null || true
git rm --cached **/*.log 2>/dev/null || true
echo "✅ Sensitive files removed from git tracking"
echo ""

# Step 2: Verify .gitignore is working
echo "🔍 Step 2: Verifying .gitignore..."
if git check-ignore -q example_project/profiles.yml && git check-ignore -q test_project/profiles.yml; then
    echo "✅ profiles.yml files are properly ignored"
else
    echo "⚠️  Warning: Some profiles.yml files may not be ignored"
fi
echo ""

# Step 3: Check for any remaining credentials
echo "🔎 Step 3: Scanning for actual credentials..."
# Check for specific credential patterns that shouldn't be in docs
if git ls-files | grep -v "prepare_for_github.sh" | grep -v "\.example$" | xargs grep -E "(YCBRNQN|BROSTAS|JA64609)" 2>/dev/null; then
    echo "❌ ERROR: Found actual Snowflake credentials in tracked files!"
    echo "   Please remove them before pushing"
    exit 1
else
    echo "✅ No actual credentials found in tracked files"
fi
echo ""

# Step 4: Show files that will be committed
echo "📁 Step 4: Files to be included in repository:"
echo ""
git status --porcelain 2>/dev/null || echo "   (Git not initialized yet)"
echo ""

# Step 5: Summary
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                            ✅ READY FOR GITHUB                               ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo "  1. Review the files above"
echo "  2. git add ."
echo "  3. git commit -m 'Initial commit: dbt-cost-guard'"
echo "  4. git remote add origin https://github.com/standmitriev/dbt-cost-guard.git"
echo "  5. git branch -M main"
echo "  6. git push -u origin main"
echo ""
echo "⚠️  IMPORTANT: Double-check that no credentials are in the files!"
echo ""


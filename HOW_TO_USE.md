# How to Use dbt-cost-guard

## ✅ Installation Complete!

The virtual environment is set up with Python 3.11 and all dependencies installed.

## Every Time You Want to Use It

In your terminal, run these commands:

```bash
cd /Users/stan.dmitriev/Documents/dbt-cost
source venv/bin/activate
```

You'll see `(venv)` appear in your terminal prompt. Now you can use dbt-cost-guard!

## Quick Commands

```bash
# Help
dbt-cost-guard --help

# Estimate costs (dry run)
dbt-cost-guard estimate --project-dir example_project

# Run with cost checks
dbt-cost-guard run --project-dir example_project

# Configuration
dbt-cost-guard config --project-dir example_project
```

## When You're Done

```bash
deactivate  # Exits the virtual environment
```

## ⚠️ Important: Run Snowflake Setup First!

Before running dbt-cost-guard, you need to create the test data:

1. Open Snowflake web UI
2. Run the SQL file: `/Users/stan.dmitriev/Documents/dbt-cost/setup_snowflake.sql`

This creates:
- DEMO_DB database
- RAW schema with sample tables
- 160,000+ rows of test data

## 🚀 Ready to Demo!

```bash
# 1. Activate venv
cd /Users/stan.dmitriev/Documents/dbt-cost
source venv/bin/activate

# 2. Run setup SQL in Snowflake (one time only)
# (Copy and paste setup_snowflake.sql into Snowflake)

# 3. Test the connection
cd example_project
dbt debug --profiles-dir .

# 4. Run the demo!
cd ..
dbt-cost-guard estimate --project-dir example_project
dbt-cost-guard run --project-dir example_project
```

That's it! 🎊


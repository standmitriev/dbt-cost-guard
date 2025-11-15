# Installation and Usage Guide

## Quick Start

### 1. Install dbt-cost-guard

```bash
cd /Users/stan.dmitriev/Documents/dbt-cost
pip install -e .
```

This will install:
- dbt-cost-guard CLI tool
- All required dependencies (dbt-core, dbt-snowflake, click, rich, etc.)

### 2. Verify Installation

```bash
dbt-cost-guard --help
```

You should see the help menu with available commands.

### 3. Try the Example Project

```bash
cd example_project

# Update profiles.yml with your Snowflake credentials
nano profiles.yml

# Estimate costs without running
dbt-cost-guard estimate

# Run with cost checks
dbt-cost-guard run
```

## Using with Your Own dbt Project

### Step 1: Add Configuration

Add to your `dbt_project.yml`:

```yaml
vars:
  cost_guard:
    enabled: true
    cost_per_credit: 3.0  # Adjust for your Snowflake pricing
    warning_threshold_per_model: 5.0
    warning_threshold_total_run: 5.0
```

### Step 2: Replace dbt run

Instead of:
```bash
dbt run
```

Use:
```bash
dbt-cost-guard run
```

All dbt flags are supported:
```bash
dbt-cost-guard run --models my_model+
dbt-cost-guard run --select tag:daily --exclude tag:expensive
dbt-cost-guard run --full-refresh
```

## Commands

### run
Run dbt with cost estimation and confirmation:
```bash
dbt-cost-guard run [dbt options]
```

Options:
- `--force`, `-f`: Skip cost checks
- `--cost-per-credit FLOAT`: Override cost per credit
- `--threshold FLOAT`: Override warning threshold
- All standard dbt run options

### estimate
Estimate costs without running:
```bash
dbt-cost-guard estimate [options]
```

Useful for:
- CI/CD cost checks
- Planning expensive runs
- Identifying costly models

### config
Show current configuration:
```bash
dbt-cost-guard config
```

## Common Workflows

### Development
```bash
# Check costs before running
dbt-cost-guard estimate --models my_new_model

# Run with cost awareness
dbt-cost-guard run --models my_new_model
```

### Production
```bash
# Run all models with cost protection
dbt-cost-guard run --threads 8

# Force run if you've already reviewed costs
dbt-cost-guard run --force
```

### CI/CD
```bash
# Fail if costs exceed threshold
if ! dbt-cost-guard estimate --threshold 20.0; then
    echo "❌ Cost exceeds budget!"
    exit 1
fi
```

## Configuration Options

### Per-Project (dbt_project.yml)
```yaml
vars:
  cost_guard:
    enabled: true
    cost_per_credit: 3.0
    warning_threshold_per_model: 5.0
    warning_threshold_total_run: 5.0
```

### Per-Model (in SQL file)
```sql
{{ config(
    meta={
        'cost_guard_skip': true  -- Skip cost check for this model
    }
) }}

SELECT ...
```

### CLI Overrides
```bash
# Override cost per credit
dbt-cost-guard run --cost-per-credit 2.5

# Override threshold
dbt-cost-guard run --threshold 10.0

# Skip all checks
dbt-cost-guard run --skip-cost-check
```

## Troubleshooting

### "Error initializing cost estimator"
- Check your Snowflake credentials in profiles.yml
- Ensure your warehouse is accessible
- Verify network connectivity

### "Could not query history"
- You may not have access to SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
- Cost estimation will fall back to heuristics
- Ask your admin for ACCOUNTADMIN or USAGE_VIEWER role

### Inaccurate cost estimates
- Cost estimation is heuristic-based and may not be 100% accurate
- Adjust based on your actual usage patterns
- Consider historical query data for better estimates

## Getting Help

```bash
# General help
dbt-cost-guard --help

# Command-specific help
dbt-cost-guard run --help
dbt-cost-guard estimate --help
```

## Next Steps

1. Try the example project
2. Add cost_guard config to your project
3. Run `dbt-cost-guard estimate` to see your current costs
4. Adjust thresholds based on your budget
5. Replace `dbt run` with `dbt-cost-guard run` in your workflows


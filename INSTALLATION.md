# Installation Guide

## Prerequisites

- Python 3.8 or higher
- dbt-core >= 1.5.0
- dbt-snowflake >= 1.5.0
- Access to a Snowflake account

## Installation Methods

### Method 1: Install from PyPI (Recommended)

Once published to PyPI:

```bash
pip install dbt-cost-guard
```

### Method 2: Install from GitHub

```bash
pip install git+https://github.com/yourusername/dbt-cost-guard.git
```

### Method 3: Install from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/dbt-cost-guard.git
cd dbt-cost-guard

# Install in development mode
pip install -e .
```

### Method 4: Using Virtual Environment (Recommended for development)

```bash
# Create virtual environment
python3 -m venv venv

# Activate it
source venv/bin/activate  # On Unix/Mac
# or
venv\Scripts\activate  # On Windows

# Install dbt-cost-guard
pip install dbt-cost-guard
```

## Verification

Verify the installation:

```bash
dbt-cost-guard --help
```

You should see the help output with available commands.

## Configuration

### Quick Setup

1. Navigate to your dbt project directory:
```bash
cd /path/to/your/dbt/project
```

2. Create a `.dbt-cost-guard.yml` configuration file (optional):
```bash
cp /path/to/dbt-cost-guard/.dbt-cost-guard.yml.example .dbt-cost-guard.yml
```

3. Edit the configuration to match your needs:
```yaml
version: 1
cost_per_credit: 3.0  # Your Snowflake cost per credit
thresholds:
  per_model_warning: 5.00
  total_run_warning: 10.00
```

### Configuration Options

#### Option 1: Using .dbt-cost-guard.yml (Recommended)

Create a `.dbt-cost-guard.yml` file in your dbt project root with full configuration options. See [.dbt-cost-guard.yml.example](./.dbt-cost-guard.yml.example) for a complete example.

#### Option 2: Using dbt_project.yml

Add to your `dbt_project.yml`:

```yaml
vars:
  cost_guard:
    enabled: true
    cost_per_credit: 3.0
    warning_threshold_per_model: 5.0
    warning_threshold_total_run: 10.0
```

#### Option 3: Using CLI Flags

Override settings at runtime:

```bash
dbt-cost-guard --cost-per-credit 3.0 --threshold 5.0 run
```

### Priority Order

Configuration is loaded in this priority (highest to lowest):
1. CLI flags (`--cost-per-credit`, `--threshold`)
2. `.dbt-cost-guard.yml` in project root
3. `dbt_project.yml` vars
4. Default values

## Snowflake Permissions

dbt-cost-guard requires these Snowflake permissions to function optimally:

### Required Permissions
- `SELECT` on `INFORMATION_SCHEMA.TABLES` (for table statistics)
- `USAGE` on warehouses

### Optional Permissions (for enhanced accuracy)
- `SELECT` on `SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY` (for historical learning)
- Ability to run `EXPLAIN` queries (for EXPLAIN plan integration)

### Setting Up Permissions

```sql
-- Grant access to INFORMATION_SCHEMA
GRANT USAGE ON DATABASE your_database TO ROLE your_role;
GRANT USAGE ON SCHEMA INFORMATION_SCHEMA TO ROLE your_role;

-- Grant access to ACCOUNT_USAGE (optional, for better estimates)
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE your_role;

-- Grant warehouse usage
GRANT USAGE ON WAREHOUSE your_warehouse TO ROLE your_role;
```

## First Run

Test your installation:

```bash
# Estimate costs for all models
dbt-cost-guard --project-dir . estimate

# Run with cost checking
dbt-cost-guard --project-dir . run
```

## Troubleshooting

### Issue: "Command not found: dbt-cost-guard"

**Solution:**
- Ensure you've activated your virtual environment
- Verify installation: `pip list | grep dbt-cost-guard`
- Try reinstalling: `pip install --force-reinstall dbt-cost-guard`

### Issue: "Could not find profiles.yml"

**Solution:**
- Ensure your `profiles.yml` is in `~/.dbt/` or specify with `--profiles-dir`
- Verify dbt setup: `dbt debug`

### Issue: "Connection to Snowflake failed"

**Solution:**
- Test dbt connection: `dbt debug`
- Verify credentials in `profiles.yml`
- Check network access to Snowflake

### Issue: "Warning: Could not access QUERY_HISTORY"

**Solution:**
- This is optional - cost estimation will still work using heuristics
- To enable historical learning, grant permissions (see above)
- Run with `--verbose` to see detailed logs

### Issue: All costs show as $0.00

**Possible causes:**
1. Tables are empty - check with `SELECT COUNT(*) FROM your_table`
2. Compiled SQL not found - ensure dbt project compiles correctly
3. Snowflake permissions issue - verify table access

**Solution:**
```bash
# Run with verbose logging to see what's happening
dbt-cost-guard --verbose --project-dir . estimate

# Verify dbt can compile
dbt compile
```

## Next Steps

- Read the [Usage Guide](./REAL_WORLD_USAGE.md) for integration examples
- Check [Configuration Reference](./.dbt-cost-guard.yml.example) for all options
- See [Contributing Guide](./CONTRIBUTING.md) to contribute

## Getting Help

- Check the [README](./README.md) for common questions
- Open an issue on [GitHub](https://github.com/yourusername/dbt-cost-guard/issues)
- Read the [Improvements Guide](./IMPROVEMENTS.md) to understand accuracy limitations


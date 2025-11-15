# Setup Guide for dbt-cost-guard

## Prerequisites

- Python 3.8 or higher
- dbt-core installed
- dbt-snowflake adapter
- Access to a Snowflake account

## Installation

### Option 1: Install from PyPI (Recommended)

```bash
pip install dbt-cost-guard
```

### Option 2: Install from GitHub

```bash
pip install git+https://github.com/standmitriev/dbt-cost-guard.git
```

### Option 3: Install from Source

```bash
git clone https://github.com/standmitriev/dbt-cost-guard.git
cd dbt-cost-guard
pip install -e .
```

## Configuration

### 1. Set Up Snowflake Connection

dbt-cost-guard uses your existing dbt profiles. If you don't have one:

#### Create `profiles.yml` in your project directory:

```yaml
your_project_name:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: YOUR_ACCOUNT  # e.g., xy12345.us-east-1
      user: YOUR_USERNAME
      password: YOUR_PASSWORD
      role: YOUR_ROLE
      database: YOUR_DATABASE
      warehouse: YOUR_WAREHOUSE
      schema: YOUR_SCHEMA
      threads: 4
      client_session_keep_alive: False
```

**⚠️ Security Note**: Never commit `profiles.yml` to version control! It contains credentials.

#### Alternative: Use Environment Variables

```yaml
your_project_name:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"
      role: "{{ env_var('SNOWFLAKE_ROLE') }}"
      database: "{{ env_var('SNOWFLAKE_DATABASE') }}"
      warehouse: "{{ env_var('SNOWFLAKE_WAREHOUSE') }}"
      schema: "{{ env_var('SNOWFLAKE_SCHEMA') }}"
      threads: 4
```

Then set environment variables:
```bash
export SNOWFLAKE_ACCOUNT=your_account
export SNOWFLAKE_USER=your_username
export SNOWFLAKE_PASSWORD=your_password
# ... etc
```

### 2. (Optional) Configure dbt-cost-guard

Create `.dbt-cost-guard.yml` in your project root:

```yaml
version: 1

# Snowflake pricing (default: $3/credit)
cost_per_credit: 3.00

# Override warehouse size for simulations
# warehouse_credits_per_hour: 8  # Uncomment to simulate LARGE warehouse

# Warning thresholds
thresholds:
  per_model_dollars: 5.00      # Warn if any model costs > $5
  total_run_dollars: 20.00     # Warn if total run costs > $20
  per_model_seconds: 300       # Warn if any model takes > 5 minutes
  total_run_seconds: 1800      # Warn if total run takes > 30 minutes

# Model-specific overrides
model_overrides:
  # Allow specific expensive models
  "fct_large_aggregation":
    per_model_dollars: 10.00
    skip: false

  # Skip test models
  "test_*":
    skip: true

# Skip patterns (glob-style)
skip_models:
  - "test_*"
  - "*_temp"
  - "experimental.*"

# Estimation settings
estimation:
  use_explain_plans: true      # Use Snowflake EXPLAIN plans (recommended)
  use_historical_data: true    # Learn from query history (recommended)
  cache_detection: true        # Check for cache hits
  history_days: 30             # Days of history to consider
  apply_billing_rules: true    # Apply 1-minute minimum billing
```

## Verify Installation

```bash
# Check version
dbt-cost-guard --version

# Show help
dbt-cost-guard --help

# Test with your project
dbt-cost-guard --project-dir /path/to/your/project config
```

## First Run

### 1. Estimate Costs

```bash
dbt-cost-guard --project-dir /path/to/your/project estimate
```

This will:
- Compile your dbt models
- Connect to Snowflake
- Analyze query complexity
- Show cost estimates

### 2. Analyze Specific Model

```bash
dbt-cost-guard --project-dir /path/to/your/project analyze -m my_model
```

### 3. Run with Cost Checking

```bash
dbt-cost-guard --project-dir /path/to/your/project run
```

This will:
- Estimate costs first
- Show warnings if costs are high
- Ask for confirmation before proceeding

## Troubleshooting

### Issue: "Command not found: dbt-cost-guard"

**Solution**: Make sure you're in the correct virtual environment:

```bash
# Activate your virtual environment
source venv/bin/activate  # Linux/Mac
# or
venv\Scripts\activate  # Windows

# Reinstall
pip install dbt-cost-guard
```

### Issue: "Could not initialize Snowflake connection"

**Solution**: Check your profiles.yml:

```bash
# Test dbt connection first
cd your_project
dbt debug

# If dbt works, dbt-cost-guard should work too
```

### Issue: "No models found"

**Solution**: Make sure you're in the correct directory:

```bash
# Use --project-dir to specify location
dbt-cost-guard --project-dir /full/path/to/project estimate
```

### Issue: Costs are all $0.00

**Possible causes**:
1. Tables are empty (run `dbt run` first to populate)
2. New queries have no history
3. Very small data volumes

**Solution**: Run `dbt run --full-refresh` to rebuild models with data.

### Issue: Permission errors accessing QUERY_HISTORY

**Solution**: Your Snowflake role needs access to `SNOWFLAKE.ACCOUNT_USAGE` views:

```sql
-- Grant in Snowflake (requires ACCOUNTADMIN)
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE YOUR_ROLE;
```

## Example Projects

Try the included example projects:

```bash
# Clone repository
git clone https://github.com/standmitriev/dbt-cost-guard.git
cd dbt-cost-guard

# Set up example_project
cd example_project
cp profiles.yml.example profiles.yml
# Edit profiles.yml with your credentials

# Run estimation
cd ..
dbt-cost-guard --project-dir example_project estimate
```

## Next Steps

- Read [USAGE.md](USAGE.md) for detailed command documentation
- Check [REAL_WORLD_USAGE.md](REAL_WORLD_USAGE.md) for CI/CD integration
- See [IMPROVEMENTS.md](IMPROVEMENTS.md) for advanced features

## Getting Help

- Check [GitHub Issues](https://github.com/standmitriev/dbt-cost-guard/issues)
- Read the [Documentation](README.md)
- Ask in [GitHub Discussions](https://github.com/standmitriev/dbt-cost-guard/discussions)


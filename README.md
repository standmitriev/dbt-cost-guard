# dbt-cost-guard 💰

**Prevent costly Snowflake mistakes before they happen!**

`dbt-cost-guard` estimates the cost of your dbt models **before** running them, helping data teams avoid expensive warehouse bills and optimize their Snowflake spending.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)

## 🎯 Why dbt-cost-guard?

Data teams running dbt on Snowflake face a common problem: **unexpected costs**. A single expensive query or running models on the wrong warehouse can cost thousands of dollars.

**dbt-cost-guard helps you:**
- 💰 **Estimate costs before running** - Know what you'll spend before executing
- 📊 **Project long-term costs** - See annual costs based on run frequency
- ⚠️ **Get warnings** - Automatic alerts for expensive operations
- 🎯 **Optimize warehouse selection** - Find cost savings opportunities
- 📈 **Track spending trends** - Understand where your money goes

### Real-World Example

```bash
$ dbt-cost-guard --project-dir my_project estimate

✓ Found 15 models
Total Cost: $48.00 per run

💰 Long-Term Cost Projections:
  Daily (1×):    $17,520/year
  Twice Daily:   $35,040/year
  Hourly (24×):  $420,480/year  ⚠️

💵 Cost Optimization Opportunity:
  Potential Annual Savings: $15,330
  Switch from 3X-Large to X-Small warehouse
```

**That's $15,000+ in annual savings!**

## 🚀 Quick Start

### Installation

```bash
pip install dbt-cost-guard
```

Or install from source:

```bash
git clone https://github.com/standmitriev/dbt-cost-guard.git
cd dbt-cost-guard
pip install -e .
```

### Basic Usage

```bash
# Estimate costs without running
dbt-cost-guard --project-dir my_project estimate

# Run dbt with cost checking
dbt-cost-guard --project-dir my_project run

# Analyze a specific model
dbt-cost-guard --project-dir my_project analyze -m my_model

# Show configuration
dbt-cost-guard --project-dir my_project config
```

## 📊 Features

### 🎯 Multi-Layered Accuracy

dbt-cost-guard uses multiple estimation methods for maximum accuracy:

1. **EXPLAIN Plans** - Analyzes Snowflake's query execution plans
2. **Historical Data** - Learns from past query performance
3. **Heuristics** - Intelligent complexity scoring (JOINs, window functions, etc.)
4. **Cache Detection** - Identifies potential cache hits
5. **Billing Rules** - Applies Snowflake's actual billing (1-minute minimum, per-minute charges)

### 💰 Long-Term Cost Projections

See how costs add up over time with different run frequencies:
- Daily, weekly, monthly projections
- Annual cost calculations
- Savings recommendations

### ⚠️ Warning System

Get automatic warnings for:
- Expensive individual models
- High total run costs
- Long-running queries
- Complex operations that might be optimized

### 🎛️ Flexible Configuration

Configure thresholds, warehouse settings, and model-specific overrides:

```yaml
# .dbt-cost-guard.yml
version: 1

cost_per_credit: 3.00
warehouse_credits_per_hour: 8  # For warehouse simulation

thresholds:
  per_model_dollars: 5.00
  total_run_dollars: 20.00

model_overrides:
  "fct_expensive_model":
    per_model_dollars: 50.00  # Allow this to be expensive

skip_models:
  - "test_*"
  - "*_temp"

estimation:
  use_explain_plans: true
  use_historical_data: true
  cache_detection: true
  history_days: 30
```

## 📖 Documentation

- [Installation Guide](INSTALLATION.md)
- [Usage Guide](USAGE.md)
- [Configuration](README.md#-flexible-configuration)
- [Architecture](ARCHITECTURE.md)
- [Contributing](CONTRIBUTING.md)
- [Improvements & Roadmap](IMPROVEMENTS.md)
- [Real-World Usage](REAL_WORLD_USAGE.md)

## 🛠️ Setup

### 1. Configure Snowflake Connection

Create a `profiles.yml` in your dbt project (or use existing dbt profiles):

```yaml
my_project:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: YOUR_ACCOUNT
      user: YOUR_USERNAME
      password: YOUR_PASSWORD
      role: YOUR_ROLE
      database: YOUR_DATABASE
      warehouse: YOUR_WAREHOUSE
      schema: YOUR_SCHEMA
      threads: 4
```

### 2. (Optional) Create Configuration File

Create `.dbt-cost-guard.yml` in your project root:

```yaml
version: 1

cost_per_credit: 3.00

thresholds:
  per_model_dollars: 5.00
  total_run_dollars: 20.00

estimation:
  use_explain_plans: true
  use_historical_data: true
  cache_detection: true
```

### 3. Run Estimation

```bash
dbt-cost-guard --project-dir my_project estimate
```

## 🎓 Example Projects

This repository includes two example projects:

### `example_project/`
Simple dbt project demonstrating basic cost estimation

### `test_project/`
Comprehensive test project with:
- Multiple databases (SALES_DB, ANALYTICS_DB, REFERENCE_DB)
- Cross-database queries
- Complex fact models
- 215M rows of test data
- Models ranging from simple to extremely expensive

## 🔬 Testing & Validation

Validate estimates against actual Snowflake costs:

```bash
# Get estimate
dbt-cost-guard --project-dir test_project analyze -m my_model

# Run the model
cd test_project && dbt run --select my_model

# Check actual cost in Snowflake
# (Use provided SQL queries in check_actual_cost.sql)
```

See [RUN_AND_VALIDATE.md](RUN_AND_VALIDATE.md) for complete validation guide.

## 💡 Use Cases

### CI/CD Integration

```yaml
# .github/workflows/dbt-cost-check.yml
- name: Check dbt costs
  run: |
    dbt-cost-guard --project-dir . estimate
    # Fails if costs exceed threshold
```

### Pre-commit Hook

```yaml
# .pre-commit-config.yaml
- repo: local
  hooks:
    - id: dbt-cost-guard
      name: dbt Cost Guard
      entry: dbt-cost-guard estimate
      language: system
      pass_filenames: false
```

### Airflow Integration

```python
from dbt_cost_guard.estimator import CostEstimator

# Estimate before running
estimator = CostEstimator(project_dir, profiles_dir, config)
cost = estimator.estimate_run_costs(models)

if cost > threshold:
    raise AirflowSkipException("Cost too high!")
```

## 📈 Accuracy

Based on validation with real Snowflake queries:

- **Cost Accuracy**: ✅ Exact match for billing (1-minute minimum correctly applied)
- **Time Estimates**: ⚠️ Conservative (better to overestimate than underestimate)
- **Best For**: Preventing expensive mistakes, warehouse optimization, cost awareness

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

```bash
# Clone repository
git clone https://github.com/standmitriev/dbt-cost-guard.git
cd dbt-cost-guard

# Create virtual environment
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows

# Install in development mode
pip install -e ".[dev]"

# Run tests
pytest

# Run with coverage
pytest --cov=dbt_cost_guard --cov-report=html
```

## 🗺️ Roadmap

Future enhancements:
- Support for BigQuery, Redshift, Databricks
- Machine learning-based estimation
- Historical cost tracking database
- Cost anomaly detection
- Team cost allocation
- Web UI dashboard

See [IMPROVEMENTS.md](IMPROVEMENTS.md) for detailed roadmap.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

Built for data teams who want to:
- Stop worrying about surprise Snowflake bills
- Make informed decisions about warehouse sizing
- Optimize their dbt workflows
- Save money while maintaining performance

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/standmitriev/dbt-cost-guard/issues)
- **Discussions**: [GitHub Discussions](https://github.com/standmitriev/dbt-cost-guard/discussions)

## ⭐ Star History

If dbt-cost-guard helps you save money, please give it a star! ⭐

---

Made with ❤️ for the dbt community

**Save money. Run confident. Use dbt-cost-guard.**


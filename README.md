# dbt-cost-guard 💰

**Prevent costly Snowflake mistakes before they happen!**

`dbt-cost-guard` estimates the cost of your dbt models **before** running them, helping data teams avoid expensive warehouse bills and optimize their Snowflake spending.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)

## 🎯 Why dbt-cost-guard?

Data teams running dbt on Snowflake face a common problem: **unexpected costs**. A single expensive query or running models on the wrong warehouse can cost thousands of dollars.

**dbt-cost-guard helps you:**
- 💰 **Estimate costs before running** - Know what you'll spend before executing
- 📊 **Project long-term costs** - See annual costs based on run frequency ($17K-$420K/year!)
- ⚠️ **Get warnings** - Automatic alerts for expensive operations
- 🎯 **Optimize warehouse selection** - Find cost savings opportunities
- 📈 **Track spending trends** - Understand where your money goes

### Real-World Example

```bash
$ dbt-cost-guard --project-dir my_project estimate

✓ Found 15 models

Cost Estimate Breakdown
┏━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━━┓
┃ Model            ┃ Est. Cost ┃ Est. Time ┃
┡━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━━┩
│ fct_orders       │     $3.20 │     12.5s │
│ fct_customers    │     $8.40 │     28.3s │
│ ...              │       ... │       ... │
├──────────────────┼───────────┼───────────┤
│ TOTAL            │    $48.00 │           │
└──────────────────┴───────────┴───────────┘

💰 Long-Term Cost Projections:
┃ Daily (1×)    ┃ $48.00     ┃ $17,520/year   ┃
┃ Twice Daily   ┃ $96.00/day ┃ $35,040/year   ┃
┃ Hourly (24×)  ┃ $1,152/day ┃ $420,480/year  ┃

💵 Cost Optimization Opportunity:
  Potential Annual Savings: $15,330
  Switch from 3X-Large to X-Small warehouse
```

**That's $15,000+ in annual savings!**

## 🚀 Quick Start

### Installation

```bash
pip install git+https://github.com/standmitriev/dbt-cost-guard.git
```

### Basic Usage

```bash
# Estimate costs without running
dbt-cost-guard --project-dir my_project estimate

# Run dbt with cost checking
dbt-cost-guard --project-dir my_project run

# Analyze a specific model
dbt-cost-guard --project-dir my_project analyze -m my_model
```

For detailed setup instructions, see [INSTALLATION.md](INSTALLATION.md).

## 📊 Features

### 🎯 Multi-Layered Accuracy

dbt-cost-guard uses multiple estimation methods for maximum accuracy:

1. **EXPLAIN Plans** - Analyzes Snowflake's query execution plans
2. **Historical Data** - Learns from past query performance  
3. **Heuristics** - Intelligent complexity scoring (JOINs, window functions, etc.)
4. **Cache Detection** - Identifies potential cache hits
5. **Billing Rules** - Applies Snowflake's actual billing (1-minute minimum)

### 💰 Long-Term Cost Projections

See how costs add up over time with different run frequencies:
- Daily, weekly, monthly, annual projections
- Savings recommendations
- Warehouse optimization suggestions

### ⚠️ Warning System

Get automatic warnings for:
- Expensive individual models (> $5)
- High total run costs (> $20)
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
```

## 📖 Documentation

- **[INSTALLATION.md](INSTALLATION.md)** - Detailed installation guide
- **[SETUP.md](SETUP.md)** - Quick start guide
- **[USAGE.md](USAGE.md)** - Command reference
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - How to contribute
- **[docs/ROADMAP.md](docs/ROADMAP.md)** - Future enhancements
- **[docs/REAL_WORLD_USAGE.md](docs/REAL_WORLD_USAGE.md)** - CI/CD integration examples
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Technical architecture

## 💡 Use Cases

### CI/CD Integration

Prevent expensive deployments:

```yaml
# .github/workflows/dbt-cost-check.yml
- name: Check dbt costs
  run: |
    dbt-cost-guard --project-dir . estimate
    # Fails if costs exceed threshold
```

### Pre-commit Hook

Catch expensive queries before commit:

```yaml
# .pre-commit-config.yaml
- repo: local
  hooks:
    - id: dbt-cost-guard
      name: dbt Cost Guard
      entry: dbt-cost-guard estimate
      language: system
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

See [docs/REAL_WORLD_USAGE.md](docs/REAL_WORLD_USAGE.md) for more examples.

## 🎓 Example Projects

This repository includes example projects to help you get started:

- **[example_project/](example_project/)** - Simple dbt project demonstrating basic cost estimation
- **[test_project/](test_project/)** - Advanced examples with cross-database queries and complex models

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

```bash
git clone https://github.com/standmitriev/dbt-cost-guard.git
cd dbt-cost-guard
python -m venv venv
source venv/bin/activate
pip install -e ".[dev]"
pytest
```

## 📈 Accuracy

Based on validation with real Snowflake queries:

- **Cost Accuracy**: ✅ Exact match for billing (1-minute minimum correctly applied)
- **Time Estimates**: ⚠️ Conservative (better to overestimate than underestimate)
- **Best For**: Preventing expensive mistakes, warehouse optimization, cost awareness

## 🗺️ Roadmap

Future enhancements:
- Support for BigQuery, Redshift, Databricks
- Machine learning-based estimation
- Historical cost tracking database
- Cost anomaly detection
- Web UI dashboard

See [docs/ROADMAP.md](docs/ROADMAP.md) for detailed plans.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🙏 Acknowledgments

Built for data teams who want to:
- Stop worrying about surprise Snowflake bills
- Make informed decisions about warehouse sizing  
- Optimize their dbt workflows
- Save money while maintaining performance

## ⭐ Star This Project

If dbt-cost-guard helps you save money, please give it a star! ⭐

---

**Save money. Run confident. Use dbt-cost-guard.**

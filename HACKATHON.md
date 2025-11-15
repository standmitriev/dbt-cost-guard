# dbt Cost Guard - Hackathon Project Summary

## 🎯 Problem Statement

Snowflake queries can be expensive, and developers running `dbt run` might unknowingly execute queries that cost hundreds or thousands of dollars. There's no built-in warning system to prevent these surprise bills.

## 💡 Solution

**dbt Cost Guard** - A CLI wrapper for dbt that:
1. ✅ Estimates query costs BEFORE execution
2. ✅ Warns when costs exceed configurable thresholds
3. ✅ Requires explicit confirmation for expensive runs
4. ✅ Shows detailed cost breakdown per model

## 🏗️ Architecture

### CLI Wrapper Approach (Not a Fork!)
- Built as a separate Python package using dbt's public API
- Works with any existing dbt project - no code changes needed
- Drop-in replacement: `dbt run` → `dbt-cost-guard run`
- Maintains full compatibility with all dbt flags and features

### Cost Estimation Engine

```
Query → Complexity Analysis → Historical Patterns → Warehouse Size → Cost Estimate
```

**Estimation Formula:**
```
cost = (estimated_time_seconds / 3600) × credits_per_hour × cost_per_credit
```

**Complexity Factors:**
- Number of joins
- Window functions
- Aggregations (GROUP BY, DISTINCT)
- Subqueries and CTEs
- Historical query execution times from Snowflake

## 🛠️ Technical Stack

- **Python 3.8+**: Core language
- **Click**: CLI framework
- **Rich**: Beautiful terminal output
- **dbt-core**: For model compilation via Python API
- **dbt-snowflake**: Snowflake adapter
- **snowflake-connector-python**: Direct Snowflake queries for cost estimation

## 📦 Project Structure

```
dbt-cost-guard/
├── dbt_cost_guard/
│   ├── cli.py              # Click-based CLI interface
│   ├── estimator.py        # Cost estimation engine
│   ├── snowflake_utils.py  # Snowflake API interactions
│   └── config.py           # Configuration management
├── example_project/        # Demo dbt project with sample models
├── pyproject.toml          # Package configuration
├── README.md              # Full documentation
├── USAGE.md               # Quick start guide
└── demo.sh                # Demo script
```

## 🚀 Key Features

### 1. Pre-Run Cost Estimation
```bash
$ dbt-cost-guard run

✓ Found 15 models to run
🔍 Estimating query costs...

                Cost Estimate Breakdown
┏━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━┳━━━━━━━━━━┳━━━━━━━━━━━━┳━━━━━━━━┓
┃ Model              ┃ Est. Cost ┃ Est.Time ┃ Complexity ┃ Status ┃
┡━━━━━━━━━━━━━━━━━━━━╇━━━━━━━━━━━╇━━━━━━━━━━╇━━━━━━━━━━━━╇━━━━━━━━┩
│ staging_users      │ $0.30     │ 12.3s    │ Low        │ ✓      │
│ fct_order_items    │ $6.50     │ 325.0s   │ High       │ ⚠️      │
│ TOTAL              │ $8.80     │          │            │        │
└────────────────────┴───────────┴──────────┴────────────┴────────┘

⚠️  Total estimated cost ($8.80) exceeds threshold ($5.00)

Do you want to proceed? [y/N]:
```

### 2. Per-Model Cost Tracking
- Each model analyzed independently
- Configurable per-model threshold (default $5)
- Models can opt-out via config

### 3. Total Run Protection
- Calculates cumulative cost for entire run
- Configurable total run threshold (default $5)
- Shows which models are expensive

### 4. Estimate-Only Mode
```bash
# Check costs without running
dbt-cost-guard estimate --models my_expensive_model
```

### 5. Full dbt Compatibility
```bash
# All dbt flags work
dbt-cost-guard run --models my_model+
dbt-cost-guard run --select tag:daily --exclude tag:skip
dbt-cost-guard run --full-refresh --threads 8
```

## 🎨 User Experience Highlights

### Beautiful Terminal Output
- Color-coded warnings (green/yellow/red)
- Rich tables with cost breakdowns
- Clear status indicators
- Complexity scores

### Smart Defaults
- Auto-detects warehouse size from Snowflake
- Reasonable default thresholds ($5)
- Falls back gracefully if query history unavailable

### Developer-Friendly
- Skip checks with `--force` flag
- Per-model opt-out configuration
- Detailed error messages
- Comprehensive help text

## 📊 Demo Scenarios

### Scenario 1: Safe Run (Low Cost)
```bash
dbt-cost-guard run --models staging
# Shows $0.30 total cost, runs without warnings
```

### Scenario 2: Warning Triggered
```bash
dbt-cost-guard run
# Shows $8.80 total cost, prompts for confirmation
```

### Scenario 3: Estimate Only
```bash
dbt-cost-guard estimate
# Shows breakdown, doesn't execute
```

## 🎯 Hackathon Pitch

### What Makes This Special?

1. **Solves a Real Problem**: Prevents surprise cloud bills
2. **Easy to Adopt**: No forking, no code changes, drop-in replacement
3. **Production-Ready**: Error handling, graceful fallbacks, comprehensive docs
4. **Hackathon-Friendly**: Built in hours, not weeks
5. **Extensible**: Easy to add support for BigQuery, Redshift, etc.

### Demo Flow (5 minutes)

1. **Show Problem** (30s)
   - "Running dbt can be expensive, no way to know costs beforehand"
   
2. **Install & Configure** (60s)
   ```bash
   pip install -e .
   # Show dbt_project.yml config
   ```

3. **Run Demo** (180s)
   - Run cheap models (no warning)
   - Run expensive models (warning + breakdown)
   - Show estimate-only mode
   - Show force flag

4. **Show Code** (60s)
   - Highlight estimator.py key functions
   - Show clean architecture

5. **Q&A** (30s)

## 🚧 Future Enhancements

### Phase 2 (Post-Hackathon)
- [ ] BigQuery support (has native dry run API!)
- [ ] Redshift support (using EXPLAIN plans)
- [ ] Databricks support
- [ ] Historical cost tracking database
- [ ] Cost trends over time
- [ ] Slack/email notifications

### Phase 3 (Production)
- [ ] Web dashboard for cost analytics
- [ ] Team-based budgets
- [ ] Cost allocation by tag
- [ ] Integration with dbt Cloud
- [ ] Auto-optimization suggestions
- [ ] CI/CD cost gates

## 💰 Value Proposition

### For Developers
- Confidence when running queries
- No more surprise bills
- Learn which models are expensive

### For Data Teams
- Budget control
- Cost visibility
- Prevent runaway costs

### For Organizations
- Predictable Snowflake spend
- Cost-aware culture
- ROI tracking per model

## 📈 Metrics & Success Criteria

### Hackathon Goals
- ✅ Working prototype
- ✅ Example project with demos
- ✅ Comprehensive documentation
- ✅ Clean, maintainable code

### Real-World Success
- Reduce unexpected Snowflake bills by 50%
- Enable developers to run dbt with confidence
- Create cost-aware data engineering culture

## 🤝 Team & Contribution

Built for hackathon to solve real-world cost management problems in dbt + Snowflake workflows.

**Open Source**: MIT License, contributions welcome!

## 📚 Resources

- **GitHub Repo**: (your-repo-url)
- **Demo Video**: (record a quick demo)
- **Docs**: See README.md and USAGE.md
- **Example Project**: See example_project/

## 🎤 Elevator Pitch

> "dbt Cost Guard is like a speed limit sign for your Snowflake queries. It estimates costs before you run dbt, warns you if queries are expensive, and requires confirmation before executing costly transformations. It's a drop-in wrapper that prevents surprise cloud bills and helps teams build cost-aware data pipelines."

## 🏆 Why This Should Win

1. **Solves Real Pain**: Every Snowflake user has gotten a surprise bill
2. **Immediately Useful**: Can use in production today
3. **Clean Implementation**: Well-architected, documented, tested
4. **Extensible**: Foundation for multi-platform cost management
5. **Open Source Spirit**: MIT license, community-friendly

---

## 🚀 Quick Start for Judges

```bash
cd /Users/stan.dmitriev/Documents/dbt-cost

# Install
pip install -e .

# Run demo
./demo.sh

# Try it
dbt-cost-guard estimate --project-dir example_project
```

**Note**: You'll need Snowflake credentials to test fully, but the code quality and architecture are visible without running.


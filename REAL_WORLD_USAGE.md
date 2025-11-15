# 🌍 Real-World Usage Guide: dbt-cost-guard

## How to Use This in Your Actual dbt Project

---

## 🚀 Quick Start (5 minutes)

### 1. Install in Your Project

```bash
# In your dbt project directory
cd /path/to/your/dbt/project

# Clone dbt-cost-guard
git clone https://github.com/your-org/dbt-cost-guard
cd dbt-cost-guard

# Install in a virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -e .
```

### 2. Run Your First Cost Estimate

```bash
# Estimate all models
dbt-cost-guard --project-dir /path/to/your/dbt/project estimate

# Estimate specific models
dbt-cost-guard --project-dir /path/to/your/dbt/project estimate --select staging.*

# Analyze a specific expensive model
dbt-cost-guard --project-dir /path/to/your/dbt/project analyze -m fct_large_orders
```

### 3. Integrate with Your Workflow

```bash
# Before running dbt in production
dbt-cost-guard --project-dir . run --threshold 50.00

# If cost > $50, it will prompt for confirmation
# Type 'n' to cancel and investigate
# Type 'y' to proceed anyway
```

---

## 🎯 Use Cases

### Use Case 1: **Pre-Deployment Cost Check**

**Scenario:** You've written a new dbt model and want to check cost before deploying.

```bash
# In your CI/CD pipeline (GitHub Actions, GitLab CI, etc.)
name: Cost Check
on: [pull_request]

jobs:
  cost-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Install dbt-cost-guard
        run: |
          pip install -e .
      
      - name: Check costs for changed models
        run: |
          # Get changed models
          CHANGED_MODELS=$(git diff --name-only origin/main | grep "models/" | xargs)
          
          # Estimate cost
          dbt-cost-guard --project-dir . estimate --select path:$CHANGED_MODELS
          
          # Fail if total cost > $100
          if [ $COST -gt 100 ]; then
            echo "❌ Cost too high! Review your models."
            exit 1
          fi
```

**Benefits:**
- 🚨 Catch expensive queries before merge
- 💰 Prevent surprise bills
- 📊 Cost visibility in PRs

---

### Use Case 2: **Daily Cost Report**

**Scenario:** Track your team's dbt costs daily.

```bash
#!/bin/bash
# daily_cost_report.sh

# Run cost estimation
dbt-cost-guard --project-dir /path/to/dbt/project estimate > /tmp/cost_report.txt

# Send to Slack
curl -X POST -H 'Content-type: application/json' \
  --data "{
    \"text\": \"📊 Daily DBT Cost Report\",
    \"attachments\": [{
      \"text\": \"$(cat /tmp/cost_report.txt)\"
    }]
  }" \
  $SLACK_WEBHOOK_URL

# Or email it
mail -s "DBT Cost Report" team@company.com < /tmp/cost_report.txt
```

**Add to crontab:**
```bash
# Run every day at 9 AM
0 9 * * * /path/to/daily_cost_report.sh
```

**Benefits:**
- 📧 Daily cost visibility
- 📈 Track cost trends over time
- 🎯 Identify cost spikes quickly

---

### Use Case 3: **Pre-Commit Hook**

**Scenario:** Prevent developers from committing expensive models.

```bash
# .git/hooks/pre-commit

#!/bin/bash

# Get staged model files
STAGED_MODELS=$(git diff --cached --name-only --diff-filter=ACM | grep "models/.*\.sql$")

if [ -n "$STAGED_MODELS" ]; then
  echo "🔍 Checking costs for staged models..."
  
  for model in $STAGED_MODELS; do
    MODEL_NAME=$(basename $model .sql)
    
    # Estimate cost for this model
    COST=$(dbt-cost-guard --project-dir . analyze -m $MODEL_NAME 2>&1 | grep "Estimated Cost" | awk '{print $3}')
    
    # Remove $ and compare
    COST_NUM=$(echo $COST | tr -d '$')
    
    if (( $(echo "$COST_NUM > 10.0" | bc -l) )); then
      echo "❌ Model $MODEL_NAME is expensive (\$$COST_NUM)"
      echo "   Please review before committing."
      echo "   Run: dbt-cost-guard analyze -m $MODEL_NAME"
      exit 1
    fi
  done
  
  echo "✅ All models within cost threshold"
fi
```

**Benefits:**
- 🛡️ Prevent expensive models from being committed
- 🎓 Educate developers about costs
- ⚡ Fast feedback loop

---

### Use Case 4: **Scheduled dbt Runs**

**Scenario:** You run dbt on a schedule (Airflow, cron, etc.).

**With Airflow:**
```python
from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime

dag = DAG('dbt_production', start_date=datetime(2024, 1, 1), schedule_interval='0 2 * * *')

# Cost check first
cost_check = BashOperator(
    task_id='check_costs',
    bash_command='''
        cd /path/to/dbt/project
        source venv/bin/activate
        
        # Estimate costs
        COST=$(dbt-cost-guard estimate 2>&1 | grep "TOTAL" | awk '{print $2}' | tr -d '$')
        
        # Fail if > $100
        if (( $(echo "$COST > 100.0" | bc -l) )); then
            echo "Cost too high: \$$COST"
            exit 1
        fi
    ''',
    dag=dag
)

# Run dbt only if cost check passes
dbt_run = BashOperator(
    task_id='dbt_run',
    bash_command='cd /path/to/dbt/project && dbt run',
    dag=dag
)

cost_check >> dbt_run  # Cost check must pass first
```

**Benefits:**
- 🚨 Automatic cost gating
- 💰 Prevent runaway costs in production
- 📊 Cost tracking in Airflow logs

---

### Use Case 5: **Cost-Based Model Prioritization**

**Scenario:** You want to run cheap models first, expensive ones later.

```bash
#!/bin/bash
# smart_dbt_run.sh

# Get all models with costs
dbt-cost-guard --project-dir . estimate > /tmp/costs.txt

# Parse and sort by cost
cat /tmp/costs.txt | grep "│" | sort -t'$' -k2 -n > /tmp/sorted_costs.txt

# Run cheap models first (cost < $1)
echo "Running cheap models first..."
CHEAP_MODELS=$(cat /tmp/sorted_costs.txt | awk -F'│' '{print $2, $3}' | awk '$2 < 1.0 {print $1}')
dbt run --select $CHEAP_MODELS

# Then run expensive models with confirmation
echo "Running expensive models..."
EXPENSIVE_MODELS=$(cat /tmp/sorted_costs.txt | awk -F'│' '{print $2, $3}' | awk '$2 >= 1.0 {print $1}')
dbt-cost-guard run --select $EXPENSIVE_MODELS --threshold 5.0
```

**Benefits:**
- ⚡ Fast feedback for cheap models
- 💰 Cost control for expensive models
- 🎯 Efficient resource usage

---

### Use Case 6: **Development vs. Production**

**Scenario:** Different cost thresholds for dev vs. prod.

```bash
# In development (loose threshold)
if [ "$ENV" = "development" ]; then
  dbt-cost-guard run --threshold 100.0  # Allow expensive dev runs
else
  # In production (strict threshold)
  dbt-cost-guard run --threshold 10.0   # Be careful with prod costs
fi
```

**Or with config:**
```yaml
# profiles.yml
my_project:
  outputs:
    dev:
      type: snowflake
      warehouse: X-SMALL  # Cheap warehouse for dev
      
    prod:
      type: snowflake
      warehouse: X-LARGE  # Expensive warehouse for prod
```

```bash
# Development: use X-SMALL warehouse
dbt-cost-guard --target dev run --threshold 5.0

# Production: use X-LARGE warehouse, higher threshold
dbt-cost-guard --target prod run --threshold 50.0
```

---

### Use Case 7: **Cost Monitoring Dashboard**

**Scenario:** Track costs over time in a dashboard.

```bash
#!/bin/bash
# log_costs.sh

DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M:%S)

# Get cost estimate
COST=$(dbt-cost-guard --project-dir . estimate 2>&1 | grep "TOTAL" | awk '{print $2}' | tr -d '$')

# Log to CSV
echo "$DATE,$TIME,$COST" >> /var/log/dbt_costs.csv

# Upload to S3 for analysis
aws s3 cp /var/log/dbt_costs.csv s3://my-bucket/dbt-costs/

# Or insert into database
psql -c "INSERT INTO dbt_cost_log (date, time, estimated_cost) VALUES ('$DATE', '$TIME', $COST)"
```

**Then visualize with:**
- 📊 Grafana
- 📈 Tableau
- 💻 Python notebook (matplotlib/plotly)

---

## 📋 Best Practices

### 1. **Set Per-Environment Thresholds**

```yaml
# .dbt-cost-guard.yml
environments:
  development:
    threshold: 20.00
    warehouse: X-SMALL
  
  staging:
    threshold: 50.00
    warehouse: SMALL
  
  production:
    threshold: 100.00
    warehouse: LARGE
```

### 2. **Tag Expensive Models**

```sql
-- models/marts/fct_large_orders.sql
{{ config(
    materialized='table',
    tags=['expensive', 'analytics'],
    meta={
        'cost_threshold': 25.00,
        'owner': 'analytics_team'
    }
) }}
```

### 3. **Document Cost Expectations**

```markdown
# models/marts/README.md

## Cost Guidelines

| Model | Expected Cost | Notes |
|-------|--------------|-------|
| fct_orders | $5-10 | Daily full refresh |
| fct_order_items | $100+ | Complex window functions |
| dim_customers | $2-5 | Incremental |
```

### 4. **Create Cost Alerts**

```python
# cost_alert.py
import subprocess
import json

result = subprocess.run([
    'dbt-cost-guard', 'estimate', '--project-dir', '.'
], capture_output=True, text=True)

# Parse total cost
total_cost = parse_cost(result.stdout)

if total_cost > 100:
    # Send alert to PagerDuty / Slack / Email
    send_alert(f"⚠️ DBT cost alert: ${total_cost}")
```

---

## 🛠️ Integration with Existing Tools

### With dbt Cloud:
```bash
# In dbt Cloud job commands
dbt-cost-guard estimate
dbt run
```

### With Airflow:
```python
from airflow.providers.dbt.cloud.operators.dbt import DbtCloudRunJobOperator

# Add cost check before dbt job
```

### With Prefect:
```python
from prefect import task, flow

@task
def check_dbt_costs():
    # Run cost guard
    pass

@task
def run_dbt():
    # Run dbt
    pass

@flow
def dbt_pipeline():
    costs = check_dbt_costs()
    if costs < 100:
        run_dbt()
```

---

## 🎯 Common Workflows

### **Workflow 1: Morning Check**
```bash
# Check costs before daily run
dbt-cost-guard estimate
# Review output
# Run specific models if needed
dbt run --select model_name
```

### **Workflow 2: PR Review**
```bash
# On feature branch
git checkout feature/new-model
dbt-cost-guard analyze -m new_model
# If cost OK, commit
git add models/new_model.sql
git commit -m "Add new model"
```

### **Workflow 3: Production Deploy**
```bash
# On main branch
git pull origin main
dbt-cost-guard estimate
# If OK, deploy
dbt run --select state:modified+
```

---

## 📊 Example Output Interpretation

```
┃ Model                 ┃ Est. Cost ┃ Est. Time ┃ Complexity ┃ Status ┃
│ stg_users             │     $0.01 │     18.0s │    Low     │   ✓    │  ← Safe
│ fct_order_items       │   $100.62 │ 120744.0s │    High    │   ⚠️    │  ← Review!
```

**Action Items:**
- ✅ `stg_users`: Safe to run
- ⚠️ `fct_order_items`: Investigate before running
  - Check for optimization opportunities
  - Consider incremental materialization
  - Maybe run during off-peak hours

---

## 🚨 Troubleshooting

### Issue: "Model not found"
```bash
# List all models
dbt ls --resource-type model

# Check if model name matches
dbt-cost-guard analyze -m exact_model_name
```

### Issue: "Connection failed"
```bash
# Verify Snowflake credentials
dbt debug

# Check profiles.yml
cat ~/.dbt/profiles.yml
```

### Issue: "Cost shows $0.00"
- Check if tables have data
- Run `dbt compile` first
- Verify `INFORMATION_SCHEMA` permissions

---

## 📚 Additional Resources

- [dbt Documentation](https://docs.getdbt.com/)
- [Snowflake Cost Optimization](https://docs.snowflake.com/en/user-guide/cost-understanding)
- [Query Optimization Guide](./OPTIMIZATION_GUIDE.md)

---

## 🎓 Training Your Team

### 1. **Lunch & Learn Session**
- Show demo of tool
- Walk through expensive query
- Demonstrate cost reduction techniques

### 2. **Add to Onboarding**
- New developers learn cost awareness
- Include in engineering standards
- Part of code review checklist

### 3. **Monthly Cost Review**
- Review most expensive models
- Discuss optimization opportunities
- Share cost savings wins

---

## ✅ Success Metrics

Track these metrics to measure success:

- 📉 **Total DBT costs** (should decrease over time)
- ⚡ **Average model runtime** (should decrease)
- 🎯 **% of models under threshold** (should increase)
- 🚨 **Number of cost alerts** (should decrease as team learns)
- 💰 **Cost savings month-over-month**

---

## 🎯 Next Steps

1. ✅ Install dbt-cost-guard in your project
2. ✅ Run initial cost analysis
3. ✅ Set appropriate thresholds
4. ✅ Add to CI/CD pipeline
5. ✅ Train your team
6. ✅ Monitor and optimize

**Start small, measure impact, iterate!** 🚀


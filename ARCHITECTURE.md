# dbt Cost Guard - Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        USER RUNS: dbt-cost-guard run                     │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                          CLI INTERFACE (cli.py)                          │
│                                                                           │
│  • Parses command-line arguments                                         │
│  • Loads configuration from dbt_project.yml                              │
│  • Displays rich terminal output (tables, colors, prompts)               │
│  • Handles user confirmation                                             │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    CONFIGURATION (config.py)                             │
│                                                                           │
│  • Loads dbt_project.yml                                                 │
│  • Merges CLI overrides                                                  │
│  • Provides warehouse credit rates                                       │
│  • Returns: cost_per_credit, thresholds, etc.                           │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     COST ESTIMATOR (estimator.py)                        │
│                                                                           │
│  ┌──────────────────────────────────────────────────────────┐            │
│  │  1. Compile Models (dbt Python API)                      │            │
│  │     • dbtRunner().invoke(['ls'])                         │            │
│  │     • Parse manifest.json                                │            │
│  │     • Extract compiled SQL                               │            │
│  └──────────────────────────────────────────────────────────┘            │
│                              │                                            │
│                              ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐            │
│  │  2. Analyze SQL Complexity                               │            │
│  │     • Count JOINs                                        │            │
│  │     • Detect window functions                            │            │
│  │     • Count aggregations                                 │            │
│  │     • Calculate complexity score (0-100)                 │            │
│  └──────────────────────────────────────────────────────────┘            │
│                              │                                            │
│                              ▼                                            │
│  ┌──────────────────────────────────────────────────────────┐            │
│  │  3. Query Snowflake History (via snowflake_utils.py)    │◄───────────┼───┐
│  │     • Find similar historical queries                    │            │   │
│  │     • Get actual execution times                         │            │   │
│  │     • Extract table statistics                           │            │   │
│  └──────────────────────────────────────────────────────────┘            │   │
│                              │                                            │   │
│                              ▼                                            │   │
│  ┌──────────────────────────────────────────────────────────┐            │   │
│  │  4. Estimate Execution Time                              │            │   │
│  │     • Use historical median if available                 │            │   │
│  │     • Fallback to complexity heuristics                  │            │   │
│  │     • Adjust for query size/patterns                     │            │   │
│  └──────────────────────────────────────────────────────────┘            │   │
│                              │                                            │   │
│                              ▼                                            │   │
│  ┌──────────────────────────────────────────────────────────┐            │   │
│  │  5. Calculate Cost                                       │            │   │
│  │     cost = (time_seconds / 3600)                         │            │   │
│  │          × warehouse_credits_per_hour                    │            │   │
│  │          × cost_per_credit                               │            │   │
│  └──────────────────────────────────────────────────────────┘            │   │
└───────────────────────────────┬─────────────────────────────────────────┘   │
                                │                                              │
                                ▼                                              │
┌─────────────────────────────────────────────────────────────────────────┐   │
│                  SNOWFLAKE UTILITIES (snowflake_utils.py)                │◄──┘
│                                                                           │
│  ┌─────────────────────────────────────────────────────────┐             │
│  │  Connection Management                                  │             │
│  │    • snowflake.connector.connect()                      │             │
│  │    • Context manager for cleanup                        │             │
│  └─────────────────────────────────────────────────────────┘             │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────┐             │
│  │  Query History Analysis                                 │             │
│  │    • SELECT FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY  │             │
│  │    • Filter by similar tables/patterns                  │             │
│  │    • Return execution metadata                          │             │
│  └─────────────────────────────────────────────────────────┘             │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────┐             │
│  │  Warehouse Metadata                                     │             │
│  │    • SHOW WAREHOUSES                                    │             │
│  │    • Get current warehouse size                         │             │
│  └─────────────────────────────────────────────────────────┘             │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────┐             │
│  │  Table Statistics                                       │             │
│  │    • Query INFORMATION_SCHEMA.TABLES                    │             │
│  │    • Get row counts and byte sizes                      │             │
│  └─────────────────────────────────────────────────────────┘             │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       COST BREAKDOWN & WARNINGS                          │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────┐             │
│  │        Cost Estimate Breakdown                          │             │
│  │  ┌────────────┬──────────┬─────────┬───────────┬──────┐ │             │
│  │  │ Model      │ Est.Cost │ Est.Time│Complexity │Status│ │             │
│  │  ├────────────┼──────────┼─────────┼───────────┼──────┤ │             │
│  │  │ stg_users  │  $0.30   │  12.3s  │   Low     │  ✓   │ │             │
│  │  │ fct_items  │  $6.50   │ 325.0s  │   High    │  ⚠️   │ │             │
│  │  │ TOTAL      │  $8.80   │         │           │      │ │             │
│  │  └────────────┴──────────┴─────────┴───────────┴──────┘ │             │
│  └─────────────────────────────────────────────────────────┘             │
│                                                                           │
│  ⚠️  Total cost ($8.80) exceeds threshold ($5.00)                        │
│  ⚠️  1 model(s) exceed per-model threshold ($5.00)                       │
│                                                                           │
│  Do you want to proceed? [y/N]: _                                        │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                ┌───────────────┴───────────────┐
                │                               │
                ▼                               ▼
         User says YES                    User says NO
                │                               │
                ▼                               ▼
┌──────────────────────────┐      ┌────────────────────────┐
│  Run actual dbt command  │      │  Exit with message     │
│  subprocess.run([        │      │  "Run cancelled"       │
│    'dbt', 'run', ...     │      │  sys.exit(0)           │
│  ])                      │      └────────────────────────┘
└──────────────────────────┘


═══════════════════════════════════════════════════════════════════════

DATA FLOW EXAMPLE:

User Input:
  $ dbt-cost-guard run --models fct_order_items

  ↓

Configuration Loading:
  • cost_per_credit: $3.00
  • threshold_per_model: $5.00
  • warehouse: MEDIUM (4 credits/hour)

  ↓

Model Compilation (dbt API):
  • Compiled SQL extracted
  • 450 lines of SQL with 5 JOINs, 8 window functions

  ↓

Complexity Analysis:
  • JOINs: 5 × 10 = 50 points
  • Window functions: 8 × 8 = 64 points
  • Total complexity: 85/100 (High)

  ↓

Snowflake History Query:
  • Found 3 similar queries
  • Median execution time: 320 seconds

  ↓

Cost Calculation:
  • Time: 320 seconds
  • Warehouse: MEDIUM = 4 credits/hour
  • Cost per credit: $3.00
  • Estimated cost: (320/3600) × 4 × 3 = $1.07

  ↓

Threshold Check:
  • $1.07 < $5.00 per-model threshold ✓
  • Proceeds without warning

  ↓

Execute: dbt run --models fct_order_items

═══════════════════════════════════════════════════════════════════════

KEY DESIGN PRINCIPLES:

1. SEPARATION OF CONCERNS
   • CLI handles user interaction
   • Estimator handles cost logic
   • Snowflake utils handle data access
   • Config handles settings

2. GRACEFUL DEGRADATION
   • If query history unavailable → use heuristics
   • If warehouse size unknown → use default (MEDIUM)
   • If cost estimation fails → warn and proceed

3. USER EXPERIENCE FIRST
   • Clear, color-coded output
   • Detailed cost breakdowns
   • Interactive confirmations
   • Force flag for automation

4. NO FORK REQUIRED
   • Uses dbt's public Python API
   • Wraps, doesn't modify dbt
   • Compatible with all dbt versions
   • Easy to install and use

═══════════════════════════════════════════════════════════════════════
```

## Warehouse Credit Rates

```
Size          Credits/Hour    Example Cost (@ $3/credit)
────────────────────────────────────────────────────────
X-Small       1              $3/hour   ($0.05/min)
Small         2              $6/hour   ($0.10/min)
Medium        4              $12/hour  ($0.20/min)
Large         8              $24/hour  ($0.40/min)
X-Large       16             $48/hour  ($0.80/min)
2X-Large      32             $96/hour  ($1.60/min)
3X-Large      64             $192/hour ($3.20/min)
4X-Large      128            $384/hour ($6.40/min)
```

## Technology Stack

```
┌─────────────────────────────────────────────────┐
│              Application Layer                   │
│                                                  │
│  dbt-cost-guard CLI (Click framework)           │
│    • Command parsing                            │
│    • Rich terminal output                       │
│    • Interactive prompts                        │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│              Business Logic Layer                │
│                                                  │
│  Cost Estimator                                 │
│    • SQL complexity analysis                    │
│    • Historical pattern matching                │
│    • Cost calculation                           │
└──────────────────┬──────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────┐
│            Integration Layer                     │
│                                                  │
│  dbt Python API          Snowflake Connector    │
│    • dbtRunner          • Query execution       │
│    • Manifest parsing   • Metadata queries      │
└──────────────────┬──────────────┬───────────────┘
                   │              │
┌──────────────────▼──────────────▼───────────────┐
│              External Systems                    │
│                                                  │
│  dbt Project            Snowflake Warehouse     │
│    • models/            • QUERY_HISTORY         │
│    • dbt_project.yml    • INFORMATION_SCHEMA    │
│    • profiles.yml       • Warehouse metadata    │
└─────────────────────────────────────────────────┘
```


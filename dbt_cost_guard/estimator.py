"""
Cost estimation engine for dbt models on Snowflake
"""
import re
import json
import yaml
import logging
import math
from pathlib import Path
from typing import List, Dict, Optional, Any
from dbt.cli.main import dbtRunner

from dbt_cost_guard.snowflake_utils import SnowflakeUtils
from dbt_cost_guard.config import get_warehouse_credits_per_hour

logger = logging.getLogger(__name__)


class CostEstimator:
    """Estimates costs for dbt models running on Snowflake"""

    def __init__(
        self,
        project_dir: Path,
        profiles_dir: Optional[Path],
        config: Dict[str, Any],
    ):
        """
        Initialize cost estimator

        Args:
            project_dir: Path to dbt project directory
            profiles_dir: Path to dbt profiles directory (optional)
            config: Cost guard configuration
        """
        self.project_dir = project_dir
        self.profiles_dir = profiles_dir or project_dir
        self.config = config
        self.dbt_runner = dbtRunner()

        # Load dbt profile to get Snowflake connection details
        self.profile_data = self._load_profile()
        self.target_config = self._get_target_config()

        # Initialize Snowflake utils
        self.snowflake_utils = None
        try:
            connection_params = self._get_snowflake_connection_params()
            self.snowflake_utils = SnowflakeUtils(connection_params)
        except Exception as e:
            print(f"Warning: Could not initialize Snowflake connection: {e}")

    def _load_profile(self) -> Dict[str, Any]:
        """Load dbt profiles.yml"""
        # Try multiple locations for profiles.yml
        possible_locations = [
            self.profiles_dir / "profiles.yml",
            Path.home() / ".dbt" / "profiles.yml",
        ]

        for location in possible_locations:
            if location.exists():
                with open(location, "r") as f:
                    return yaml.safe_load(f)

        raise FileNotFoundError("Could not find profiles.yml")

    def _get_target_config(self) -> Dict[str, Any]:
        """Get target configuration from profile"""
        # Load dbt_project.yml to get profile name
        dbt_project_path = self.project_dir / "dbt_project.yml"
        with open(dbt_project_path, "r") as f:
            dbt_project = yaml.safe_load(f)

        profile_name = dbt_project.get("profile")
        if not profile_name:
            raise ValueError("No profile specified in dbt_project.yml")

        profile = self.profile_data.get(profile_name)
        if not profile:
            raise ValueError(f"Profile '{profile_name}' not found in profiles.yml")

        # Get target (default to 'dev' if not specified)
        target_name = profile.get("target", "dev")
        outputs = profile.get("outputs", {})
        target_config = outputs.get(target_name)

        if not target_config:
            raise ValueError(f"Target '{target_name}' not found in profile '{profile_name}'")

        return target_config

    def _get_snowflake_connection_params(self) -> Dict[str, str]:
        """Extract Snowflake connection parameters from target config"""
        params = {
            "account": self.target_config.get("account"),
            "user": self.target_config.get("user"),
            "warehouse": self.target_config.get("warehouse"),
            "database": self.target_config.get("database"),
            "schema": self.target_config.get("schema"),
            "role": self.target_config.get("role"),
        }

        # Handle authentication
        if "password" in self.target_config:
            params["password"] = self.target_config["password"]
        elif "private_key_path" in self.target_config:
            # For key-based auth, would need to load the key
            pass
        elif "authenticator" in self.target_config:
            params["authenticator"] = self.target_config["authenticator"]

        # Remove None values
        params = {k: v for k, v in params.items() if v is not None}

        return params

    def get_models_to_run(
        self, models: Optional[str] = None, exclude: Optional[str] = None
    ) -> List[Dict[str, Any]]:
        """
        Get list of models that would be run by dbt

        Args:
            models: Model selection string
            exclude: Model exclusion string

        Returns:
            List of model metadata dictionaries
        """
        # First, compile models to get compiled SQL
        compile_args = ["compile", "--project-dir", str(self.project_dir)]

        if self.profiles_dir:
            compile_args.extend(["--profiles-dir", str(self.profiles_dir)])

        if models:
            compile_args.extend(["--select", models])

        if exclude:
            compile_args.extend(["--exclude", exclude])

        # Run dbt compile
        result = self.dbt_runner.invoke(compile_args)

        if not result.success:
            raise RuntimeError(f"Failed to compile dbt models: {result.exception}")

        # Parse model information
        models_list = []

        # Read from dbt output (it writes to files in target/)
        manifest_path = self.project_dir / "target" / "manifest.json"
        if manifest_path.exists():
            with open(manifest_path, "r") as f:
                manifest = json.load(f)

            # Extract models from manifest
            for node_id, node in manifest.get("nodes", {}).items():
                if node.get("resource_type") == "model":
                    # Try to get compiled SQL from compiled file if not in manifest
                    compiled_sql = node.get("compiled_sql") or node.get("raw_sql")
                    
                    if not compiled_sql:
                        # Read from compiled file
                        compiled_path = self.project_dir / "target" / "compiled" / node.get("package_name", "example_project") / node.get("original_file_path", "")
                        if compiled_path.exists():
                            with open(compiled_path, "r") as cf:
                                compiled_sql = cf.read()
                    
                    models_list.append(
                        {
                            "unique_id": node_id,
                            "name": node.get("name"),
                            "schema": node.get("schema"),
                            "database": node.get("database"),
                            "alias": node.get("alias"),
                            "compiled_sql": compiled_sql,
                            "config": node.get("config", {}),
                            "depends_on": node.get("depends_on", {}),
                        }
                    )

        return models_list

    def estimate_run_costs(self, models: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Estimate costs for a list of models

        Args:
            models: List of model dictionaries

        Returns:
            List of cost estimates
        """
        cost_estimates = []

        for model in models:
            estimate = self.estimate_model_cost(model)
            cost_estimates.append(estimate)

        return cost_estimates

    def estimate_model_cost(self, model: Dict[str, Any]) -> Dict[str, Any]:
        """
        Estimate cost for a single model

        Args:
            model: Model dictionary with SQL and metadata

        Returns:
            Cost estimate dictionary
        """
        model_name = model.get("name")
        sql = model.get("compiled_sql") or model.get("raw_sql", "")
        
        logger.debug(f"[{model_name}] SQL length = {len(sql) if sql else 0} characters")
        if sql and len(sql) > 0:
            logger.debug(f"[{model_name}] SQL preview: {sql[:300]}")

        # Check if cost estimation is disabled for this model
        model_config = model.get("config", {})
        meta = model_config.get("meta", {})
        if meta.get("cost_guard_skip"):
            return {
                "model_name": model_name,
                "estimated_cost": 0.0,
                "estimated_time_seconds": 0.0,
                "complexity_score": 0,
                "skipped": True,
                "cache_hit_probability": 0.0,
            }

        # Calculate complexity score
        complexity_score = self._calculate_complexity_score(sql)
        logger.debug(f"[{model_name}] Complexity score = {complexity_score}")

        # Check cache probability
        cache_probability = 0.0
        if self.snowflake_utils and sql:
            try:
                cache_probability = self.snowflake_utils.check_cache_probability(sql)
                logger.debug(f"[{model_name}] Cache hit probability = {cache_probability}")
            except Exception as e:
                logger.debug(f"[{model_name}] Could not check cache: {e}")

        # Estimate execution time
        estimated_time = self._estimate_execution_time(sql, model, complexity_score)

        # Calculate cost
        warehouse_name = self.target_config.get("warehouse", "")
        warehouse_size = self._get_warehouse_size(warehouse_name)
        
        # Check if warehouse_credits_per_hour is explicitly set in config
        # (useful for demos or simulating different warehouse sizes)
        if "warehouse_credits_per_hour" in self.config:
            credits_per_hour = self.config["warehouse_credits_per_hour"]
            logger.debug(f"[{model_name}] Using configured warehouse credits: {credits_per_hour}/hour")
        else:
            credits_per_hour = get_warehouse_credits_per_hour(warehouse_size)
            logger.debug(f"[{model_name}] Using detected warehouse size {warehouse_size}: {credits_per_hour}/hour")
        
        cost_per_credit = self.config.get("cost_per_credit", 3.0)

        # Apply per-minute billing rules
        billable_time = self._apply_billing_rules(estimated_time)

        # Cost = (time in hours) * (credits per hour) * (cost per credit)
        estimated_cost = (billable_time / 3600.0) * credits_per_hour * cost_per_credit
        
        # Apply cache probability discount
        if cache_probability > 0.8:
            # Very likely to hit cache - cost is essentially free
            estimated_cost = 0.0
            logger.debug(f"[{model_name}] Cache hit very likely, cost = $0")
        elif cache_probability > 0.5:
            # Likely to hit cache - reduce cost significantly
            estimated_cost *= 0.1
            logger.debug(f"[{model_name}] Cache hit likely, cost reduced by 90%")
        
        # Calculate "scaled cost" - what this WOULD cost on 100x data
        # This helps identify expensive patterns even on small datasets
        scaled_time = estimated_time * max(1.0, (complexity_score / 20.0))  # Scale by complexity
        scaled_billable_time = self._apply_billing_rules(scaled_time)
        scaled_cost = (scaled_billable_time / 3600.0) * credits_per_hour * cost_per_credit
        
        # Determine if this model is "expensive" based on patterns
        is_expensive_pattern = (
            complexity_score > self.config.get("complexity_warning_threshold", 60)
            or scaled_cost > 10.0  # Would cost > $10 at scale
            or sql.upper().count("CROSS JOIN") > 0  # Cartesian product
        )

        return {
            "model_name": model_name,
            "estimated_cost": estimated_cost,
            "estimated_time_seconds": estimated_time,
            "billable_time_seconds": billable_time,
            "complexity_score": complexity_score,
            "warehouse_size": warehouse_size,
            "credits_per_hour": credits_per_hour,
            "cache_hit_probability": cache_probability,
            "scaled_cost": scaled_cost,  # NEW: What it would cost at scale
            "is_expensive_pattern": is_expensive_pattern,  # NEW: Flag for optimization
            "skipped": False,
        }
    
    def _apply_billing_rules(self, time_seconds: float) -> float:
        """
        Apply Snowflake's per-minute billing with 60s minimum
        
        Args:
            time_seconds: Estimated execution time in seconds
            
        Returns:
            Billable time in seconds (rounded up to minutes)
        """
        # Round up to nearest minute
        billable_minutes = math.ceil(time_seconds / 60.0)
        # Minimum 1 minute
        billable_minutes = max(billable_minutes, 1)
        return billable_minutes * 60.0

    def _get_warehouse_size(self, warehouse_name: str) -> str:
        """Get warehouse size from Snowflake or config"""
        if self.snowflake_utils:
            try:
                return self.snowflake_utils.get_current_warehouse_size(warehouse_name)
            except Exception:
                pass

        # Fall back to config or default
        return self.config.get("warehouse_size", "MEDIUM")

    def _calculate_complexity_score(self, sql: str) -> int:
        """
        Calculate complexity score for SQL query (0-100)

        Args:
            sql: SQL query text

        Returns:
            Complexity score
        """
        sql_upper = sql.upper()
        score = 10  # Base score

        # Count joins
        join_count = len(re.findall(r"\bJOIN\b", sql_upper))
        score += min(join_count * 10, 30)

        # Count aggregations
        agg_functions = ["COUNT", "SUM", "AVG", "MAX", "MIN", "GROUP BY"]
        for func in agg_functions:
            if func in sql_upper:
                score += 5

        # Window functions
        if "OVER (" in sql_upper or "OVER(" in sql_upper:
            window_count = len(re.findall(r"\bOVER\s*\(", sql_upper))
            score += min(window_count * 8, 24)

        # Subqueries
        subquery_count = sql_upper.count("SELECT") - 1  # Subtract main SELECT
        score += min(subquery_count * 5, 20)

        # DISTINCT
        if "DISTINCT" in sql_upper:
            score += 5

        # CTEs
        if "WITH " in sql_upper:
            cte_count = sql_upper.count("WITH ")
            score += min(cte_count * 3, 10)

        return min(score, 100)

    def _estimate_execution_time(
        self, sql: str, model: Dict[str, Any], complexity_score: int
    ) -> float:
        """
        Estimate execution time in seconds based on data volume and complexity
        Uses multi-layered approach with fallbacks:
        1. Try EXPLAIN plan (most accurate)
        2. Try historical query data (improves over time)
        3. Fall back to heuristics
        
        Args:
            sql: SQL query text
            model: Model metadata
            complexity_score: Query complexity score
            
        Returns:
            Estimated execution time in seconds
        """
        model_name = model.get("name")
        
        # Layer 1: Try EXPLAIN plan
        if self.snowflake_utils:
            try:
                explain_data = self.snowflake_utils.get_explain_plan(sql)
                if explain_data and explain_data.get("bytes_scanned_estimate", 0) > 0:
                    logger.debug(f"[{model_name}] Using EXPLAIN plan for estimation")
                    return self._estimate_from_explain(explain_data, complexity_score, sql)
            except Exception as e:
                logger.debug(f"[{model_name}] EXPLAIN failed: {e}, trying historical data")
        
        # Layer 2: Try historical query data
        if self.snowflake_utils:
            try:
                history = self.snowflake_utils.get_model_history(model_name, days=30)
                if history and history.get("run_count", 0) > 0:
                    logger.debug(f"[{model_name}] Using historical data for estimation")
                    return self._estimate_from_history(history, complexity_score)
            except Exception as e:
                logger.debug(f"[{model_name}] Historical data failed: {e}, using heuristics")
        
        # Layer 3: Fall back to heuristic estimation
        logger.debug(f"[{model_name}] Using heuristic estimation")
        return self._estimate_from_heuristics(sql, model, complexity_score)
    
    def _estimate_from_explain(self, explain_data: Dict[str, Any], complexity_score: int, sql: str) -> float:
        """
        Estimate execution time from EXPLAIN plan data
        
        Args:
            explain_data: Parsed EXPLAIN plan data
            complexity_score: Query complexity score
            sql: SQL query text (for detecting specific patterns)
            
        Returns:
            Estimated execution time in seconds
        """
        bytes_scanned = explain_data.get("bytes_scanned_estimate", 0)
        
        if bytes_scanned == 0:
            # No reliable data from EXPLAIN, fall back
            return 1.0
        
        # Estimate based on bytes scanned
        # Snowflake MEDIUM warehouse: ~10-20 MB/sec for complex queries
        bytes_mb = bytes_scanned / (1024 * 1024)
        base_throughput_mbps = 15.0  # MB per second
        
        # Adjust for complexity
        complexity_factor = max(complexity_score / 30.0, 1.0)
        adjusted_throughput = base_throughput_mbps / complexity_factor
        
        time_estimate = bytes_mb / adjusted_throughput
        
        # IMPORTANT: EXPLAIN plans often underestimate for complex queries!
        # Apply additional multipliers based on complexity score
        if complexity_score > 80:
            # Very complex queries (lots of window functions/joins) are 5-10x more expensive
            time_estimate *= 10.0
            logger.debug(f"Applied 10x multiplier for very high complexity (>80)")
        elif complexity_score > 50:
            # Medium-high complexity queries are 3-5x more expensive
            time_estimate *= 5.0
            logger.debug(f"Applied 5x multiplier for high complexity (>50)")
        
        # 🔥 DETECT CARTESIAN PRODUCTS (CROSS JOIN)
        sql_upper = sql.upper()
        cross_join_count = sql_upper.count("CROSS JOIN")
        if cross_join_count > 0:
            # CROSS JOINs are CATASTROPHICALLY expensive!
            time_estimate *= (100 ** cross_join_count)  # 100x per CROSS JOIN!
            logger.warning(f"⚠️  CARTESIAN PRODUCT DETECTED: {cross_join_count} CROSS JOIN(s)!")
        
        # Apply multipliers for specific operations
        if explain_data.get("has_full_scan"):
            time_estimate *= 1.5
        
        if not explain_data.get("has_partition_pruning") and explain_data.get("partitions_scanned", 0) > 100:
            time_estimate *= 1.3
        
        # Minimum 1 second
        return max(time_estimate, 1.0)
    
    def _estimate_from_history(self, history: Dict[str, Any], complexity_score: int) -> float:
        """
        Estimate execution time from historical query data
        
        Args:
            history: Historical execution statistics
            complexity_score: Query complexity score
            
        Returns:
            Estimated execution time in seconds
        """
        # Use median time as base (more robust than average)
        # Convert to float in case Snowflake returns Decimal
        median_time = float(history.get("median_time", 0) or 0)
        
        if median_time == 0:
            return 1.0
        
        # If we have enough history, use it directly
        run_count = int(history.get("run_count", 0) or 0)
        if run_count >= 5:
            # High confidence in historical data
            return max(median_time, 1.0)
        
        # Low history count - adjust based on complexity
        # Assume historical query had average complexity of 30
        complexity_adjustment = float(complexity_score) / 30.0
        adjusted_time = median_time * complexity_adjustment
        
        return max(adjusted_time, 1.0)
    
    def _estimate_from_heuristics(
        self, sql: str, model: Dict[str, Any], complexity_score: int
    ) -> float:
        """
        Estimate execution time using heuristics (fallback method)
        
        Args:
            sql: SQL query text
            model: Model metadata
            complexity_score: Query complexity score
            
        Returns:
            Estimated execution time in seconds
        """
        # Enhanced estimation using table statistics
        estimated_rows_processed = 0
        estimated_bytes_processed = 0

        if self.snowflake_utils:
            try:
                # Get source tables from model dependencies instead of parsing SQL
                # This is more reliable than regex parsing
                table_refs = []
                
                # Get database and schema for lookups
                database = model.get("database") or self.target_config.get("database")
                schema_name = model.get("schema") or self.target_config.get("schema")
                
                logger.debug(f"[{model.get('name')}] Using database={database}, schema={schema_name}")
                
                # Check if model has depends_on information
                depends_on = model.get("depends_on", {})
                nodes = depends_on.get("nodes", [])
                
                logger.debug(f"[{model.get('name')}] Depends on {len(nodes)} nodes")
                
                # Extract source tables from dependencies
                for node_id in nodes:
                    if node_id.startswith("source."):
                        # Format: source.project.source_name.table_name
                        parts = node_id.split(".")
                        if len(parts) >= 4:
                            source_schema = parts[2].upper()  # e.g., 'raw'
                            source_table = parts[3].upper()   # e.g., 'users'
                            table_refs.append((database, source_schema, source_table))
                            logger.debug(f"[{model.get('name')}] Added source table {database}.{source_schema}.{source_table}")
                
                if table_refs:
                    stats = self.snowflake_utils.get_table_statistics(table_refs)
                    logger.debug(f"[{model.get('name')}] Got stats for {len(stats)} tables")
                    
                    # Calculate estimated data volume
                    for table_name, table_stats in stats.items():
                        # Convert to float in case Snowflake returns Decimal
                        rows = float(table_stats.get("row_count", 0) or 0)
                        bytes_size = float(table_stats.get("bytes", 0) or 0)
                        estimated_rows_processed += rows
                        estimated_bytes_processed += bytes_size
                        logger.debug(f"[{model.get('name')}] Table {table_name}: {rows} rows, {bytes_size} bytes")
                    
                    logger.debug(f"[{model.get('name')}] Total rows={estimated_rows_processed}, bytes={estimated_bytes_processed}")
            except Exception as e:
                logger.warning(f"Could not get table statistics: {e}")
        
        # If we have data statistics, use them for estimation
        if estimated_rows_processed > 0:
            # Base time calculation on data volume
            # Snowflake processes vary widely: 1k-100k rows/sec depending on query complexity
            # Use VERY conservative estimate for realistic costs, especially for complex queries
            base_throughput = 2000  # rows per second (very conservative for complex queries with JOINs/windows)
            
            # Adjust throughput based on complexity QUADRATICALLY (complexity hurts A LOT!)
            complexity_factor = max((complexity_score / 30.0) ** 1.5, 1.0)  # Exponential penalty
            adjusted_throughput = base_throughput / complexity_factor
            
            time_from_rows = estimated_rows_processed / adjusted_throughput
            
            # Also consider bytes (Snowflake MEDIUM ~10-20MB/sec for complex queries)
            if estimated_bytes_processed > 0:
                bytes_mb = estimated_bytes_processed / (1024 * 1024)
                time_from_bytes = bytes_mb / 10.0  # 10 MB/sec (conservative)
                
                # Use the larger estimate (more conservative)
                time_estimate = max(time_from_rows, time_from_bytes)
            else:
                time_estimate = time_from_rows
            
            # Account for JOINs (multiplicative effect - JOINs are EXPONENTIALLY EXPENSIVE)
            sql_upper = sql.upper()
            join_count = sql_upper.count("JOIN")
            
            # 🔥 DETECT CARTESIAN PRODUCTS (CROSS JOIN or JOIN without ON/USING)
            cross_join_count = sql_upper.count("CROSS JOIN")
            if cross_join_count > 0:
                # CROSS JOINs are CATASTROPHICALLY expensive!
                # Each CROSS JOIN multiplies the dataset by the size of the other table
                # 3 tables = N * M * P rows (potentially trillions!)
                time_estimate *= (100 ** cross_join_count)  # 100x per CROSS JOIN!
                logger.warning(f"⚠️  CARTESIAN PRODUCT DETECTED: {cross_join_count} CROSS JOIN(s)!")
            elif join_count > 0:
                # Regular JOINs are still expensive but not as catastrophic
                # 5 JOINs should be ~10-20x slower
                time_estimate *= (1.5 ** join_count)
            
            # Account for aggregations (slower, especially with many groups)
            if "GROUP BY" in sql_upper:
                time_estimate *= 3.0  # GROUP BY is VERY expensive
            
            # Account for window functions (EXTREMELY expensive on large datasets!)
            if "OVER (" in sql_upper or "OVER(" in sql_upper:
                window_count = len(re.findall(r"\bOVER\s*\(", sql_upper))
                # Window functions require sorting/partitioning entire dataset
                # Each window function is 5-10x slower, and they compound!
                # 14 window functions should be EXTREMELY expensive
                time_estimate *= (1 + (window_count * 5.0))  # Was 3.0, now 5.0
            
            # Account for DISTINCT (full table scan + deduplication)
            if "DISTINCT" in sql_upper:
                time_estimate *= 2.0  # Was 1.5, now 2.0
            
            # Account for ORDER BY (sorting is expensive on large datasets)
            if "ORDER BY" in sql_upper:
                order_by_count = sql_upper.count("ORDER BY")
                time_estimate *= (1 + (order_by_count * 0.5))  # Multiple sorts compound
            
            # Minimum 1 second (Snowflake overhead)
            return max(time_estimate, 1.0)
        
        # Fallback: heuristic estimation based on complexity only
        base_time = 5.0
        time_estimate = base_time * (complexity_score / 30.0)
        
        # Large table scans
        sql_upper = sql.upper()
        if "SCAN" in sql_upper or "FULL" in sql_upper:
            time_estimate *= 1.5

        return max(time_estimate, 1.0)


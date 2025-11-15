"""
Configuration management for dbt-cost-guard
"""
import yaml
import logging
from pathlib import Path
from typing import Optional, Dict, Any
import fnmatch

logger = logging.getLogger(__name__)


def load_config(
    project_dir: Path,
    cost_per_credit: Optional[float] = None,
    threshold: Optional[float] = None,
) -> Dict[str, Any]:
    """
    Load configuration from .dbt-cost-guard.yml and dbt_project.yml
    Priority: CLI args > .dbt-cost-guard.yml > dbt_project.yml > defaults

    Args:
        project_dir: Path to dbt project directory
        cost_per_credit: Override for cost per credit
        threshold: Override for cost threshold

    Returns:
        Configuration dictionary
    """
    config = {
        "cost_per_credit": 3.0,  # Default Snowflake cost
        "warning_threshold_per_model": 5.0,
        "warning_threshold_total_run": 5.0,
        "enabled": True,
        "estimation": {
            "use_explain_plans": True,
            "use_historical_data": True,
            "cache_detection": True,
            "history_days": 30,
        },
        "model_overrides": {},
        "skip_models": [],
    }

    # Try to load from .dbt-cost-guard.yml first
    cost_guard_config_path = project_dir / ".dbt-cost-guard.yml"
    if cost_guard_config_path.exists():
        try:
            with open(cost_guard_config_path, "r") as f:
                cost_guard_config = yaml.safe_load(f)
            
            if cost_guard_config:
                logger.debug(f"Loaded config from {cost_guard_config_path}")
                
                # Update top-level settings
                if "cost_per_credit" in cost_guard_config:
                    config["cost_per_credit"] = cost_guard_config["cost_per_credit"]
                
                if "warehouse_credits_per_hour" in cost_guard_config:
                    config["warehouse_credits_per_hour"] = cost_guard_config["warehouse_credits_per_hour"]
                
                # Update thresholds
                if "thresholds" in cost_guard_config:
                    thresholds = cost_guard_config["thresholds"]
                    if "per_model_warning" in thresholds:
                        config["warning_threshold_per_model"] = thresholds["per_model_warning"]
                    if "total_run_warning" in thresholds:
                        config["warning_threshold_total_run"] = thresholds["total_run_warning"]
                
                # Update estimation settings
                if "estimation" in cost_guard_config:
                    config["estimation"].update(cost_guard_config["estimation"])
                
                # Store model overrides
                if "model_overrides" in cost_guard_config:
                    config["model_overrides"] = cost_guard_config["model_overrides"]
                
                # Store skip models
                if "skip_models" in cost_guard_config:
                    config["skip_models"] = cost_guard_config["skip_models"]
        except Exception as e:
            logger.warning(f"Could not load .dbt-cost-guard.yml: {e}")

    # Try to load from dbt_project.yml (lower priority)
    dbt_project_path = project_dir / "dbt_project.yml"
    if dbt_project_path.exists():
        try:
            with open(dbt_project_path, "r") as f:
                dbt_project = yaml.safe_load(f)

            # Look for cost_guard configuration in vars
            if "vars" in dbt_project and "cost_guard" in dbt_project["vars"]:
                cost_guard_config = dbt_project["vars"]["cost_guard"]
                
                # Only update if not already customized by .dbt-cost-guard.yml
                # Check if values are still at defaults (meaning .dbt-cost-guard.yml didn't set them)
                if "cost_per_credit" in cost_guard_config:
                    # Only override if still at default value
                    if cost_guard_config_path.exists():
                        # Skip - .dbt-cost-guard.yml takes precedence
                        pass
                    else:
                        config["cost_per_credit"] = cost_guard_config["cost_per_credit"]
                
                # Update other settings only if config file doesn't exist
                if not cost_guard_config_path.exists():
                    for key in ["warning_threshold_per_model", "warning_threshold_total_run", "enabled"]:
                        if key in cost_guard_config:
                            config[key] = cost_guard_config[key]
        except Exception as e:
            logger.debug(f"Could not load dbt_project.yml: {e}")

    # Apply CLI overrides (highest priority)
    if cost_per_credit is not None:
        config["cost_per_credit"] = cost_per_credit

    if threshold is not None:
        config["warning_threshold_per_model"] = threshold
        config["warning_threshold_total_run"] = threshold

    return config


def get_model_threshold(config: Dict[str, Any], model_name: str) -> float:
    """
    Get cost threshold for a specific model, considering overrides
    
    Args:
        config: Configuration dictionary
        model_name: Name of the dbt model
        
    Returns:
        Cost threshold for this model
    """
    model_overrides = config.get("model_overrides", {})
    
    # Check each override pattern
    for pattern, override_config in model_overrides.items():
        if fnmatch.fnmatch(model_name, pattern):
            if "threshold" in override_config:
                logger.debug(f"Using override threshold for {model_name}: ${override_config['threshold']}")
                return override_config["threshold"]
    
    # Fall back to default
    return config.get("warning_threshold_per_model", 5.0)


def should_skip_model(config: Dict[str, Any], model_name: str) -> bool:
    """
    Check if a model should be skipped based on configuration
    
    Args:
        config: Configuration dictionary
        model_name: Name of the dbt model
        
    Returns:
        True if model should be skipped
    """
    skip_patterns = config.get("skip_models", [])
    
    for pattern in skip_patterns:
        if fnmatch.fnmatch(model_name, pattern):
            logger.debug(f"Skipping model {model_name} (matches pattern: {pattern})")
            return True
    
    return False


def get_warehouse_credits_per_hour(warehouse_size: str) -> int:
    """
    Get credits per hour for a Snowflake warehouse size

    Args:
        warehouse_size: Warehouse size (e.g., 'SMALL', 'MEDIUM')

    Returns:
        Credits per hour
    """
    warehouse_size = warehouse_size.upper()

    size_to_credits = {
        "X-SMALL": 1,
        "XSMALL": 1,
        "SMALL": 2,
        "MEDIUM": 4,
        "LARGE": 8,
        "X-LARGE": 16,
        "XLARGE": 16,
        "2X-LARGE": 32,
        "2XLARGE": 32,
        "3X-LARGE": 64,
        "3XLARGE": 64,
        "4X-LARGE": 128,
        "4XLARGE": 128,
    }

    return size_to_credits.get(warehouse_size, 2)  # Default to SMALL


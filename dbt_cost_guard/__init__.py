"""
dbt Cost Guard - A CLI wrapper for dbt that estimates Snowflake query costs
"""

__version__ = "0.1.0"
__author__ = "dbt Cost Guard Contributors"

from dbt_cost_guard.estimator import CostEstimator
from dbt_cost_guard.snowflake_utils import SnowflakeUtils

__all__ = ["CostEstimator", "SnowflakeUtils"]

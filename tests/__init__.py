"""
Test package for dbt-cost-guard
"""
import pytest

# Configure pytest
def pytest_configure(config):
    """Configure pytest with custom markers"""
    config.addinivalue_line(
        "markers", "integration: mark test as integration test requiring Snowflake"
    )
    config.addinivalue_line(
        "markers", "slow: mark test as slow running"
    )


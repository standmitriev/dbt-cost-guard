"""
Tests for configuration module
"""
import pytest
import tempfile
import yaml
from pathlib import Path
from dbt_cost_guard.config import (
    load_config,
    get_model_threshold,
    should_skip_model,
    get_warehouse_credits_per_hour
)


class TestLoadConfig:
    """Test configuration loading"""
    
    def test_default_config(self):
        """Test loading with default values when no config files exist"""
        with tempfile.TemporaryDirectory() as tmpdir:
            project_dir = Path(tmpdir)
            config = load_config(project_dir)
            
            assert config['cost_per_credit'] == 3.0
            assert config['warning_threshold_per_model'] == 5.0
            assert config['enabled'] == True
    
    def test_load_from_cost_guard_yml(self):
        """Test loading from .dbt-cost-guard.yml"""
        with tempfile.TemporaryDirectory() as tmpdir:
            project_dir = Path(tmpdir)
            
            # Create .dbt-cost-guard.yml
            config_file = project_dir / '.dbt-cost-guard.yml'
            with open(config_file, 'w') as f:
                yaml.dump({
                    'version': 1,
                    'cost_per_credit': 4.5,
                    'thresholds': {
                        'per_model_warning': 10.0,
                        'total_run_warning': 50.0
                    }
                }, f)
            
            config = load_config(project_dir)
            
            assert config['cost_per_credit'] == 4.5
            assert config['warning_threshold_per_model'] == 10.0
            assert config['warning_threshold_total_run'] == 50.0
    
    def test_cli_override(self):
        """Test CLI arguments override config file"""
        with tempfile.TemporaryDirectory() as tmpdir:
            project_dir = Path(tmpdir)
            
            # Create config with default values
            config_file = project_dir / '.dbt-cost-guard.yml'
            with open(config_file, 'w') as f:
                yaml.dump({
                    'cost_per_credit': 3.0,
                    'thresholds': {'per_model_warning': 5.0}
                }, f)
            
            # CLI override should take precedence
            config = load_config(project_dir, cost_per_credit=10.0, threshold=20.0)
            
            assert config['cost_per_credit'] == 10.0
            assert config['warning_threshold_per_model'] == 20.0
    
    def test_model_overrides(self):
        """Test model-specific threshold overrides"""
        with tempfile.TemporaryDirectory() as tmpdir:
            project_dir = Path(tmpdir)
            
            config_file = project_dir / '.dbt-cost-guard.yml'
            with open(config_file, 'w') as f:
                yaml.dump({
                    'model_overrides': {
                        'fct_*': {'threshold': 20.0},
                        'staging.*': {'threshold': 1.0}
                    }
                }, f)
            
            config = load_config(project_dir)
            
            assert 'fct_*' in config['model_overrides']
            assert config['model_overrides']['fct_*']['threshold'] == 20.0


class TestModelThreshold:
    """Test getting model-specific thresholds"""
    
    def test_default_threshold(self):
        """Test default threshold when no overrides match"""
        config = {
            'warning_threshold_per_model': 5.0,
            'model_overrides': {}
        }
        
        threshold = get_model_threshold(config, 'my_model')
        assert threshold == 5.0
    
    def test_override_threshold(self):
        """Test threshold override for matching pattern"""
        config = {
            'warning_threshold_per_model': 5.0,
            'model_overrides': {
                'fct_*': {'threshold': 20.0}
            }
        }
        
        threshold = get_model_threshold(config, 'fct_orders')
        assert threshold == 20.0
    
    def test_pattern_matching(self):
        """Test glob pattern matching"""
        config = {
            'warning_threshold_per_model': 5.0,
            'model_overrides': {
                'staging.*': {'threshold': 1.0},
                'fct_*': {'threshold': 20.0}
            }
        }
        
        assert get_model_threshold(config, 'staging.users') == 1.0
        assert get_model_threshold(config, 'fct_orders') == 20.0
        assert get_model_threshold(config, 'dim_customers') == 5.0


class TestSkipModel:
    """Test model skipping logic"""
    
    def test_no_skip_patterns(self):
        """Test when no skip patterns configured"""
        config = {'skip_models': []}
        
        assert should_skip_model(config, 'my_model') == False
    
    def test_skip_pattern_match(self):
        """Test skipping models matching patterns"""
        config = {
            'skip_models': ['test_*', 'seeds.*']
        }
        
        assert should_skip_model(config, 'test_my_model') == True
        assert should_skip_model(config, 'seeds.raw_data') == True
        assert should_skip_model(config, 'my_model') == False


class TestWarehouseCredits:
    """Test warehouse credits per hour calculation"""
    
    def test_standard_sizes(self):
        """Test credits for standard warehouse sizes"""
        assert get_warehouse_credits_per_hour('X-SMALL') == 1
        assert get_warehouse_credits_per_hour('SMALL') == 2
        assert get_warehouse_credits_per_hour('MEDIUM') == 4
        assert get_warehouse_credits_per_hour('LARGE') == 8
        assert get_warehouse_credits_per_hour('X-LARGE') == 16
    
    def test_case_insensitive(self):
        """Test size matching is case insensitive"""
        assert get_warehouse_credits_per_hour('medium') == 4
        assert get_warehouse_credits_per_hour('MeDiUm') == 4
    
    def test_unknown_size_default(self):
        """Test default value for unknown sizes"""
        assert get_warehouse_credits_per_hour('UNKNOWN') == 2  # Defaults to SMALL


if __name__ == "__main__":
    pytest.main([__file__, "-v"])


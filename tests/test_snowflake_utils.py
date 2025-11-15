"""
Tests for Snowflake utilities module
"""
import pytest
from unittest.mock import Mock, patch, MagicMock
from dbt_cost_guard.snowflake_utils import SnowflakeUtils


class TestSnowflakeConnection:
    """Test Snowflake connection management"""
    
    @patch('snowflake.connector.connect')
    def test_connect(self, mock_connect):
        """Test connection establishment"""
        mock_conn = Mock()
        mock_connect.return_value = mock_conn
        
        params = {
            'account': 'test_account',
            'user': 'test_user',
            'password': 'test_pass',
        }
        
        utils = SnowflakeUtils(params)
        utils.connect()
        
        mock_connect.assert_called_once_with(**params)
        assert utils.conn == mock_conn
    
    @patch('snowflake.connector.connect')
    def test_context_manager(self, mock_connect):
        """Test using SnowflakeUtils as context manager"""
        mock_conn = Mock()
        mock_connect.return_value = mock_conn
        
        params = {'account': 'test', 'user': 'user', 'password': 'pass'}
        
        with SnowflakeUtils(params) as utils:
            assert utils.conn == mock_conn
        
        # Connection should be closed after exiting context
        mock_conn.close.assert_called_once()


class TestExplainPlan:
    """Test EXPLAIN plan parsing"""
    
    @patch('snowflake.connector.connect')
    def test_explain_plan_parsing(self, mock_connect):
        """Test parsing of EXPLAIN plan output"""
        mock_cursor = Mock()
        mock_cursor.fetchall.return_value = [
            ('TableScan on TABLE1 (100 MB)  ',),
            ('Partition pruning: enabled',),
            ('Estimated 1000 partitions scanned',),
        ]
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        params = {'account': 'test', 'user': 'user', 'password': 'pass'}
        utils = SnowflakeUtils(params)
        
        result = utils.get_explain_plan("SELECT * FROM table1")
        
        assert result is not None
        assert 'has_partition_pruning' in result
        assert result['has_partition_pruning'] == True
    
    @patch('snowflake.connector.connect')
    def test_explain_plan_failure(self, mock_connect):
        """Test graceful handling of EXPLAIN failures"""
        mock_cursor = Mock()
        mock_cursor.execute.side_effect = Exception("EXPLAIN failed")
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        params = {'account': 'test', 'user': 'user', 'password': 'pass'}
        utils = SnowflakeUtils(params)
        
        result = utils.get_explain_plan("SELECT * FROM table1")
        
        # Should return None on failure, not raise exception
        assert result is None


class TestHistoricalQueries:
    """Test historical query data retrieval"""
    
    @patch('snowflake.connector.connect')
    def test_get_model_history(self, mock_connect):
        """Test retrieving historical query data"""
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (
            45.5,   # avg_time
            1024000,  # avg_bytes
            40.0,   # median_time
            10,     # run_count
            120.0,  # max_time
            15.0,   # min_time
        )
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        params = {'account': 'test', 'user': 'user', 'password': 'pass'}
        utils = SnowflakeUtils(params)
        
        result = utils.get_model_history("my_model", days=30)
        
        assert result is not None
        assert result['run_count'] == 10
        assert result['median_time'] == 40.0
    
    @patch('snowflake.connector.connect')
    def test_no_history_available(self, mock_connect):
        """Test when no historical data exists"""
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (None, None, None, 0, None, None)
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        params = {'account': 'test', 'user': 'user', 'password': 'pass'}
        utils = SnowflakeUtils(params)
        
        result = utils.get_model_history("my_model", days=30)
        
        # Should return None when run_count is 0
        assert result is None


class TestCacheProbability:
    """Test cache probability checking"""
    
    @patch('snowflake.connector.connect')
    def test_high_cache_probability(self, mock_connect):
        """Test query with many recent executions"""
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (5,)  # 5 cache hits
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        params = {'account': 'test', 'user': 'user', 'password': 'pass'}
        utils = SnowflakeUtils(params)
        
        probability = utils.check_cache_probability("SELECT * FROM table1")
        
        assert probability == 0.9  # 3+ hits = 0.9 probability
    
    @patch('snowflake.connector.connect')
    def test_no_cache_hits(self, mock_connect):
        """Test query with no recent executions"""
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (0,)  # 0 cache hits
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        params = {'account': 'test', 'user': 'user', 'password': 'pass'}
        utils = SnowflakeUtils(params)
        
        probability = utils.check_cache_probability("SELECT * FROM table1")
        
        assert probability == 0.0  # No hits = 0.0 probability


class TestTableStatistics:
    """Test table statistics retrieval"""
    
    @patch('snowflake.connector.connect')
    def test_get_table_stats(self, mock_connect):
        """Test retrieving table row counts and sizes"""
        mock_cursor = Mock()
        mock_cursor.fetchone.return_value = (10000, 1024000)  # rows, bytes
        
        mock_conn = Mock()
        mock_conn.cursor.return_value = mock_cursor
        mock_connect.return_value = mock_conn
        
        params = {'account': 'test', 'user': 'user', 'password': 'pass'}
        utils = SnowflakeUtils(params)
        
        table_refs = [('DB', 'SCHEMA', 'TABLE1')]
        stats = utils.get_table_statistics(table_refs)
        
        assert 'DB.SCHEMA.TABLE1' in stats
        assert stats['DB.SCHEMA.TABLE1']['row_count'] == 10000
        assert stats['DB.SCHEMA.TABLE1']['bytes'] == 1024000


if __name__ == "__main__":
    pytest.main([__file__, "-v"])


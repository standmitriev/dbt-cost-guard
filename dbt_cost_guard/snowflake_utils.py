"""
Snowflake utilities for cost estimation
"""

import re
import logging
from typing import Dict, List, Optional, Tuple, Any
import snowflake.connector
from pathlib import Path

logger = logging.getLogger(__name__)


class SnowflakeUtils:
    """Utilities for interacting with Snowflake and estimating query costs"""

    def __init__(self, connection_params: Dict[str, str]):
        """
        Initialize Snowflake utilities

        Args:
            connection_params: Snowflake connection parameters
        """
        self.connection_params = connection_params
        self.conn = None

    def connect(self) -> None:
        """Establish connection to Snowflake"""
        if self.conn is None:
            self.conn = snowflake.connector.connect(**self.connection_params)

    def close(self) -> None:
        """Close Snowflake connection"""
        if self.conn:
            self.conn.close()
            self.conn = None

    def __enter__(self):
        """Context manager entry"""
        self.connect()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.close()

    def get_current_warehouse_size(self, warehouse_name: str) -> str:
        """
        Get the size of the current warehouse

        Args:
            warehouse_name: Name of the warehouse

        Returns:
            Warehouse size (e.g., 'SMALL', 'MEDIUM')
        """
        self.connect()
        cursor = self.conn.cursor()

        try:
            query = f"SHOW WAREHOUSES LIKE '{warehouse_name}'"
            cursor.execute(query)
            result = cursor.fetchone()

            if result:
                # The size is typically in the 3rd or 4th column
                # Format: name, state, type, size, ...
                return result[3] if len(result) > 3 else "MEDIUM"

            return "MEDIUM"  # Default
        except Exception as e:
            print(f"Warning: Could not get warehouse size: {e}")
            return "MEDIUM"
        finally:
            cursor.close()

    def find_similar_queries(
        self, sql: str, limit: int = 10, days_back: int = 30
    ) -> List[Dict[str, any]]:
        """
        Find similar historical queries from query history

        Args:
            sql: SQL query to find similar queries for
            limit: Maximum number of results
            days_back: How many days back to search

        Returns:
            List of similar queries with execution metadata
        """
        self.connect()
        cursor = self.conn.cursor()

        # Extract table names from SQL for similarity matching
        tables = self._extract_table_names(sql)

        if not tables:
            return []

        try:
            # Build query to find similar queries
            # We look for queries that reference similar tables
            table_conditions = " OR ".join(
                [f"QUERY_TEXT ILIKE '%{table}%'" for table in tables[:5]]
            )

            query = f"""
            SELECT
                QUERY_ID,
                QUERY_TEXT,
                TOTAL_ELAPSED_TIME / 1000 as EXECUTION_TIME_SECONDS,
                BYTES_SCANNED,
                ROWS_PRODUCED,
                WAREHOUSE_SIZE
            FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
            WHERE
                START_TIME >= DATEADD(day, -{days_back}, CURRENT_TIMESTAMP())
                AND EXECUTION_STATUS = 'SUCCESS'
                AND ({table_conditions})
                AND QUERY_TYPE IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'CREATE_TABLE_AS_SELECT', 'MERGE')
            ORDER BY START_TIME DESC
            LIMIT {limit}
            """

            cursor.execute(query)
            results = cursor.fetchall()

            similar_queries = []
            for row in results:
                similar_queries.append(
                    {
                        "query_id": row[0],
                        "query_text": row[1],
                        "execution_time_seconds": row[2],
                        "bytes_scanned": row[3] or 0,
                        "rows_produced": row[4] or 0,
                        "warehouse_size": row[5],
                    }
                )

            return similar_queries
        except Exception as e:
            # If we can't access query history (permissions, etc), return empty
            print(f"Warning: Could not query history: {e}")
            return []
        finally:
            cursor.close()

    def get_explain_plan(self, sql: str) -> Optional[Dict[str, Any]]:
        """
        Execute EXPLAIN and parse the results for cost estimation

        Args:
            sql: SQL query to explain

        Returns:
            Dictionary with parsed EXPLAIN data or None if failed
        """
        self.connect()
        cursor = self.conn.cursor()

        try:
            # Execute EXPLAIN USING TEXT
            explain_query = f"EXPLAIN USING TEXT {sql}"
            cursor.execute(explain_query)
            explain_output = cursor.fetchall()

            if not explain_output:
                return None

            # Parse the text output
            parsed_data = {
                "bytes_scanned_estimate": 0,
                "partitions_scanned": 0,
                "has_partition_pruning": False,
                "operation_costs": [],
                "has_full_scan": False,
            }

            for row in explain_output:
                line = str(row[0]) if row else ""
                line_upper = line.upper()

                # Look for bytes scanned indicators
                if "BYTES" in line_upper or "SIZE" in line_upper:
                    # Try to extract numeric values
                    numbers = re.findall(r"(\d+\.?\d*)\s*(?:MB|GB|KB|BYTES)", line_upper)
                    for num_str in numbers:
                        try:
                            num = float(num_str)
                            # Convert to bytes
                            if "GB" in line_upper:
                                parsed_data["bytes_scanned_estimate"] += int(
                                    num * 1024 * 1024 * 1024
                                )
                            elif "MB" in line_upper:
                                parsed_data["bytes_scanned_estimate"] += int(num * 1024 * 1024)
                            elif "KB" in line_upper:
                                parsed_data["bytes_scanned_estimate"] += int(num * 1024)
                        except:
                            pass

                # Check for partition pruning
                if "PARTITION" in line_upper and "PRUNE" in line_upper:
                    parsed_data["has_partition_pruning"] = True

                # Check for full table scans
                if "TABLE SCAN" in line_upper or "FULL SCAN" in line_upper:
                    parsed_data["has_full_scan"] = True

                # Count partitions
                if "PARTITIONS" in line_upper:
                    numbers = re.findall(r"(\d+)\s*PARTITIONS", line_upper)
                    for num_str in numbers:
                        try:
                            parsed_data["partitions_scanned"] += int(num_str)
                        except:
                            pass

            logger.debug(f"EXPLAIN plan parsed: {parsed_data}")
            return parsed_data

        except Exception as e:
            logger.debug(f"Could not get EXPLAIN plan: {e}")
            return None
        finally:
            cursor.close()

    def get_model_history(self, model_name: str, days: int = 30) -> Optional[Dict[str, Any]]:
        """
        Query QUERY_HISTORY for actual execution stats for a specific model

        Args:
            model_name: Name of the dbt model
            days: How many days of history to query

        Returns:
            Dictionary with historical execution stats or None
        """
        self.connect()
        cursor = self.conn.cursor()

        try:
            query = f"""
            SELECT 
                AVG(TOTAL_ELAPSED_TIME / 1000) as avg_time,
                AVG(BYTES_SCANNED) as avg_bytes,
                MEDIAN(TOTAL_ELAPSED_TIME / 1000) as median_time,
                COUNT(*) as run_count,
                MAX(TOTAL_ELAPSED_TIME / 1000) as max_time,
                MIN(TOTAL_ELAPSED_TIME / 1000) as min_time
            FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
            WHERE QUERY_TEXT ILIKE '%{model_name}%'
            AND EXECUTION_STATUS = 'SUCCESS'
            AND START_TIME >= DATEADD(day, -{days}, CURRENT_TIMESTAMP())
            AND QUERY_TYPE IN ('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'CREATE_TABLE_AS_SELECT', 'MERGE')
            """

            cursor.execute(query)
            result = cursor.fetchone()

            if result and result[3] > 0:  # run_count > 0
                return {
                    "avg_time": result[0] or 0,
                    "avg_bytes": result[1] or 0,
                    "median_time": result[2] or 0,
                    "run_count": result[3] or 0,
                    "max_time": result[4] or 0,
                    "min_time": result[5] or 0,
                }

            return None

        except Exception as e:
            logger.debug(f"Could not get model history: {e}")
            return None
        finally:
            cursor.close()

    def check_cache_probability(self, sql: str) -> float:
        """
        Check if query is likely to hit Snowflake's result cache (24hr window)

        Args:
            sql: SQL query text

        Returns:
            Probability between 0.0 and 1.0
        """
        self.connect()
        cursor = self.conn.cursor()

        try:
            # Normalize SQL for comparison (remove whitespace variations)
            normalized_sql = " ".join(sql.split())

            query = """
            SELECT COUNT(*) as cache_hits
            FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
            WHERE QUERY_TEXT = %s
            AND START_TIME >= DATEADD(hour, -24, CURRENT_TIMESTAMP())
            AND EXECUTION_STATUS = 'SUCCESS'
            """

            cursor.execute(query, (normalized_sql,))
            result = cursor.fetchone()

            if result and result[0]:
                cache_hits = result[0]
                # If query ran recently, high probability of cache hit
                if cache_hits >= 3:
                    return 0.9
                elif cache_hits >= 2:
                    return 0.7
                elif cache_hits >= 1:
                    return 0.5

            return 0.0

        except Exception as e:
            logger.debug(f"Could not check cache probability: {e}")
            return 0.0
        finally:
            cursor.close()

    def get_table_statistics(self, table_refs: List[Tuple[str, str, str]]) -> Dict[str, Dict]:
        """
        Get statistics for tables referenced in query

        Args:
            table_refs: List of (database, schema, table) tuples

        Returns:
            Dictionary mapping table names to statistics
        """
        self.connect()
        cursor = self.conn.cursor()

        stats = {}

        for database, schema, table in table_refs:
            try:
                # Query information schema for table stats
                query = f"""
                SELECT
                    ROW_COUNT,
                    BYTES
                FROM {database}.INFORMATION_SCHEMA.TABLES
                WHERE TABLE_SCHEMA = '{schema}'
                AND TABLE_NAME = '{table}'
                """

                cursor.execute(query)
                result = cursor.fetchone()

                if result:
                    full_table_name = f"{database}.{schema}.{table}"
                    stats[full_table_name] = {
                        "row_count": result[0] or 0,
                        "bytes": result[1] or 0,
                    }
            except Exception as e:
                # Skip tables we can't access
                pass

        cursor.close()
        return stats

    def _extract_table_names(self, sql: str) -> List[str]:
        """
        Extract table names from SQL query

        Args:
            sql: SQL query text

        Returns:
            List of table names
        """
        # Simple regex-based extraction (not perfect but good enough)
        # Matches patterns like: FROM table, JOIN table, INTO table
        sql_upper = sql.upper()

        # Remove comments
        sql_upper = re.sub(r"--.*$", "", sql_upper, flags=re.MULTILINE)
        sql_upper = re.sub(r"/\*.*?\*/", "", sql_upper, flags=re.DOTALL)

        tables = []

        # Match FROM/JOIN clauses
        from_pattern = r"(?:FROM|JOIN)\s+([a-zA-Z0-9_]+(?:\.[a-zA-Z0-9_]+)*)"
        matches = re.findall(from_pattern, sql_upper)
        tables.extend(matches)

        # Match INTO clauses
        into_pattern = r"INTO\s+([a-zA-Z0-9_]+(?:\.[a-zA-Z0-9_]+)*)"
        matches = re.findall(into_pattern, sql_upper)
        tables.extend(matches)

        # Clean up and deduplicate
        tables = list(set([t.strip() for t in tables if t.strip()]))

        return tables

    @staticmethod
    def parse_table_reference(
        table_ref: str, default_database: str, default_schema: str
    ) -> Tuple[str, str, str]:
        """
        Parse a table reference into database, schema, table components

        Args:
            table_ref: Table reference (may be qualified or unqualified)
            default_database: Default database name
            default_schema: Default schema name

        Returns:
            Tuple of (database, schema, table)
        """
        parts = table_ref.split(".")

        if len(parts) == 3:
            return parts[0], parts[1], parts[2]
        elif len(parts) == 2:
            return default_database, parts[0], parts[1]
        else:
            return default_database, default_schema, parts[0]

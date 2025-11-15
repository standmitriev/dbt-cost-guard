# Contributing to dbt-cost-guard

Thank you for your interest in contributing to dbt-cost-guard! This document provides guidelines and instructions for contributing.

## Code of Conduct

Be respectful, inclusive, and collaborative. We're all here to make cost estimation better for the dbt community.

## How to Contribute

### Reporting Bugs

Before creating a bug report:
1. Check the [existing issues](https://github.com/yourusername/dbt-cost-guard/issues)
2. Try with the latest version
3. Enable verbose logging (`--verbose`) to gather details

When reporting bugs, include:
- dbt version (`dbt --version`)
- dbt-cost-guard version (`pip show dbt-cost-guard`)
- Snowflake warehouse size
- Error message and stack trace
- Steps to reproduce
- Expected vs. actual behavior

### Suggesting Enhancements

We welcome feature requests! Please include:
- Clear description of the feature
- Use case / why it's valuable
- Example usage (if applicable)
- Willingness to contribute the implementation

### Pull Requests

1. **Fork the repository** and create your branch from `main`

```bash
git clone https://github.com/yourusername/dbt-cost-guard.git
cd dbt-cost-guard
git checkout -b feature/your-feature-name
```

2. **Set up development environment**

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install in development mode with dev dependencies
pip install -e ".[dev]"
```

3. **Make your changes**

Follow the code style guidelines below.

4. **Add tests**

```bash
# Run existing tests
pytest tests/

# Add tests for your changes
# Tests should go in tests/ directory
```

5. **Update documentation**

- Update README.md if adding features
- Add docstrings to new functions
- Update IMPROVEMENTS.md if relevant

6. **Commit your changes**

```bash
git add .
git commit -m "feat: add EXPLAIN plan caching"
```

Use conventional commit messages:
- `feat:` new feature
- `fix:` bug fix
- `docs:` documentation changes
- `test:` adding tests
- `refactor:` code refactoring
- `perf:` performance improvements

7. **Push and create PR**

```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub.

## Development Guidelines

### Code Style

- Follow PEP 8 style guide
- Use Black for code formatting: `black .`
- Use type hints for function parameters and return values
- Maximum line length: 100 characters

```python
def estimate_cost(sql: str, complexity: int) -> float:
    """
    Estimate query cost based on SQL and complexity.
    
    Args:
        sql: SQL query text
        complexity: Complexity score (0-100)
        
    Returns:
        Estimated cost in dollars
    """
    # Implementation
    return cost
```

### Project Structure

```
dbt-cost-guard/
├── dbt_cost_guard/          # Main package
│   ├── __init__.py
│   ├── cli.py               # CLI interface
│   ├── estimator.py         # Cost estimation logic
│   ├── snowflake_utils.py   # Snowflake integration
│   └── config.py            # Configuration management
├── tests/                   # Test suite
│   ├── test_estimator.py
│   ├── test_snowflake_utils.py
│   └── test_config.py
├── example_project/         # Example dbt project
├── docs/                    # Documentation
├── pyproject.toml          # Package configuration
└── README.md
```

### Adding New Features

When adding new features:

1. **Update estimator.py** for estimation logic
2. **Update snowflake_utils.py** for Snowflake interactions
3. **Update config.py** for new configuration options
4. **Update CLI** if exposing new commands/flags
5. **Add tests** in tests/ directory
6. **Update documentation**
7. **Add example usage** in REAL_WORLD_USAGE.md

### Testing

We use pytest for testing:

```bash
# Run all tests
pytest tests/

# Run specific test file
pytest tests/test_estimator.py

# Run with coverage
pytest --cov=dbt_cost_guard tests/

# Run with verbose output
pytest -v tests/
```

Test guidelines:
- Write unit tests for all new functions
- Mock Snowflake connections
- Test error handling and edge cases
- Aim for >80% code coverage

Example test:

```python
def test_calculate_complexity_score():
    estimator = CostEstimator(project_dir, profiles_dir, config)
    
    sql = "SELECT * FROM table JOIN other ON id"
    score = estimator._calculate_complexity_score(sql)
    
    assert score > 10  # Has JOIN
    assert score < 50  # Not too complex
```

### Logging

Use Python's logging module:

```python
import logging

logger = logging.getLogger(__name__)

logger.debug("Detailed info for debugging")
logger.info("General information")
logger.warning("Warning message")
logger.error("Error message")
```

Never use `print()` statements in production code. Use `logger.debug()` instead, which users can enable with `--verbose`.

### Error Handling

Always provide graceful fallbacks:

```python
try:
    result = expensive_operation()
except SpecificException as e:
    logger.warning(f"Operation failed: {e}, using fallback")
    result = fallback_operation()
```

### Documentation

- All functions must have docstrings
- Use Google-style docstrings
- Include type hints
- Document exceptions that can be raised

```python
def get_explain_plan(self, sql: str) -> Optional[Dict[str, Any]]:
    """
    Execute EXPLAIN and parse results.
    
    Args:
        sql: SQL query to explain
        
    Returns:
        Parsed EXPLAIN data, or None if failed
        
    Raises:
        SnowflakeError: If connection fails
    """
    pass
```

## Development Workflow

### Local Testing

1. Make changes to code
2. Run tests: `pytest tests/`
3. Test with example project:
```bash
dbt-cost-guard --project-dir example_project estimate
```
4. Test verbose mode:
```bash
dbt-cost-guard --verbose --project-dir example_project estimate
```

### Release Process

(For maintainers)

1. Update version in `pyproject.toml`
2. Update CHANGELOG.md
3. Create git tag: `git tag v0.2.0`
4. Push tag: `git push origin v0.2.0`
5. GitHub Actions will automatically publish to PyPI

## Areas for Contribution

Looking for ways to contribute? Here are high-impact areas:

### High Priority
- Improve EXPLAIN plan parsing accuracy
- Add support for other data warehouses (BigQuery, Redshift)
- Better incremental model detection
- Integration with dbt Cloud API
- Performance optimizations

### Medium Priority
- More comprehensive tests
- Better error messages
- Configuration UI/wizard
- Cost forecasting (predict future costs)
- Anomaly detection (unusual cost spikes)

### Documentation
- More real-world examples
- Video tutorials
- Blog posts about usage
- Translation to other languages

### Testing
- Integration tests with real Snowflake
- Performance benchmarks
- Accuracy measurements

## Questions?

- Open a GitHub discussion
- Comment on related issues
- Reach out to maintainers

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- GitHub contributors page

Thank you for helping make dbt-cost-guard better! 🚀


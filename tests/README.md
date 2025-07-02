# PDS Web Analytics Testing

This directory contains tests for the PDS Web Analytics project, including both unit tests and integration tests, all using the unittest framework.

## Test Structure

### Unit Tests (unittest)
- **`test_s3_sync.py`**: Tests for S3 synchronization functionality
- **`conftest.py`**: Helper functions and utilities for testing

### Integration Tests (unittest)
- **`test_logstash_integration.py`**: End-to-end tests for Logstash pipeline processing
  - Replaces the functionality of the old `run_tests.sh` script
  - Tests Logstash configurations with various input formats
  - Validates output file counts and contents
  - Provides better error handling and cross-platform compatibility
  - Uses unittest framework for better standard library integration

### Test Configuration Files
- **`config/test-input-https.conf`**: Test configuration for HTTPS logs
- **`config/test-input-ftp.conf`**: Test configuration for FTP logs
- **`config/test-input-logs.conf`**: Test configuration for all log files in test/data/logs
- **`config/test-output.conf`**: Test output configuration

## Running Tests

### Running Tests Directly

#### Unit Tests
```bash
# Run all unit tests
python -m unittest tests.test_s3_sync

# Run specific test class
python -m unittest tests.test_s3_sync.TestS3Sync

# Run specific test method
python -m unittest tests.test_s3_sync.TestS3Sync.test_init_with_gzip_enabled

# Run with verbose output
python -m unittest tests.test_s3_sync -v
```

#### Integration Tests
```bash
# Run all integration tests
python -m unittest tests.test_logstash_integration

# Run specific test method
python -m unittest tests.test_logstash_integration.TestLogstashIntegration.test_https_log_processing

# Run with verbose output
python -m unittest tests.test_logstash_integration -v
```

#### All Tests
```bash
# Run all tests in the tests directory
python -m unittest discover tests

# Run with verbose output
python -m unittest discover tests -v
```

## Test Framework Choice

### Why unittest?
- **Standard Library**: No additional dependencies required
- **Process Management**: Better handling of subprocess execution
- **Error Handling**: More explicit error handling for external tools
- **Cross-Platform**: Better compatibility across different operating systems
- **Consistency**: All tests use the same framework
- **Simplicity**: Easier to understand and maintain

## Test Data

The `data/logs/` directory contains sample log files for testing:
- Apache HTTP access logs
- FTP transfer logs
- Various PDS node log formats

## Prerequisites

### For All Tests
- Python 3.9+
- No additional Python dependencies required

### For Integration Tests
- Logstash (must be in PATH)

## Configuration

Integration tests use configuration files in the `config/` directory:
- Input configurations specify log sources
- Output configurations specify where processed data should be written
- Filter configurations define data processing rules

## Helper Functions

The `conftest.py` module provides helper functions for testing:

```python
from tests.conftest import (
    create_test_data_dir,
    cleanup_test_data_dir,
    create_sample_log_files,
    get_sample_config,
    create_temp_config_file,
    cleanup_temp_config_file,
    MockAWSCredentials,
    MockSubprocess,
    TestDataManager
)

# Example usage in a test class
class TestExample(unittest.TestCase):
    def setUp(self):
        self.test_data_dir = create_test_data_dir()
        self.config_file = create_temp_config_file()

    def tearDown(self):
        cleanup_test_data_dir(self.test_data_dir)
        cleanup_temp_config_file(self.config_file)

    def test_with_mocked_aws(self):
        with MockAWSCredentials():
            # Test code here
            pass

    def test_with_mocked_subprocess(self):
        with MockSubprocess(stdout="success", returncode=0) as mock_run:
            # Test code here
            pass
```

## Troubleshooting

### Common Issues

1. **Logstash not found**: Ensure Logstash is installed and in your PATH
2. **Permission errors**: Check file permissions for test data and output directories
3. **Timeout errors**: Integration tests have a 5-minute timeout; increase if needed
4. **Missing dependencies**: Install required packages with `pip install -e .`

### Debug Mode

Run tests with verbose output to see detailed execution:
```bash
./run_unit_tests.sh -v
```

### Manual Testing

To manually test Logstash configurations:
```bash
# Test HTTPS logs
logstash -f tests/config/test-input-https.conf tests/config/shared/pds-filter.conf tests/config/test-output.conf

# Test FTP logs
logstash -f tests/config/test-input-ftp.conf tests/config/shared/pds-filter.conf tests/config/test-output.conf
```

## Contributing

When adding new tests:
1. Use unittest framework for all tests
2. Inherit from `unittest.TestCase`
3. Use `setUp()` and `tearDown()` methods for test setup/cleanup
4. Use unittest assertion methods (`self.assertEqual()`, `self.assertTrue()`, etc.)
5. Add appropriate test data to `data/logs/` if needed
6. Update this README with any new test procedures
7. Use helper functions from `conftest.py` for common testing tasks

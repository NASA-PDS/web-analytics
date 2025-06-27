"""Pytest configuration and common fixtures."""

import pytest
import tempfile
import os
import shutil
import yaml
from unittest.mock import patch


@pytest.fixture(scope="session")
def test_data_dir():
    """Create a test data directory for the test session."""
    temp_dir = tempfile.mkdtemp(prefix="pds_web_analytics_test_")
    yield temp_dir
    shutil.rmtree(temp_dir, ignore_errors=True)


@pytest.fixture
def sample_log_files(test_data_dir):
    """Create sample log files for testing."""
    log_dir = os.path.join(test_data_dir, "sample_logs")
    os.makedirs(log_dir, exist_ok=True)
    
    # Create sample log files with different formats
    log_files = {
        "apache_access.log": [
            '192.168.1.1 - - [25/Dec/2023:10:30:45 +0000] "GET /data/file.txt HTTP/1.1" 200 1024',
            '192.168.1.2 - - [25/Dec/2023:10:31:45 +0000] "POST /api/data HTTP/1.1" 404 0',
            '192.168.1.3 - - [25/Dec/2023:10:32:45 +0000] "GET /search?q=mars HTTP/1.1" 200 2048'
        ],
        "iis_access.log": [
            '2023-12-25 10:30:45 192.168.1.1 GET /data/file.txt 200 1024',
            '2023-12-25 10:31:45 192.168.1.2 POST /api/data 404 0',
            '2023-12-25 10:32:45 192.168.1.3 GET /search 200 2048'
        ],
        "ftp_transfer.log": [
            '192.168.1.1 [25/Dec/2023:10:30:45] "GET /ftp/data.zip" 200 1024',
            '192.168.1.2 [25/Dec/2023:10:31:45] "PUT /ftp/upload.txt" 226 512',
            '192.168.1.3 [25/Dec/2023:10:32:45] "GET /ftp/image.jpg" 200 4096'
        ]
    }
    
    for filename, lines in log_files.items():
        filepath = os.path.join(log_dir, filename)
        with open(filepath, 'w') as f:
            f.write('\n'.join(lines))
    
    return log_dir


@pytest.fixture
def sample_config():
    """Create a sample configuration for testing."""
    return {
        "s3_bucket": "test-pds-logs-bucket",
        "s3_logdir": "logs",
        "subdirs": {
            "atm": {
                "atm-apache-http": {
                    "include": ["*.log"]
                },
                "atm-atmos-ftp": {
                    "include": ["*.log"]
                }
            },
            "en": {
                "en-http": {
                    "include": ["*.txt"]
                }
            },
            "geo": {
                "geo-http": {
                    "include": ["*.log", "*.txt"]
                }
            }
        }
    }


@pytest.fixture
def temp_config_file(sample_config):
    """Create a temporary configuration file."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
        yaml.dump(sample_config, f)
        temp_file = f.name
    
    yield temp_file
    os.unlink(temp_file)


@pytest.fixture
def mock_aws_credentials():
    """Mock AWS credentials for testing."""
    with patch.dict(os.environ, {
        'AWS_ACCESS_KEY_ID': 'test-access-key',
        'AWS_SECRET_ACCESS_KEY': 'test-secret-key',
        'AWS_DEFAULT_REGION': 'us-west-2'
    }):
        yield


@pytest.fixture
def mock_subprocess():
    """Mock subprocess for testing."""
    with patch('subprocess.run') as mock_run:
        # Default successful response
        mock_result = type('MockResult', (), {
            'stdout': 'upload: test.log.gz to s3://bucket/logs/test.log.gz',
            'stderr': '',
            'returncode': 0
        })()
        mock_run.return_value = mock_result
        yield mock_run


@pytest.fixture(autouse=True)
def cleanup_temp_files():
    """Clean up temporary files after each test."""
    yield
    # This fixture runs automatically and cleans up after each test
    # Additional cleanup can be added here if needed 
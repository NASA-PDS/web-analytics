"""Unit tests for the S3Sync class."""

import pytest
import tempfile
import os
import gzip
import shutil
from unittest.mock import Mock, patch, MagicMock, call
from pds.web_analytics.s3_sync import S3Sync


@pytest.mark.unit
class TestS3Sync:
    """Test cases for the S3Sync class."""

    @pytest.fixture
    def temp_dir(self):
        """Create a temporary directory for testing."""
        temp_dir = tempfile.mkdtemp()
        yield temp_dir
        shutil.rmtree(temp_dir, ignore_errors=True)

    @pytest.fixture
    def sample_config(self):
        """Sample configuration for testing."""
        return {
            "/test/logs/atm/atm-apache-http": {"include": ["*.log"]},
            "/test/logs/en/en-http": {"include": ["*.txt"]},
        }

    @pytest.fixture
    def s3_sync(self, sample_config):
        """Create an S3Sync instance for testing."""
        return S3Sync(
            src_paths=sample_config,
            src_logdir="/test/logs",
            bucket_name="test-bucket",
            s3_subdir="logs",
            profile_name="test-profile",
            enable_gzip=True
        )

    def test_init_with_gzip_enabled(self, sample_config):
        """Test S3Sync initialization with gzip enabled."""
        s3_sync = S3Sync(
            src_paths=sample_config,
            src_logdir="/test/logs",
            bucket_name="test-bucket",
            s3_subdir="logs",
            profile_name="test-profile",
            enable_gzip=True
        )
        
        assert s3_sync.enable_gzip is True
        assert s3_sync.bucket_name == "test-bucket"
        assert s3_sync.profile_name == "test-profile"
        assert "--profile" in s3_sync.s3_sync_cmd
        assert "test-profile" in s3_sync.s3_sync_cmd

    def test_init_with_gzip_disabled(self, sample_config):
        """Test S3Sync initialization with gzip disabled."""
        s3_sync = S3Sync(
            src_paths=sample_config,
            src_logdir="/test/logs",
            bucket_name="test-bucket",
            s3_subdir="logs",
            enable_gzip=False
        )
        
        assert s3_sync.enable_gzip is False
        assert "--profile" not in s3_sync.s3_sync_cmd

    def test_init_without_profile(self, sample_config):
        """Test S3Sync initialization without AWS profile."""
        s3_sync = S3Sync(
            src_paths=sample_config,
            src_logdir="/test/logs",
            bucket_name="test-bucket",
            s3_subdir="logs"
        )
        
        assert s3_sync.profile_name is None
        assert "--profile" not in s3_sync.s3_sync_cmd

    @pytest.mark.gzip
    def test_is_gzipped_with_gzipped_file(self, temp_dir):
        """Test is_gzipped method with a gzipped file."""
        # Create a gzipped file
        gzipped_file = os.path.join(temp_dir, "test.gz")
        with gzip.open(gzipped_file, 'wb') as f:
            f.write(b"test content")
        
        s3_sync = S3Sync({}, "/test", "bucket", "logs")
        assert s3_sync.is_gzipped(gzipped_file) is True

    @pytest.mark.gzip
    def test_is_gzipped_with_plain_file(self, temp_dir):
        """Test is_gzipped method with a plain text file."""
        # Create a plain text file
        plain_file = os.path.join(temp_dir, "test.txt")
        with open(plain_file, 'w') as f:
            f.write("test content")
        
        s3_sync = S3Sync({}, "/test", "bucket", "logs")
        assert s3_sync.is_gzipped(plain_file) is False

    @pytest.mark.gzip
    def test_is_gzipped_with_nonexistent_file(self, s3_sync):
        """Test is_gzipped method with a nonexistent file."""
        assert s3_sync.is_gzipped("/nonexistent/file.txt") is False

    @pytest.mark.gzip
    def test_gzip_file_in_place(self, temp_dir):
        """Test gzip_file_in_place method."""
        # Create a test file
        test_file = os.path.join(temp_dir, "test.txt")
        test_content = "This is test content for gzipping"
        with open(test_file, 'w') as f:
            f.write(test_content)
        
        s3_sync = S3Sync({}, "/test", "bucket", "logs")
        gzipped_path = s3_sync.gzip_file_in_place(test_file)
        
        # Check that the original file is removed
        assert not os.path.exists(test_file)
        
        # Check that the gzipped file exists
        assert os.path.exists(gzipped_path)
        assert gzipped_path == test_file + '.gz'
        
        # Check that the gzipped file contains the original content
        with gzip.open(gzipped_path, 'rt') as f:
            content = f.read()
        assert content == test_content

    @pytest.mark.gzip
    def test_ensure_files_are_gzipped_with_mixed_files(self, temp_dir):
        """Test ensure_files_are_gzipped with mixed file types."""
        # Create test directory structure
        test_dir = os.path.join(temp_dir, "test_logs")
        os.makedirs(test_dir)
        
        # Create different types of files
        files = {
            "already_gzipped.gz": b"gzipped content",
            "plain_text.txt": "plain text content",
            "another_log.log": "log content",
            "already_gzipped_content": b"content that looks gzipped"
        }
        
        for filename, content in files.items():
            filepath = os.path.join(test_dir, filename)
            if isinstance(content, bytes):
                with open(filepath, 'wb') as f:
                    f.write(content)
            else:
                with open(filepath, 'w') as f:
                    f.write(content)
        
        # Create a gzipped file with proper magic bytes
        gzipped_file = os.path.join(test_dir, "properly_gzipped.gz")
        with gzip.open(gzipped_file, 'wb') as f:
            f.write(b"properly gzipped content")
        
        s3_sync = S3Sync({}, "/test", "bucket", "logs", enable_gzip=True)
        
        with patch('builtins.print') as mock_print:
            s3_sync.ensure_files_are_gzipped(test_dir)
        
        # Check that plain text files were gzipped
        assert not os.path.exists(os.path.join(test_dir, "plain_text.txt"))
        assert os.path.exists(os.path.join(test_dir, "plain_text.txt.gz"))
        
        assert not os.path.exists(os.path.join(test_dir, "another_log.log"))
        assert os.path.exists(os.path.join(test_dir, "another_log.log.gz"))
        
        # Check that already gzipped files were not re-gzipped
        assert os.path.exists(os.path.join(test_dir, "already_gzipped.gz"))
        assert os.path.exists(os.path.join(test_dir, "properly_gzipped.gz"))

    @pytest.mark.gzip
    def test_ensure_files_are_gzipped_disabled(self, temp_dir):
        """Test ensure_files_are_gzipped when gzip is disabled."""
        test_dir = os.path.join(temp_dir, "test_logs")
        os.makedirs(test_dir)
        
        # Create a test file
        test_file = os.path.join(test_dir, "test.txt")
        with open(test_file, 'w') as f:
            f.write("test content")
        
        s3_sync = S3Sync({}, "/test", "bucket", "logs", enable_gzip=False)
        
        with patch('builtins.print') as mock_print:
            s3_sync.ensure_files_are_gzipped(test_dir)
        
        # Check that the file was not gzipped
        assert os.path.exists(test_file)
        assert not os.path.exists(test_file + '.gz')
        
        # Check that the correct message was printed
        mock_print.assert_called_with(
            "Gzip compression disabled, skipping compression for: " + test_dir
        )

    def test_convert_size(self):
        """Test convert_size static method."""
        assert S3Sync.convert_size(0) == "0B"
        assert S3Sync.convert_size(1024) == "1.0KB"
        assert S3Sync.convert_size(1024 * 1024) == "1.0MB"
        assert S3Sync.convert_size(1024 * 1024 * 1024) == "1.0GB"

    def test_get_bytes(self):
        """Test get_bytes static method."""
        assert S3Sync.get_bytes(1, "KiB") == 1024
        assert S3Sync.get_bytes(1, "MiB") == 1024 * 1024
        assert S3Sync.get_bytes(1, "GiB") == 1024 * 1024 * 1024
        assert S3Sync.get_bytes(1, "TiB") == 1024 * 1024 * 1024 * 1024

    def test_get_throughput(self):
        """Test get_throughput static method."""
        # Test with 1MB sent in 1 second
        with patch('pds.web_analytics.s3_sync.time.monotonic') as mock_time:
            mock_time.return_value = 1.0  # Mock current time to be 1 second after start
            throughput = S3Sync.get_throughput(1024 * 1024, 0)
            assert "1.00 MB/s" in throughput

    @pytest.mark.s3
    @patch('subprocess.run')
    def test_sync_directory_success(self, mock_run, s3_sync):
        """Test successful sync_directory execution."""
        # Mock successful subprocess run
        mock_result = Mock()
        mock_result.stdout = "upload: test.log.gz to s3://bucket/logs/test.log.gz"
        mock_result.stderr = ""
        mock_run.return_value = mock_result
        
        path_tuple = ("/test/logs/atm/atm-apache-http", {"include": ["*.log"]})
        
        with patch.object(s3_sync, 'ensure_files_are_gzipped'):
            with patch('time.monotonic', return_value=0):
                s3_sync.sync_directory(path_tuple)
        
        # Verify subprocess.run was called
        mock_run.assert_called_once()
        call_args = mock_run.call_args[0][0]
        assert "aws" in call_args
        assert "s3" in call_args
        assert "sync" in call_args
        assert "--profile" in call_args
        assert "test-profile" in call_args

    @pytest.mark.s3
    @patch('subprocess.run')
    def test_sync_directory_failure(self, mock_run, s3_sync):
        """Test sync_directory with subprocess failure."""
        # Mock failed subprocess run
        mock_run.side_effect = Exception("AWS CLI error")
        
        path_tuple = ("/test/logs/atm/atm-apache-http", {"include": ["*.log"]})
        
        with patch.object(s3_sync, 'ensure_files_are_gzipped'):
            with patch('builtins.print') as mock_print:
                s3_sync.sync_directory(path_tuple)
        
        # Verify error message was printed
        mock_print.assert_called_with("Unexpected error during sync: AWS CLI error")

    @pytest.mark.s3
    @patch('subprocess.run')
    def test_sync_directory_no_changes(self, mock_run, s3_sync):
        """Test sync_directory when no changes are detected."""
        # Mock subprocess run with no output
        mock_result = Mock()
        mock_result.stdout = ""
        mock_result.stderr = ""
        mock_run.return_value = mock_result
        
        path_tuple = ("/test/logs/atm/atm-apache-http", {"include": ["*.log"]})
        
        with patch.object(s3_sync, 'ensure_files_are_gzipped'):
            with patch('builtins.print') as mock_print:
                s3_sync.sync_directory(path_tuple)
        
        # Verify the correct messages were printed
        # First message: about gzipping
        # Second message: no changes detected
        expected_calls = [
            call("Ensuring files are gzipped in: /test/logs/atm/atm-apache-http"),
            call("/test/logs/atm/atm-apache-http sync to logs/atm/atm-apache-http: no changes detected.")
        ]
        assert mock_print.call_args_list == expected_calls

    def test_sync_directory_with_gzip_disabled(self, sample_config):
        """Test sync_directory when gzip is disabled."""
        s3_sync = S3Sync(
            src_paths=sample_config,
            src_logdir="/test/logs",
            bucket_name="test-bucket",
            s3_subdir="logs",
            enable_gzip=False
        )
        
        path_tuple = ("/test/logs/atm/atm-apache-http", {"include": ["*.log"]})
        
        with patch('builtins.print') as mock_print:
            with patch('subprocess.run') as mock_run:
                # Mock the subprocess result to return empty stdout
                mock_result = Mock()
                mock_result.stdout = ""
                mock_result.stderr = ""
                mock_run.return_value = mock_result
                
                s3_sync.sync_directory(path_tuple)
        
        # Verify the correct messages were printed
        # First message: gzip disabled
        # Second message: sync result (but we're mocking subprocess so no output)
        expected_calls = [
            call("Gzip compression disabled, syncing files as-is: /test/logs/atm/atm-apache-http"),
            call("/test/logs/atm/atm-apache-http sync to logs/atm/atm-apache-http: no changes detected.")
        ]
        assert mock_print.call_args_list == expected_calls

    def test_process_progress(self, s3_sync):
        """Test process_progress method."""
        # Test with a properly formatted progress line
        progress_line = "upload: 1024.0 MiB/2048.0 MiB 50% 2.5 MiB/s"
        
        with patch('builtins.print') as mock_print:
            with patch('pds.web_analytics.s3_sync.time.monotonic', return_value=1.0):  # Mock current time
                s3_sync.process_progress(progress_line, "/test/path", 0)
        
        # Verify print was called with progress information
        mock_print.assert_called_once()
        call_args = mock_print.call_args[0][0]
        assert "/test/path" in call_args
        assert "50%" in call_args
        assert "MB/s" in call_args


@pytest.mark.integration
class TestS3SyncIntegration:
    """Integration tests for S3Sync class."""

    @pytest.fixture
    def temp_log_dir(self):
        """Create a temporary directory with sample log files."""
        temp_dir = tempfile.mkdtemp()
        
        # Create directory structure
        atm_dir = os.path.join(temp_dir, "atm", "atm-apache-http")
        en_dir = os.path.join(temp_dir, "en", "en-http")
        os.makedirs(atm_dir)
        os.makedirs(en_dir)
        
        # Create sample log files
        files = {
            os.path.join(atm_dir, "access.log"): "192.168.1.1 - - [25/Dec/2023:10:30:45 +0000] \"GET /data/file.txt HTTP/1.1\" 200 1024",
            os.path.join(atm_dir, "error.log"): "192.168.1.2 - - [25/Dec/2023:10:31:45 +0000] \"POST /api/data HTTP/1.1\" 404 0",
            os.path.join(en_dir, "search.log"): "192.168.1.3 - - [25/Dec/2023:10:32:45 +0000] \"GET /search?q=mars HTTP/1.1\" 200 2048",
        }
        
        for filepath, content in files.items():
            with open(filepath, 'w') as f:
                f.write(content)
        
        # Create an already gzipped file
        gzipped_file = os.path.join(atm_dir, "old.log.gz")
        with gzip.open(gzipped_file, 'wb') as f:
            f.write(b"old gzipped content")
        
        yield temp_dir
        shutil.rmtree(temp_dir, ignore_errors=True)

    def test_full_sync_process(self, temp_log_dir):
        """Test the complete sync process with real files."""
        config = {
            os.path.join(temp_log_dir, "atm", "atm-apache-http"): {"include": ["*.log"]},
            os.path.join(temp_log_dir, "en", "en-http"): {"include": ["*.log"]},
        }
        
        s3_sync = S3Sync(
            src_paths=config,
            src_logdir=temp_log_dir,
            bucket_name="test-bucket",
            s3_subdir="logs",
            enable_gzip=True
        )
        
        # Run the sync process
        with patch('subprocess.run') as mock_run:
            mock_result = Mock()
            mock_result.stdout = "upload: test.log.gz to s3://bucket/logs/test.log.gz"
            mock_result.stderr = ""
            mock_run.return_value = mock_result
            
            s3_sync.run()
        
        # Verify that files were processed
        atm_dir = os.path.join(temp_log_dir, "atm", "atm-apache-http")
        en_dir = os.path.join(temp_log_dir, "en", "en-http")
        
        # Check that plain log files were gzipped
        assert not os.path.exists(os.path.join(atm_dir, "access.log"))
        assert os.path.exists(os.path.join(atm_dir, "access.log.gz"))
        
        assert not os.path.exists(os.path.join(atm_dir, "error.log"))
        assert os.path.exists(os.path.join(atm_dir, "error.log.gz"))
        
        assert not os.path.exists(os.path.join(en_dir, "search.log"))
        assert os.path.exists(os.path.join(en_dir, "search.log.gz"))
        
        # Check that already gzipped file was not re-gzipped
        assert os.path.exists(os.path.join(atm_dir, "old.log.gz"))

    def test_sync_with_gzip_disabled(self, temp_log_dir):
        """Test sync process with gzip disabled."""
        config = {
            os.path.join(temp_log_dir, "atm", "atm-apache-http"): {"include": ["*.log"]},
        }
        
        s3_sync = S3Sync(
            src_paths=config,
            src_logdir=temp_log_dir,
            bucket_name="test-bucket",
            s3_subdir="logs",
            enable_gzip=False
        )
        
        # Run the sync process
        with patch('subprocess.run') as mock_run:
            mock_result = Mock()
            mock_result.stdout = "upload: test.log to s3://bucket/logs/test.log"
            mock_result.stderr = ""
            mock_run.return_value = mock_result
            
            s3_sync.run()
        
        # Verify that files were not gzipped
        atm_dir = os.path.join(temp_log_dir, "atm", "atm-apache-http")
        assert os.path.exists(os.path.join(atm_dir, "access.log"))
        assert not os.path.exists(os.path.join(atm_dir, "access.log.gz"))
        
        assert os.path.exists(os.path.join(atm_dir, "error.log"))
        assert not os.path.exists(os.path.join(atm_dir, "error.log.gz"))


if __name__ == "__main__":
    pytest.main([__file__]) 
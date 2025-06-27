"""
Integration tests for Logstash pipeline processing.

This module replaces the functionality of run_tests.sh with a Python-based
testing approach that provides better error handling, cross-platform compatibility,
and integration with unittest.
"""

import unittest
import subprocess
import tempfile
import os
import json
import shutil
from pathlib import Path
from typing import Dict, List, Tuple
import time
import uuid


class TestLogstashIntegration(unittest.TestCase):
    """Integration tests for Logstash pipeline processing."""

    # ============================================================================
    # CONFIGURATION: Set which configurations to test here
    # ============================================================================
    ENABLED_CONFIGS = ["https"]  # Options: "https", "ftp"
    
    # Configuration-specific test expectations
    EXPECTED_COUNTS = {
        "https": {
            "parse_failures": 0,
            "bad_logs": 0,
            "invalid_methods": 1,
            "template_errors": 0,
            "empty_user_agents": 2,
            "duplicate_sources": 0,
            "processed_logs": 22,
            "corrupt_logs": 3
        },
        "ftp": {
            "parse_failures": 0,
            "bad_logs": 0,
            "invalid_methods": 0,
            "template_errors": 0,
            "empty_user_agents": 0,
            "duplicate_sources": 0,
            "processed_logs": 16,
            "corrupt_logs": 6
        }
    }

    # Logstash configuration components
    INPUT_CONFIGS = {
        "https": "test-input-https.conf",
        "ftp": "test-input-ftp.conf"
    }
    
    FILTER_CONFIGS = [
        "shared/pds-filter.conf"
    ]
    
    OUTPUT_CONFIGS = [
        "test-output.conf"
    ]

    @classmethod
    def setUpClass(cls):
        """Set up class-level configuration validation."""
        # Validate that all enabled configs exist
        invalid_configs = [config for config in cls.ENABLED_CONFIGS if config not in cls.INPUT_CONFIGS]
        if invalid_configs:
            raise ValueError(f"Invalid enabled configs: {invalid_configs}. Available: {list(cls.INPUT_CONFIGS.keys())}")
        
        # Filter INPUT_CONFIGS to only include enabled ones
        cls.ACTIVE_INPUT_CONFIGS = {k: v for k, v in cls.INPUT_CONFIGS.items() if k in cls.ENABLED_CONFIGS}
        
        print(f"[CONFIG] Testing configurations: {cls.ENABLED_CONFIGS}")
        print(f"[CONFIG] Active input configs: {list(cls.ACTIVE_INPUT_CONFIGS.keys())}")

    def setUp(self):
        """Set up test environment before each test."""
        # Find the repository root (workspace directory) robustly
        current_file = Path(__file__).resolve()
        self.test_dir = current_file.parent
        self.workspace_dir = self.test_dir.parent
        self.ls_settings_dir = self.workspace_dir / "config" / "logstash" / "config"
        self.output_dir = self.workspace_dir / "output"
        self.test_config_dir = self.test_dir / "config"

        # Debug output for troubleshooting path issues
        print(f"[DEBUG] workspace_dir: {self.workspace_dir}")
        print(f"[DEBUG] ls_settings_dir: {self.ls_settings_dir}")
        print(f"[DEBUG] test_config_dir: {self.test_config_dir}")
        
        # Create output directory if it doesn't exist
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        # Clean up old test directories (but be more careful about race conditions)
        if self.output_dir.exists():
            try:
                for item in self.output_dir.iterdir():
                    if item.is_dir() and (item.name.startswith("data_") or item.name.startswith("test_run_")):
                        # Only clean up directories that are clearly from previous test runs
                        try:
                            shutil.rmtree(item, ignore_errors=True)
                        except (FileNotFoundError, OSError):
                            # Ignore errors - another test might be using it
                            pass
            except (FileNotFoundError, OSError):
                # Ignore errors - directory might be in use
                pass

    # def tearDown(self):
    #     """Clean up after each test."""
    #     # Cleanup after tests - handle case where directory might not exist
    #     if self.output_dir.exists():
    #         try:
    #             # Clean up all test run directories
    #             for item in self.output_dir.iterdir():
    #                 if item.is_dir() and item.name.startswith("test_run_"):
    #                     shutil.rmtree(item, ignore_errors=True)
    #                 elif item.is_file():
    #                     item.unlink()
    #         except (FileNotFoundError, OSError):
    #             # Directory might have already been removed or is in use
    #             pass

    def get_input_config_path(self, config_name: str) -> Path:
        """Get the full path to an input configuration file."""
        if config_name not in self.ACTIVE_INPUT_CONFIGS:
            raise ValueError(f"Unknown or disabled input config: {config_name}")
        return self.test_config_dir / self.ACTIVE_INPUT_CONFIGS[config_name]

    def get_filter_config_paths(self) -> List[Path]:
        """Get the full paths to all filter configuration files."""
        return [self.ls_settings_dir / filter_config for filter_config in self.FILTER_CONFIGS]

    def get_output_config_paths(self) -> List[Path]:
        """Get the full paths to all output configuration files."""
        return [self.test_config_dir / output_config for output_config in self.OUTPUT_CONFIGS]

    def get_enabled_configs(self) -> List[Tuple[str, str]]:
        """Get list of (config_name, description) tuples for enabled configurations."""
        descriptions = {
            "https": "HTTPS Log Processing",
            "ftp": "FTP Log Processing"
        }
        return [(config, descriptions.get(config, f"{config} Processing")) for config in self.ENABLED_CONFIGS]

    def build_pipeline_config(self, input_config_name: str) -> str:
        """
        Build a complete Logstash pipeline configuration.
        
        Args:
            input_config_name: Name of the input configuration to use
            
        Returns:
            Complete pipeline configuration as a string
        """
        config_parts = []
        
        # Add input configuration
        input_config_path = self.get_input_config_path(input_config_name)
        if not input_config_path.exists():
            raise FileNotFoundError(f"Input config not found: {input_config_path}")
        
        input_content = input_config_path.read_text()
        
        config_parts.append(input_content)
        
        # Add filter configurations
        for filter_path in self.get_filter_config_paths():
            if not filter_path.exists():
                raise FileNotFoundError(f"Filter config not found: {filter_path}")
            config_parts.append(filter_path.read_text())
        
        # Add output configurations
        for output_path in self.get_output_config_paths():
            if not output_path.exists():
                raise FileNotFoundError(f"Output config not found: {output_path}")
            config_parts.append(output_path.read_text())
        
        return "\n".join(config_parts)

    def kill_existing_logstash_processes(self):
        """Kill any existing Logstash processes to ensure clean state."""
        try:
            # Find and kill any running Logstash processes
            result = subprocess.run(
                ["pkill", "-f", "logstash"],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                print("Killed existing Logstash processes")
            else:
                print("No existing Logstash processes found")

            time.sleep(3)
        except (subprocess.TimeoutExpired, FileNotFoundError):
            # pkill might not be available on all systems, ignore errors
            pass

    def run_logstash_pipeline(self, input_config_name: str, description: str) -> Tuple[bool, Path]:
        """
        Run Logstash with a specific input configuration.
        
        Args:
            input_config_name: Name of the input configuration to use
            description: Description of the test being run
            
        Returns:
            Tuple of (success, output_directory_path)
        """
        print(f"\nRunning Logstash pipeline: {description}")

        # Kill any existing Logstash processes first
        self.kill_existing_logstash_processes()

        # Build the complete pipeline configuration
        try:
            pipeline_config = self.build_pipeline_config(input_config_name)
        except FileNotFoundError as e:
            self.fail(f"Configuration file not found: {e}")

        # Create temporary configuration file
        with tempfile.NamedTemporaryFile(mode='w', suffix='.conf', delete=False) as tmp_conf:
            tmp_conf_path = tmp_conf.name
            tmp_conf.write(pipeline_config)
        
        # Create unique output directory for this test run
        unique_output_dir = self.output_dir /  f"data_{uuid.uuid4().hex}"
        unique_output_dir.mkdir(parents=True, exist_ok=True)
        
        # Create unique data directory for this test run
        unique_data_dir = self.output_dir /  f"data_{uuid.uuid4().hex}"
        unique_data_dir.mkdir(parents=True, exist_ok=True)
        
        try:
            # Set up environment variables for Logstash
            env = os.environ.copy()
            env['LS_SETTINGS_DIR'] = str(self.ls_settings_dir)
            env['OUTPUT_DIR'] = str(unique_output_dir)
            
            # Run Logstash with unique data directory
            cmd = [
                "logstash", 
                "-f", tmp_conf_path, 
                "--log.level=debug",
                "--path.data", str(unique_data_dir)
            ]
            print(f"Running command: {' '.join(cmd)}")
            print(f"LS_SETTINGS_DIR: {env['LS_SETTINGS_DIR']}")
            print(f"OUTPUT_DIR: {env['OUTPUT_DIR']}")
            print(f"DATA_DIR: {unique_data_dir}")
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                cwd=str(self.workspace_dir),
                env=env,
                timeout=300  # 5 minute timeout
            )
            
            # Always show Logstash output for debugging
            print(f"\nLogstash return code: {result.returncode}")
            if result.stdout:
                print(f"Logstash STDOUT:\n{result.stdout}")
            if result.stderr:
                print(f"Logstash STDERR:\n{result.stderr}")
            
            if result.returncode != 0:
                print(f"Logstash failed with return code {result.returncode}")
                return False, unique_output_dir
            
            print(f"Logstash completed successfully")
            
            # Show what files were actually created
            print(f"\nFiles created in output directory {unique_output_dir}:")
            if unique_output_dir.exists():
                for item in unique_output_dir.rglob("*"):
                    if item.is_file():
                        print(f"  {item.relative_to(unique_output_dir)}")
                    elif item.is_dir():
                        print(f"  {item.relative_to(unique_output_dir)}/ (directory)")
            else:
                print("  No output directory found!")
            
            return True, unique_output_dir
            
        except subprocess.TimeoutExpired:
            print("Logstash timed out after 5 minutes")
            return False, unique_output_dir
        except FileNotFoundError:
            self.skipTest("Logstash not found in PATH")
        finally:
            # Clean up temporary config file
            if os.path.exists(tmp_conf_path):
                os.unlink(tmp_conf_path)
            # Clean up temporary data directory
            # if unique_data_dir.exists():
            #     shutil.rmtree(unique_data_dir, ignore_errors=True)
            # Note: Don't clean up unique_output_dir here - let the test use it for validation

    def count_files_in_directory(self, directory: Path) -> int:
        """Count JSON files in a directory and all subdirectories."""
        if not directory.exists():
            return 0
        return len(list(directory.rglob("*.json")))

    def get_directory_contents(self, directory: Path) -> List[str]:
        """Get contents of JSON files in a directory for debugging."""
        if not directory.exists():
            return []
        
        contents = []
        for json_file in directory.glob("*.json"):
            try:
                with open(json_file, 'r') as f:
                    data = json.load(f)
                    contents.append(json.dumps(data, indent=2))
            except json.JSONDecodeError:
                with open(json_file, 'r') as f:
                    contents.append(f"Invalid JSON: {f.read()}")
        
        return contents

    def validate_output_counts(self, output_dir: Path, config_name: str):
        """Validate output counts for a specific configuration."""
        expected_counts = self.EXPECTED_COUNTS[config_name]
        
        print(f"\nValidating output counts for {config_name}:")
        print("=" * 50)
        
        validation_results = []
        
        # Define the directory mappings
        dir_mappings = [
            ("parse-failures", "parse_failures"),
            ("bad-logs", "bad_logs"), 
            ("invalid-methods", "invalid_methods"),
            ("template-errors", "template_errors"),
            ("empty-user-agents", "empty_user_agents"),
            ("duplicate-sources", "duplicate_sources"),
            ("processed-logs", "processed_logs"),
            ("corrupt-logs", "corrupt_logs")
        ]
        
        for dir_name, count_key in dir_mappings:
            directory = output_dir / dir_name
            expected = expected_counts[count_key]
            actual = self.count_files_in_directory(directory)
            
            print(f"{count_key}: {actual} files (expected {expected})")
            
            if actual == expected:
                print(f"  ✅ PASS")
                validation_results.append(True)
            else:
                print(f"  ❌ FAIL")
                validation_results.append(False)
        
        print("=" * 50)
        
        # Show detailed results for debugging if any failed
        if not all(validation_results):
            self._show_detailed_results(output_dir)
        
        # Final assertion
        all_passed = all(validation_results)
        if all_passed:
            print(f"🎉 ALL VALIDATIONS PASSED for {config_name}!")
        else:
            print(f"💥 SOME VALIDATIONS FAILED for {config_name}!")
        
        self.assertTrue(all_passed, f"Output validation failed for {config_name}")

    def _show_detailed_results(self, output_dir: Path):
        """Show detailed results for debugging."""
        print("\nDetailed Results:")
        
        categories = [
            ("parse-failures", "Parse Failures"),
            ("bad-logs", "Bad Logs"),
            ("invalid-methods", "Invalid HTTP Methods"),
            ("template-errors", "Template Errors"),
            ("empty-user-agents", "Empty User Agents"),
            ("duplicate-sources", "Duplicate Source Addresses"),
            ("processed-logs", "Processed Logs"),
            ("corrupt-logs", "Corrupt Logs")
        ]
        
        for dir_name, description in categories:
            directory = output_dir / dir_name
            print(f"\n{description}:")
            
            if directory.exists():
                contents = self.get_directory_contents(directory)
                if contents:
                    print("Found files:")
                    for content in contents[:3]:  # Show first 3 files
                        print(f"  {content[:200]}...")  # Truncate long content
                    if len(contents) > 3:
                        print(f"  ... and {len(contents) - 3} more files")
                else:
                    print("Directory exists but no JSON files found")
            else:
                print("No files found")

    def test_https_log_processing(self):
        """Test processing of HTTPS logs."""
        if "https" not in self.ENABLED_CONFIGS:
            self.skipTest("HTTPS configuration not enabled")
        
        # Run Logstash pipeline
        success, output_dir = self.run_logstash_pipeline("https", "HTTPS Log Processing")
        self.assertTrue(success, "Logstash pipeline failed for HTTPS logs")
        
        # Validate output counts
        self.validate_output_counts(output_dir, "https")

    def test_ftp_log_processing(self):
        """Test processing of FTP logs."""
        if "ftp" not in self.ENABLED_CONFIGS:
            self.skipTest("FTP configuration not enabled")
        
        # Run Logstash pipeline
        success, output_dir = self.run_logstash_pipeline("ftp", "FTP Log Processing")
        self.assertTrue(success, "Logstash pipeline failed for FTP logs")
        
        # Validate output counts
        self.validate_output_counts(output_dir, "ftp")

    def test_individual_configurations(self):
        """Test individual Logstash configurations."""
        test_configs = self.get_enabled_configs()
        
        for config_name, description in test_configs:
            with self.subTest(config_name=config_name):
                # Run Logstash pipeline
                success, output_dir = self.run_logstash_pipeline(config_name, description)
                self.assertTrue(success, f"Logstash pipeline failed for {config_name}")
                
                # Validate output counts
                self.validate_output_counts(output_dir, config_name)

    @unittest.skip("Skipping configuration file existence test")
    def test_configuration_files_exist(self):
        """Test that all required configuration files exist."""
        # Check input configs
        for config_name in self.ACTIVE_INPUT_CONFIGS:
            config_path = self.get_input_config_path(config_name)
            with self.subTest(input_config=config_name):
                self.assertTrue(config_path.exists(), f"Input configuration file missing: {config_path}")
        
        # Check filter configs
        for filter_path in self.get_filter_config_paths():
            with self.subTest(filter_config=str(filter_path)):
                self.assertTrue(filter_path.exists(), f"Filter configuration file missing: {filter_path}")
        
        # Check output configs
        for output_path in self.get_output_config_paths():
            with self.subTest(output_config=str(output_path)):
                self.assertTrue(output_path.exists(), f"Output configuration file missing: {output_path}")

    @unittest.skip("Skipping Logstash version check")
    def test_logstash_available(self):
        """Test that Logstash is available in the system PATH."""
        try:
            result = subprocess.run(
                ["logstash", "--version"],
                capture_output=True,
                text=True,
                timeout=30
            )
            self.assertEqual(result.returncode, 0, "Logstash version check failed")
            print(f"Logstash version: {result.stdout.strip()}")
        except FileNotFoundError:
            self.skipTest("Logstash not found in PATH")
        except subprocess.TimeoutExpired:
            self.fail("Logstash version check timed out")


if __name__ == '__main__':
    # Run the tests
    unittest.main(verbosity=2) 
"""S3 synchronization module for PDS web analytics."""

from typing import Dict, Optional, Tuple
import os
import time
import math
import subprocess
import shutil
import gzip
from multiprocessing import cpu_count
import argparse
import yaml  # type: ignore
import sys
from box import Box


class S3Sync:
    """A class to sync directories from a local filesystem to an AWS S3 bucket.

    Attributes:
        src_paths (Dict[str, Dict[str, str]]): Source paths to sync, with include patterns.
        src_logdir (str): The base directory for source logs.
        bucket_name (str): The name of the target S3 bucket.
        s3_subdir (str): The target directory within the S3 bucket.
        profile_name (Optional[str]): AWS CLI profile name. Default is None.
        delete (bool): Flag to delete source files after sync. Default is False.
        workers (int): Number of worker processes to use. Default is the number of CPUs.
        s3_sync_cmd (List[str]): Base command for AWS S3 sync operations.
        enable_gzip (bool): Flag to enable/disable gzip compression. Default is True.
    """

    def __init__(self, src_paths: Dict[str, Dict[str, str]], src_logdir: str, bucket_name: str,
                 s3_subdir: str, profile_name: Optional[str] = None, delete: bool = False,
                 workers: Optional[int] = None, enable_gzip: bool = True) -> None:
        """Initialize the S3Sync object with configuration for syncing."""
        self.src_paths = src_paths
        self.src_logdir = src_logdir
        self.bucket_name = bucket_name
        self.s3_subdir = s3_subdir
        self.profile_name = profile_name
        self.delete = delete
        self.workers = workers if workers else cpu_count()
        self.enable_gzip = enable_gzip
        self.s3_sync_cmd = ["aws", "s3", "sync"]
        if self.profile_name:
            self.s3_sync_cmd += ["--profile", self.profile_name]
        self.s3_sync_cmd += ["--exclude", "*"]

    def is_gzipped(self, file_path: str) -> bool:
        """Check if a file is already gzipped by examining its magic bytes.

        Args:
            file_path (str): Path to the file to check.

        Returns:
            bool: True if the file is gzipped, False otherwise.
        """
        try:
            with open(file_path, "rb") as f:
                magic_bytes = f.read(2)
                return magic_bytes == b"\x1f\x8b"  # gzip magic bytes
        except OSError:
            return False

    def gzip_file_in_place(self, file_path: str) -> str:
        """Gzip a file in place and return the path to the gzipped version.

        Args:
            file_path (str): Path to the original file.

        Returns:
            str: Path to the gzipped file (same as input with .gz added).
        """
        gzipped_path = file_path + ".gz"

        with open(file_path, "rb") as f_in:
            with gzip.open(gzipped_path, "wb") as f_out:
                shutil.copyfileobj(f_in, f_out)

        # Remove the original file
        os.remove(file_path)

        return gzipped_path

    def ensure_files_are_gzipped(self, src_path: str) -> None:
        """Ensure all files in a directory are gzipped by compressing them in place.

        Args:
            src_path (str): Path to the source directory.
        """
        if not self.enable_gzip:
            print(f"Gzip compression disabled, skipping compression for: {src_path}")
            return

        # Process all files in the source directory
        for root, _dirs, files in os.walk(src_path):
            for file in files:
                file_path = os.path.join(root, file)

                # Skip files that are already gzipped
                if self.is_gzipped(file_path):
                    print(f"File already gzipped: {file_path}")
                    continue

                # Skip files that already have .gz extension
                if file.endswith(".gz"):
                    print(f"File already has .gz extension: {file_path}")
                    continue

                # Gzip the file in place
                try:
                    gzipped_path = self.gzip_file_in_place(file_path)
                    print(f"Gzipped file in place: {file_path} -> {gzipped_path}")
                except Exception as e:
                    print(f"Error gzipping {file_path}: {str(e)}")

    def run(self) -> None:
        """Execute the sync process for all configured source paths."""
        for src_path in self.src_paths.items():
            self.sync_directory(src_path)

    def sync_directory(self, path_tuple: Tuple[str, Dict[str, str]]) -> None:
        """Sync a single directory to S3, including progress logging and deletion if specified.

        Args:
            path_tuple (tuple): A tuple containing the source path and include patterns.
        """
        src_path, path_include = path_tuple

        # Ensure all files are gzipped before sync (if enabled)
        if self.enable_gzip:
            print(f"Ensuring files are gzipped in: {src_path}")
            self.ensure_files_are_gzipped(src_path)
        else:
            print(f"Gzip compression disabled, syncing files as-is: {src_path}")

        s3_path = os.path.join(self.s3_subdir, os.path.relpath(src_path, self.src_logdir))

        # Construct CLI Sync command
        cmd = self.s3_sync_cmd + [src_path, f"s3://{self.bucket_name}/{s3_path}"]

        for includes in path_include.values():
            for pattern in includes:
                # Update include patterns based on gzip setting
                if self.enable_gzip and not pattern.endswith(".gz"):
                    pattern += ".gz"
                cmd += ["--include", pattern]

        # Execute and capture output
        try:
            result = subprocess.run(
                cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                universal_newlines=True
            )
            if result.stdout:
                print(f"{src_path} sync to {s3_path}: {result.stdout}")
            else:
                print(f"{src_path} sync to {s3_path}: no changes detected.")
        except subprocess.CalledProcessError as e:
            print(f"Sync failed: {e.stderr}")
        except Exception as e:
            print(f"Unexpected error during sync: {str(e)}")

    @staticmethod
    def convert_size(size: int) -> str:
        """Convert a size in bytes to a human-readable string.

        Args:
            size (int): The size in bytes.

        Returns:
            str: The human-readable size.
        """
        if size == 0:
            return "0B"
        size_name = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
        i = int(math.floor(math.log(size, 1024)))
        p = math.pow(1024, i)
        s = round(size / p, 2)
        return f"{s}{size_name[i]}"

    @staticmethod
    def get_bytes(size: int, size_incre: str) -> int:
        """Convert a size with unit to bytes.

        Args:
            size (int): The numerical part of the size.
            size_incre (str): The unit of the size (e.g., "KiB", "MiB").

        Returns:
            int: The size in bytes.
        """
        # Convert size to bytes based on unit
        if size_incre == "KiB":
            size *= 2 ** 10
        elif size_incre == "MiB":
            size *= 2 ** 20
        elif size_incre == "GiB":
            size *= 2 ** 30
        elif size_incre == "TiB":
            size *= 2 ** 40
        return size

    @staticmethod
    def get_throughput(sent: int, start_time: float) -> str:
        """Calculate and return the data transfer throughput.

        Args:
            sent (int): The number of bytes sent.
            start_time (float): The start time of the transfer.

        Returns:
            str: The throughput in MB/s.
        """
        elapsed_time = time.monotonic() - start_time
        mb_sent = sent / (1024 * 1024)
        return f"{mb_sent / elapsed_time:.2f} MB/s"

    def process_progress(self, line: str, src_path: str, start_time: float) -> None:
        """Process and print the progress of the sync operation based on AWS CLI output.

        Args:
            line (str): The output line from AWS CLI.
            src_path (str): The source path being synced.
            start_time (float): The start time of the sync operation.
        """
        # Extract and process progress information from AWS CLI output
        line_components = line.split()
        sent = int(float(line_components[1]))
        sent_incre = line_components[2].split("/")[0]
        total_size = int(float(line_components[2].split("/")[1].replace("~", "")))
        total_size_incre = line_components[3]
        sent = self.get_bytes(sent, sent_incre)
        total_size = self.get_bytes(total_size, total_size_incre)
        progress = sent / total_size
        print(
            f"{src_path} - "
            f"{self.convert_size(sent)} / {self.convert_size(total_size)} - "
            f"{progress:.0%} - "
            f"{self.get_throughput(sent, start_time)}",
            end="\r",
        )


def parse_args():
    """Parse command line arguments for the script.

    Returns a Namespace object with parsed arguments if successful;
    otherwise, prints an error message and exits the script with a non-zero status.
    """
    parser = argparse.ArgumentParser(
        description="Sync directories to an AWS S3 bucket with optional gzip compression.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter
    )
    parser.add_argument(
        "-c", "--config", required=True, help="Path to the configuration file."
    )
    parser.add_argument(
        "-d", "--log-directory", required=True,
        help="Base directory containing the log subdirectories to sync."
    )
    parser.add_argument(
        "--aws-profile", required=True,
        help="AWS CLI profile name to use for authentication."
    )
    parser.add_argument(
        "--no-gzip", action="store_true",
        help="Disable gzip compression. Files will be synced as-is without compression."
    )

    return parser.parse_args()


def main():
    """Main entry point for the CLI."""
    args = parse_args()

    try:
        with open(args.config, "r") as file:
            config = yaml.safe_load(file)
        config = Box(config)
    except FileNotFoundError:
        print(f"Error: Configuration file '{args.config}' not found.")
        sys.exit(1)

    local_dirs = {
        args.log_directory + "/" + dir + "/" + subdir: config.subdirs[dir][subdir]
        for dir in config.subdirs.keys()
        for subdir in config.subdirs[dir]
    }

    s3_sync = S3Sync(
        src_paths=local_dirs,
        src_logdir=args.log_directory,
        bucket_name=config.s3_bucket,
        s3_subdir=config.s3_logdir,
        profile_name=args.aws_profile,
        enable_gzip=not args.no_gzip,
    )
    s3_sync.run()


if __name__ == "__main__":
    main()

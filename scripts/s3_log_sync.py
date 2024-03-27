"""Module to sync changes from local PDS reporting server to AWS S3 buckets."""

from typing import Dict, Optional, List
from box import Box
import yaml
import os
import time
import math
import subprocess
import shutil
from multiprocessing import cpu_count


class S3Sync:
    """
    A class to sync directories from a local filesystem to an AWS S3 bucket.

    Attributes:
        src_paths (Dict[str, Dict[str, str]]): Source paths to sync, with include patterns.
        src_logdir (str): The base directory for source logs.
        bucket_name (str): The name of the target S3 bucket.
        s3_subdir (str): The target directory within the S3 bucket.
        profile_name (Optional[str]): AWS CLI profile name. Default is None.
        delete (bool): Flag to delete source files after sync. Default is False.
        workers (int): Number of worker processes to use. Default is the number of CPUs.
        s3_sync_cmd (List[str]): Base command for AWS S3 sync operations.
    """

    def __init__(self, src_paths: Dict[str, Dict[str, str]], src_logdir: str, bucket_name: str,
                 s3_subdir: str, profile_name: Optional[str] = None, delete: bool = False,
                 workers: Optional[int] = None) -> None:
        """Initialize the S3Sync object with configuration for syncing."""
        self.src_paths = src_paths
        self.src_logdir = src_logdir
        self.bucket_name = bucket_name
        self.s3_subdir = s3_subdir
        self.profile_name = profile_name
        self.delete = delete
        self.workers = workers if workers else cpu_count()
        self.s3_sync_cmd = ["aws", "s3", "sync"]
        if self.profile_name:
            self.s3_sync_cmd += ["--profile", self.profile_name]
        self.s3_sync_cmd += ["--exclude", "*"]

    def run(self) -> None:
        """Execute the sync process for all configured source paths."""
        for src_path in self.src_paths.items():
            self.sync_directory(src_path)

    def sync_directory(self, path_tuple: (str, Dict[str, str])) -> None:
        """
        Sync a single directory to S3, including progress logging and deletion if specified.

        Args:
            path_tuple (tuple): A tuple containing the source path and include patterns.
        """
        src_path, path_include = path_tuple
        s3_path = os.path.join(self.s3_subdir, os.path.relpath(src_path, self.src_logdir))
        cmd = self.s3_sync_cmd + [src_path, f"s3://{self.bucket_name}/{s3_path}"]
        for include in path_include:
            cmd += ["--include", include]
        start_time = time.monotonic()
        with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              bufsize=1, universal_newlines=True, shell=False) as proc:
            for line in proc.stdout:
                if "Completed" in line:
                    try:
                        # Process and print progress information
                        self.process_progress(line, src_path, start_time)
                    except Exception as e:
                        print(f"Error parsing AWS CLI output: {e}", end="\r")
            print(f"Completed syncing {src_path}")

        if self.delete:
            # Optionally delete the source directory after sync
            print(f"Deleting local files from {src_path}")
            shutil.rmtree(src_path)

    @staticmethod
    def convert_size(size: int) -> str:
        """
        Convert a size in bytes to a human-readable string.

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
        """
        Convert a size with unit to bytes.

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
        """
        Calculate and return the data transfer throughput.

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
        """
        Process and print the progress of the sync operation based on AWS CLI output.

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



if __name__ == "__main__":
    # Parse basic config file and set up AWS Session
    with open("../config/config_dev_kai.yaml", "r") as file:
        config = yaml.safe_load(file)
    config = Box(config, box_dots=True)
    local_dirs = {
        config.log_directory + "/" + dir + "/" + subdir: config.subdirs[dir][subdir]
        for dir in config.subdirs.keys()
        for subdir in config.subdirs[dir]
    }
    s3_sync = S3Sync(
        src_paths=local_dirs,
        src_logdir=config.log_directory,
        bucket_name=config.s3_bucket,
        s3_subdir=config.s3_logdir,
        profile_name=config.profile_name,
    )
    s3_sync.run()
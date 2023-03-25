""" Sync changes from local PDS reporting server to AWS S3 buckets



"""
from box import Box
import yaml
import io
import os
import re
import sys
from tqdm import tqdm
import time
import math
import subprocess
from multiprocessing import Pool, cpu_count


class S3Sync2:
    def __init__(self,
                 src_paths,
                 src_logdir,
                 bucket_name,
                 s3_subdir,
                 profile_name=None,
                 delete=False,
                 workers=None):
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
        self.s3_sync_cmd += [
            "--exclude",
            ".DS_Store"  # exclude macOS metadata files
        ]

    def run(self):
        pool = Pool(processes=self.workers)
        pool.map(self.sync_directory, self.src_paths)
        pool.close()
        pool.join()

    def sync_directory(self, src_path):
        # Use subprocess to call the AWS CLI command and display progress
        s3_path = os.path.join(self.s3_subdir, os.path.relpath(src_path, self.src_logdir))
        cmd = self.s3_sync_cmd + [src_path, f"s3://{self.bucket_name}/{s3_path}"]
        proc = subprocess.Popen(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=1
        )
        # Use os.walk to get total size of directory (for progress bar)
        total_size = sum(
            os.path.getsize(os.path.join(dirpath, filename))
            for dirpath, _, filenames in os.walk(src_path)
            for filename in filenames
        )

        # Display progress bar
        sent = 0
        for line in io.TextIOWrapper(proc.stdout, encoding="utf-8"):
            print(line.rstrip())
            if "sent" in line:
                if line.split()[2] is not None:
                    sent += int(line.split()[2])
                    progress = sent / total_size
                    print(f"{src_path} - "
                          f"{self.convert_size(sent)} / {self.convert_size(total_size)} - "
                          f"{progress:.0%} - "
                          f"{self.get_throughput(sent)}")
                else:
                    continue
        for line in io.TextIOWrapper(proc.stderr, encoding="utf-8"):
            print(line.rstrip())

        # Wait for the subprocess to finish
        proc.wait()
        if proc.returncode != 0:
            raise Exception(f"S3 sync failed with return code {proc.returncode}")

    @staticmethod
    def convert_size(size_bytes):
        # Convert bytes to a human-readable format
        if size_bytes == 0:
            return "0B"
        size_name = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
        i = int(math.floor(math.log(size_bytes, 1024)))
        p = math.pow(1024, i)
        s = round(size_bytes / p, 2)
        return f"{s}{size_name[i]}"

    @staticmethod
    def get_throughput(sent):
        # Calculate and return the current throughput in MB/s
        elapsed_time = time.monotonic() - start_time
        mb_sent = sent / (1024 * 1024)
        return f"{mb_sent / elapsed_time:.2f} MB/s"


if __name__ == '__main__':
    # Parse basic config file and set up AWS Session
    with open('../config/def.yaml', 'r') as file:
        config = yaml.safe_load(file)
    config = Box(config, box_dots=True)
    local_dirs = [config.log_directory + "/" + dir + "/" + subdir
                  for dir in config.subdirs.keys()
                  for subdir in config.subdirs[dir]]
    s3_sync = S3Sync2(src_paths=local_dirs,
                      src_logdir=config.log_directory,
                      bucket_name=config.s3_bucket,
                      s3_subdir=config.s3_logdir,
                      profile_name=config.profile_name)
    s3_sync.run()
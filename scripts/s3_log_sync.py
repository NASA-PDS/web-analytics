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
from multiprocessing import Pool, cpu_count, Value

class S3Sync2:
    def __init__(self, src_paths, src_logdir, bucket_name, s3_subdir, profile_name=None, delete=False, workers=None):
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
        self.s3_sync_cmd += ["--exclude", ".DS_Store"]

    def run(self):
        for src_path in self.src_paths:
            self.sync_directory(src_path)

    def sync_directory(self, src_path):
        # Use subprocess to call the AWS CLI command and display progress
        start_time = time.monotonic()
        s3_path = os.path.join(self.s3_subdir, os.path.relpath(src_path, self.src_logdir))
        cmd = self.s3_sync_cmd + [src_path, f"s3://{self.bucket_name}/{s3_path}"]
        # Use subprocess to call the AWS CLI command and display progress
        with subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=1,
                              universal_newlines=True) as proc:
            for line in proc.stdout:
                if "Completed" in line:
                    try:
                        line_components = line.split()
                        sent = int((line_components[1]))
                        sent_incre = line_components[2].split('/')[0]
                        total_size = int(float(line_components[2].split('/')[1].replace("~", "")))
                        total_size_incre =  line_components[3]
                        sent = self.get_bytes(sent, sent_incre)
                        total_size = self.get_bytes(total_size, total_size_incre)
                        progress = sent / total_size
                        print(f"{src_path} - "
                              f"{self.convert_size(sent)} / {self.convert_size(total_size)} - "
                              f"{progress:.0%} - "
                              f"{self.get_throughput(sent, start_time)}", end="\r")
                    except Exception as e:
                        print(f"Error parsing aws cli output: {e}", end="\r")
            print(f"Completed syncing {src_path}")

        if self.delete:
            print(f"Deleting local files from {src_path}")
            shutil.rmtree(src_path)

    @staticmethod
    def convert_size(size):
        # Convert bytes to a human-readable format
        if size == 0:
            return "0B"
        size_name = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
        i = int(math.floor(math.log(size, 1024)))
        p = math.pow(1024, i)
        s = round(size / p, 2)
        return f"{s}{size_name[i]}"

    @staticmethod
    def get_bytes(size, size_incre):
        if size_incre == "KiB":
            size *= 2**10
        if size_incre == "MiB":
            size *= 2**20
        if size_incre == "GiB":
            size *= 2**30
        if size_incre == "TiB":
            size *= 2**40
        return size

    @staticmethod
    def get_throughput(sent, start_time):
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
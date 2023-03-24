""" Sync changes from local PDS reporting server to AWS S3 buckets



"""
import boto3
from box import Box
import yaml
import re
import os
import time
from multiprocessing import Process

import boto3
import os
import time
from multiprocessing import Process
from tqdm import tqdm


class S3Sync:
    def __init__(self, local_dirs, bucket_name, s3_prefix, profile_name):
        self.local_dirs = local_dirs
        self.bucket_name = bucket_name
        self.s3_prefix = s3_prefix
        self.profile_name = profile_name
        self.session = boto3.Session(profile_name=self.profile_name)
        self.s3 = self.session.resource('s3')

    def sync_local_dir(self, local_dir):
        # Get list of files in local directory
        local_files = []
        for root, dirs, files in os.walk(local_dir):
            for file in files:
                local_files.append(os.path.join(root, file))

        # Get last sync time from S3
        s3_key = os.path.join(self.s3_prefix, 'last_sync_time')
        try:
            last_sync_time = float(self.s3.Object(self.bucket_name, s3_key).get()['Body'].read().decode())
        except:
            last_sync_time = 0

        # Sync new and modified files to S3
        total_size = 0
        for local_file in local_files:
            if os.path.getmtime(local_file) > last_sync_time:
                total_size += os.path.getsize(local_file)
        progress_bar = tqdm(total=total_size, unit='B', unit_scale=True, desc=f"Uploading {local_dir}")
        start_time = time.time()
        for local_file in local_files:
            if os.path.getmtime(local_file) > last_sync_time:
                s3_key = os.path.join(self.s3_prefix, os.path.relpath(local_file, local_dir))
                self.s3.meta.client.upload_file(local_file, self.bucket_name, s3_key, Callback=lambda sent: progress_bar.update(sent - progress_bar.n))
        end_time = time.time()

        # Calculate throughput and display it in the progress bar
        duration = end_time - start_time
        throughput = total_size / (1024 ** 3) / duration
        progress_bar.set_description(f"Uploading {local_dir} ({round(throughput, 2)} GB/s)")

        # Update last sync time in S3
        last_sync_time = time.time()
        s3_key = os.path.join(self.s3_prefix, 'last_sync_time')
        self.s3.Object(self.bucket_name, s3_key).put(Body=str(last_sync_time))

    def sync(self):
        processes = []
        for local_dir in self.local_dirs:
            p = Process(target=self.sync_local_dir, args=(local_dir,))
            p.start()
            processes.append(p)

        for p in processes:
            p.join()


if __name__ == '__main__':
    # Parse basic config file and set up AWS Session
    with open('../config/def.yaml', 'r') as file:
        config = yaml.safe_load(file)
    config = Box(config, box_dots=True)
    local_dirs = [config.log_directory + "/" + node for node in config.node_dirs]
    s3_sync = S3Sync(profile_name=config.profile_name,
                    local_dirs=local_dirs,
                    bucket_name=config.s3_bucket,
                    s3_prefix=config.s3_logdir)
    s3_sync.sync()


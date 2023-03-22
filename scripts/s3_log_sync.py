""" Sync changes from local PDS reporting server to AWS S3 buckets



"""
import boto3
from box import Box
import yaml
import re
import os






if __name__ == '__main__':
    # Parse basic config file and set up AWS Session
    with open('../config/def.yaml', 'r') as file:
        config = yaml.safe_load(file)
    config = Box(config, box_dots=True)

    session = boto3.Session(profile_name=config.profile_name)
    s3 = session.resource('s3')
    s3_bucket = s3.Bucket(config.s3_bucket)

    for obj in s3_bucket.objects.all():
        print(obj.key)


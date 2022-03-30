""" Sync changes from local PDS reporting server to AWS S3 buckets



"""

import boto3


s3 = boto3.resource('s3')

for bucket in s3.buckets.all():
    print(bucket.name)

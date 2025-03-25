import boto3
from botocore.exceptions import ClientError
import os

# Define your profile, bucket name, prefix, and local destination directory
SOURCE_PROFILE = 'pdsimg-web-log'
SOURCE_BUCKET = 'pdsimg-web-log'
SOURCE_PREFIX = 'logs/img/img-web-log-s3/'
LOCAL_DEST_DIR = 'img'  # Local directory where files will be downloaded

# Create a session for the source AWS profile and initialize S3 resource
source_session = boto3.Session(profile_name=SOURCE_PROFILE)
source_s3 = source_session.resource('s3')
source_bucket = source_s3.Bucket(SOURCE_BUCKET)

# Ensure the local destination directory exists
if not os.path.exists(LOCAL_DEST_DIR):
    os.makedirs(LOCAL_DEST_DIR)

# Loop through objects with the specified prefix in the source bucket
for obj in source_bucket.objects.filter(Prefix=SOURCE_PREFIX):
    # Remove the source prefix from the object's key to construct a relative path
    relative_path = obj.key[len(SOURCE_PREFIX):]
    # Construct the local file path
    local_file_path = os.path.join(LOCAL_DEST_DIR, relative_path)

    # Ensure the directory structure exists locally
    local_dir = os.path.dirname(local_file_path)
    if not os.path.exists(local_dir):
        os.makedirs(local_dir)

    print(f"Downloading {obj.key} to {local_file_path}...")
    try:
        source_bucket.download_file(obj.key, local_file_path)
    except ClientError as e:
        print(f"Error downloading {obj.key}: {e}")
    break

print("Download complete!")

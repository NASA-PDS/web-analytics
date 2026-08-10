#!/bin/bash
set -euo pipefail

# Install system packages
dnf update -y
dnf install -y git python3.13 python3.13-pip --quiet
python3.13 -m pip install --quiet --break-system-packages boto3

# Install Logstash from Elastic RPM repo
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
cat > /etc/yum.repos.d/elastic.repo <<'REPO'
[elasticsearch]
name=Elasticsearch repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
REPO
dnf install -y logstash-${logstash_version}

# Update aws integration plugin — bundled version has a PageableResponse incompatibility with aws-sdk-core 3.213+
/usr/share/logstash/bin/logstash-plugin update logstash-integration-aws

# sincedb: persists S3 read position across restarts
mkdir -p /var/lib/logstash/plugins/inputs/s3
chown -R logstash:logstash /var/lib/logstash

# Write environment file — sourced by the systemd service
cat > /etc/logstash/env <<'ENV'
AWS_REGION=${aws_region}
S3_BUCKET_NAME=${s3_bucket_name}
OPENSEARCH_URL=https://${opensearch_endpoint}
INDEX_PREFIX=${index_prefix}
S3_CF_BUCKET_NAME=${s3_cf_bucket_name}
ENV
chown root:logstash /etc/logstash/env
chmod 640 /etc/logstash/env

# Systemd service unit
cat > /etc/systemd/system/logstash.service <<'SERVICE'
[Unit]
Description=Logstash web-analytics pipeline
After=network.target

[Service]
Type=simple
User=logstash
Group=logstash
EnvironmentFile=/etc/logstash/env
ExecStart=/usr/share/logstash/bin/logstash --path.settings /etc/logstash
Restart=on-failure
RestartSec=30
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable logstash

# Clone repo and run init script on first boot
REPO_DIR="/opt/web-analytics"
REPO_BRANCH="${repo_branch}"

git clone --branch "$REPO_BRANCH" https://github.com/NASA-PDS/web-analytics.git "$REPO_DIR"

OPENSEARCH_ENDPOINT="${opensearch_endpoint}" \
S3_BUCKET_NAME="${s3_bucket_name}" \
S3_CF_BUCKET_NAME="${s3_cf_bucket_name}" \
REPO_BRANCH="$REPO_BRANCH" \
  bash "$REPO_DIR/scripts/logstash-init.sh" >> /var/log/logstash-init.log 2>&1

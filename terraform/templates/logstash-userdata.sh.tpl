#!/bin/bash
set -euo pipefail

# Install Docker
dnf update -y
dnf install -y docker
systemctl enable docker
systemctl start docker

# Add ec2-user to docker group so logstash can be managed without sudo
usermod -aG docker ec2-user

# Pull Logstash image
docker pull docker.elastic.co/logstash/logstash:${logstash_version}

# Create directory for sincedb files (persists S3 read position across restarts)
mkdir -p /var/lib/logstash/sincedb
chown -R ec2-user:ec2-user /var/lib/logstash

# Create systemd service for Logstash container
cat > /etc/systemd/system/logstash.service <<'EOF'
[Unit]
Description=Logstash web-analytics pipeline
After=docker.service
Requires=docker.service

[Service]
Restart=on-failure
RestartSec=30
ExecStartPre=-/usr/bin/docker stop logstash
ExecStartPre=-/usr/bin/docker rm logstash
ExecStart=/usr/bin/docker run --name logstash \
  --env AWS_REGION=${aws_region} \
  --env S3_BUCKET_NAME=${s3_bucket_name} \
  --env AOSS_URL=${opensearch_endpoint} \
  --env INDEX_PREFIX=${index_prefix} \
  --env LS_SETTINGS_DIR=/usr/share/logstash/config \
  --volume /opt/logstash/config:/usr/share/logstash/config:ro \
  --volume /var/lib/logstash/sincedb:/var/lib/logstash/sincedb \
  docker.elastic.co/logstash/logstash:${logstash_version}
ExecStop=/usr/bin/docker stop logstash

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable logstash
# Note: logstash does not auto-start here — config must be deployed to
# /opt/logstash/config before starting. Run: systemctl start logstash

mkdir -p /opt/logstash/config

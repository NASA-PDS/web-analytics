#!/bin/bash
# logstash-init.sh — Initialize Logstash on the web-analytics EC2.
#
# Safe to re-run: updates config, env file, and restarts Logstash.
# Also installs Logstash if not present (for EC2s predating direct-install userdata).
#
# Usage (from an SSM session on the EC2):
#   bash /opt/web-analytics/scripts/logstash-init.sh
#
# Optional env overrides (all auto-populated from SSM/metadata if not set):
#   OPENSEARCH_ENDPOINT  — OpenSearch domain endpoint (without https://)
#   S3_BUCKET_NAME       — S3 bucket for log ingestion
#   AWS_REGION           — AWS region (default: from instance metadata)
#   INDEX_PREFIX         — OpenSearch index prefix (default: pds-dev)
#   S3_CF_BUCKET_NAME    — CloudFront logs bucket (EN only; default: empty)
#   LOGSTASH_VERSION     — Logstash version to install if missing (default: 8.17.0)
#   REPO_BRANCH          — git branch to clone (default: main)

set -euo pipefail

REPO_URL="https://github.com/NASA-PDS/web-analytics.git"
REPO_BRANCH="${REPO_BRANCH:-main}"
REPO_DIR="/opt/web-analytics"
LOGSTASH_CONFIG_DIR="/etc/logstash"
LOGSTASH_VERSION="${LOGSTASH_VERSION:-8.17.0}"
INDEX_PREFIX="${INDEX_PREFIX:-pds-dev}"
S3_CF_BUCKET_NAME="${S3_CF_BUCKET_NAME:-}"

AWS_REGION="${AWS_REGION:-$(curl -sf \
  http://169.254.169.254/latest/meta-data/placement/region || echo 'us-west-2')}"
OPENSEARCH_ENDPOINT="${OPENSEARCH_ENDPOINT:-$(aws ssm get-parameter \
  --name /pds/observability/opensearch_managed/opensearch_endpoint \
  --region "$AWS_REGION" \
  --query Parameter.Value --output text)}"
S3_BUCKET_NAME="${S3_BUCKET_NAME:-$(aws ssm get-parameter \
  --name /pds/web-analytics/s3/bucket_name \
  --region "$AWS_REGION" \
  --query Parameter.Value --output text)}"

echo "=== web-analytics Logstash init ==="
echo "Repo:     $REPO_URL ($REPO_BRANCH)"
echo "Endpoint: $OPENSEARCH_ENDPOINT"
echo ""

# ----------------------------------------
# 0. Install Logstash if not present
# ----------------------------------------
if [ ! -f /usr/share/logstash/bin/logstash ]; then
  echo "--- Installing Logstash ${LOGSTASH_VERSION} ---"
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
  dnf install -y logstash-${LOGSTASH_VERSION}
  mkdir -p /var/lib/logstash/sincedb
  chown -R logstash:logstash /var/lib/logstash
  echo "Logstash installed"
else
  echo "Logstash already installed — skipping"
fi

# ----------------------------------------
# 1. Install tools and clone or update the repo
# ----------------------------------------
echo "--- Cloning web-analytics repo ---"
dnf install -y git gettext --quiet

if [ -d "$REPO_DIR/.git" ]; then
  echo "Repo already exists — pulling latest $REPO_BRANCH"
  git -C "$REPO_DIR" fetch origin
  git -C "$REPO_DIR" checkout "$REPO_BRANCH"
  git -C "$REPO_DIR" pull origin "$REPO_BRANCH"
else
  git clone --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"
fi

# ----------------------------------------
# 2. Copy Logstash config into place
# ----------------------------------------
echo "--- Deploying Logstash pipeline config ---"
cp -r "$REPO_DIR/config/logstash/config/"* "$LOGSTASH_CONFIG_DIR/"
echo "Config deployed to $LOGSTASH_CONFIG_DIR"

# ----------------------------------------
# 3. Build Logstash pipeline configs
# ----------------------------------------
echo "--- Building Logstash pipeline configs ---"
LS_SETTINGS_DIR="$LOGSTASH_CONFIG_DIR" \
  bash "$REPO_DIR/scripts/logstash_build_config.sh"

LS_SETTINGS_DIR="$LOGSTASH_CONFIG_DIR" \
  envsubst < "$LOGSTASH_CONFIG_DIR/pipelines.yml.template" \
  > "$LOGSTASH_CONFIG_DIR/pipelines.yml"
echo "pipelines.yml generated"

chown -R root:logstash "$LOGSTASH_CONFIG_DIR"
chmod -R g+rX "$LOGSTASH_CONFIG_DIR"

# ----------------------------------------
# 4. Apply OpenSearch index template
# ----------------------------------------
echo "--- Applying OpenSearch ECS index template ---"
eval $(aws configure export-credentials --format env)

TEMPLATE_FILE="$REPO_DIR/config/opensearch/ecs-8.17-custom-template.json"
RESPONSE=$(curl -s -o /tmp/template-response.json -w "%{http_code}" \
  -X PUT "https://${OPENSEARCH_ENDPOINT}/_index_template/pds-web-analytics" \
  -H 'Content-Type: application/json' \
  -H "x-amz-security-token: ${AWS_SESSION_TOKEN}" \
  --aws-sigv4 "aws:amz:${AWS_REGION}:es" \
  --user "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}" \
  -d @"$TEMPLATE_FILE")

if [ "$RESPONSE" = "200" ]; then
  echo "Index template applied successfully"
else
  echo "ERROR: Index template apply failed (HTTP $RESPONSE)"
  cat /tmp/template-response.json
  exit 1
fi

# ----------------------------------------
# 5. Write environment file and ensure service unit is present
# ----------------------------------------
echo "--- Configuring Logstash service ---"
ENV_FILE="$LOGSTASH_CONFIG_DIR/env"

cat > "$ENV_FILE" <<EOF
AWS_REGION=${AWS_REGION}
S3_BUCKET_NAME=${S3_BUCKET_NAME}
OPENSEARCH_URL=https://${OPENSEARCH_ENDPOINT}
INDEX_PREFIX=${INDEX_PREFIX}
S3_CF_BUCKET_NAME=${S3_CF_BUCKET_NAME}
EOF
chown root:logstash "$ENV_FILE"
chmod 640 "$ENV_FILE"
echo "Environment file written to $ENV_FILE"

SERVICE_UNIT="/etc/systemd/system/logstash.service"
if [ ! -f "$SERVICE_UNIT" ]; then
  echo "Creating systemd service unit"
  cat > "$SERVICE_UNIT" <<'SERVICE'
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
  echo "Service unit created"
fi

# ----------------------------------------
# 6. Start Logstash
# ----------------------------------------
echo "--- Starting Logstash ---"
systemctl restart logstash
systemctl status logstash --no-pager

echo ""
echo "=== Init complete ==="
echo "Tail logs with: journalctl -u logstash -f"

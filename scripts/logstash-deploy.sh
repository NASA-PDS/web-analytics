#!/bin/bash
# logstash-deploy.sh — Deploy config and (re)start Logstash on the
# web-analytics EC2. No sudo required — run entirely as the `logstash` user.
#
# Safe to re-run: pulls latest config, updates the env file, and restarts
# the systemd --user logstash service.
#
# Usage (as the logstash user — e.g. an SSM Run-As session):
#   bash /opt/web-analytics/scripts/logstash-deploy.sh
#
# Requires scripts/logstash-bootstrap.sh to have been run first (root, once)
# to install Logstash and provision this account — this script will refuse
# to run otherwise.
#
# Optional env overrides (all auto-populated from SSM/metadata if not set):
#   OPENSEARCH_ENDPOINT  — OpenSearch domain endpoint (without https://)
#   S3_BUCKET_NAME       — S3 bucket for log ingestion
#   AWS_REGION           — AWS region (default: us-west-2)
#   INDEX_PREFIX         — OpenSearch index prefix (default: pds-weblogs)
#   S3_CF_BUCKET_NAME    — CloudFront logs bucket (EN only; default: empty)
#   REPO_BRANCH          — git branch to deploy (default: main)

set -euo pipefail

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR: logstash-deploy.sh must NOT be run as root — run it as the logstash user." >&2
  exit 1
fi

REPO_URL="https://github.com/NASA-PDS/web-analytics.git"
REPO_BRANCH="${REPO_BRANCH:-main}"
REPO_DIR="${REPO_DIR:-/opt/web-analytics}"
LOGSTASH_CONFIG_DIR="/etc/logstash"
INDEX_PREFIX="${INDEX_PREFIX:-pds-weblogs}"
S3_CF_BUCKET_NAME="${S3_CF_BUCKET_NAME:-}"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [ ! -f /usr/share/logstash/bin/logstash ]; then
  echo "ERROR: Logstash is not installed. An admin must run 'sudo bash scripts/logstash-bootstrap.sh' first." >&2
  exit 1
fi

AWS_REGION="${AWS_REGION:-us-west-2}"
OPENSEARCH_ENDPOINT="${OPENSEARCH_ENDPOINT:-$(aws ssm get-parameter \
  --name /pds/observability/opensearch/opensearch_endpoint \
  --region "$AWS_REGION" \
  --query Parameter.Value --output text)}"

echo "=== web-analytics Logstash deploy ==="
echo "Repo:     $REPO_URL ($REPO_BRANCH)"
echo "Endpoint: $OPENSEARCH_ENDPOINT"
echo ""

# ----------------------------------------
# 1. Clone or update the repo
# ----------------------------------------
echo "--- Deploying web-analytics repo ---"
if [ -d "$REPO_DIR/.git" ]; then
  echo "Repo already exists — pulling latest $REPO_BRANCH"
  git -C "$REPO_DIR" fetch origin
  git -C "$REPO_DIR" checkout "$REPO_BRANCH"
  git -C "$REPO_DIR" pull origin "$REPO_BRANCH"
else
  git clone --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"
fi

# ----------------------------------------
# 2. Copy Logstash config into place and build pipeline configs
# ----------------------------------------
echo "--- Deploying Logstash pipeline config ---"
cp -r "$REPO_DIR/config/logstash/config/"* "$LOGSTASH_CONFIG_DIR/"
echo "Config deployed to $LOGSTASH_CONFIG_DIR"

echo "--- Building Logstash pipeline configs ---"
LS_SETTINGS_DIR="$LOGSTASH_CONFIG_DIR" \
  bash "$REPO_DIR/scripts/logstash_build_config.sh"
echo "pipelines.yml and pipeline configs generated"

# ----------------------------------------
# 3. Apply OpenSearch index template
# ----------------------------------------
echo "--- Applying OpenSearch ECS index template ---"
eval "$(aws configure export-credentials --format env)"

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
# 4. Write environment file
# ----------------------------------------
echo "--- Configuring Logstash service ---"
ENV_FILE="$LOGSTASH_CONFIG_DIR/env"

S3_BUCKET_NAME="${S3_BUCKET_NAME:-$(aws ssm get-parameter \
  --name /pds/web-analytics/s3/bucket_name \
  --region "$AWS_REGION" \
  --query Parameter.Value --output text)}"

cat > "$ENV_FILE" <<EOF
AWS_REGION=${AWS_REGION}
S3_BUCKET_NAME=${S3_BUCKET_NAME}
OPENSEARCH_URL=https://${OPENSEARCH_ENDPOINT}:443
INDEX_PREFIX=${INDEX_PREFIX}
S3_CF_BUCKET_NAME=${S3_CF_BUCKET_NAME}
LS_SETTINGS_DIR=${LOGSTASH_CONFIG_DIR}
EOF
echo "Environment file written to $ENV_FILE"

# ----------------------------------------
# 5. Start Logstash (systemd --user — no sudo)
# ----------------------------------------
echo "--- Starting Logstash ---"
systemctl --user daemon-reload
systemctl --user enable --now logstash
systemctl --user restart logstash
systemctl --user status logstash --no-pager

echo ""
echo "=== Deploy complete ==="
echo "Tail logs with: journalctl --user-unit logstash -f"

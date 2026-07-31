#!/bin/bash
# logstash-init.sh — Initialize Logstash config on the web-analytics EC2.
#
# Run this once after the EC2 is launched to:
#   1. Clone the web-analytics repo
#   2. Copy Logstash pipeline config into place
#   3. Apply the OpenSearch ECS index template
#   4. Start the Logstash systemd service
#
# Usage (from an SSM session on the EC2):
#   bash logstash-init.sh
#
# Environment variables (auto-populated from instance metadata if not set):
#   OPENSEARCH_ENDPOINT  — OpenSearch domain endpoint (without https://)
#   REPO_BRANCH          — git branch to clone (default: main)

set -euo pipefail

REPO_URL="https://github.com/NASA-PDS/web-analytics.git"
REPO_BRANCH="${REPO_BRANCH:-main}"
REPO_DIR="/opt/web-analytics"
LOGSTASH_CONFIG_DIR="/opt/logstash/config"
OPENSEARCH_ENDPOINT="${OPENSEARCH_ENDPOINT:-$(aws ssm get-parameter \
  --name /pds/web-analytics/opensearch_managed/opensearch_endpoint \
  --query Parameter.Value --output text)}"

echo "=== web-analytics Logstash init ==="
echo "Repo:     $REPO_URL ($REPO_BRANCH)"
echo "Endpoint: $OPENSEARCH_ENDPOINT"
echo ""

# ----------------------------------------
# 1. Clone or update the repo
# ----------------------------------------
echo "--- Cloning web-analytics repo ---"
dnf install -y git --quiet

if [ -d "$REPO_DIR/.git" ]; then
  echo "Repo already exists — pulling latest $REPO_BRANCH"
  git -C "$REPO_DIR" fetch origin
  git -C "$REPO_DIR" checkout "$REPO_BRANCH"
  git -C "$REPO_DIR" pull origin "$REPO_BRANCH"
else
  git clone --branch "$REPO_BRANCH" "$REPO_URL" "$REPO_DIR"
fi

chmod -R o+rX "$REPO_DIR"

# ----------------------------------------
# 2. Copy Logstash config into place
# ----------------------------------------
echo "--- Deploying Logstash pipeline config ---"
mkdir -p "$LOGSTASH_CONFIG_DIR"
cp -r "$REPO_DIR/config/logstash/config/"* "$LOGSTASH_CONFIG_DIR/"
echo "Config deployed to $LOGSTASH_CONFIG_DIR"

# ----------------------------------------
# 3. Apply OpenSearch index template
# ----------------------------------------
echo "--- Applying OpenSearch ECS index template ---"
eval $(aws configure export-credentials --format env)

TEMPLATE_FILE="$REPO_DIR/config/opensearch/ecs-8.17-custom-template.json"
RESPONSE=$(curl -s -o /tmp/template-response.json -w "%{http_code}" \
  -X PUT "https://${OPENSEARCH_ENDPOINT}/_index_template/pds-web-analytics" \
  -H 'Content-Type: application/json' \
  -H "x-amz-security-token: ${AWS_SESSION_TOKEN}" \
  --aws-sigv4 "aws:amz:us-west-2:es" \
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
# 4. Start Logstash
# ----------------------------------------
echo "--- Starting Logstash ---"
systemctl start logstash
systemctl status logstash --no-pager

echo ""
echo "=== Init complete ==="
echo "Tail logs with: journalctl -u logstash -f"

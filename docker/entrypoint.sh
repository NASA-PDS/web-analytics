#!/bin/bash
# Entrypoint for the PDS Web Analytics Logstash container.
# Validates required environment variables, builds pipeline configurations
# from templates (using envsubst), then starts Logstash.
#
# In production (ECS), all variables below are injected via the task definition.
# Do not hardcode values here.

set -euo pipefail

# ---------------------------------------------------------------------------
# Validate required environment variables
# ---------------------------------------------------------------------------
REQUIRED_VARS=(S3_BUCKET_NAME OPENSEARCH_URL INDEX_PREFIX AWS_REGION)

missing=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        missing+=("$var")
    fi
done

if [ ${#missing[@]} -gt 0 ]; then
    echo "ERROR: The following required environment variables are not set:"
    for var in "${missing[@]}"; do
        echo "  - $var"
    done
    exit 1
fi

# ---------------------------------------------------------------------------
# Build per-node pipeline configs from templates
# Generates: $LS_SETTINGS_DIR/pipelines.yml
#            $LS_SETTINGS_DIR/pipelines/pipeline-*.conf
# ---------------------------------------------------------------------------
echo "Building Logstash pipeline configurations..."
bash /usr/local/bin/logstash_build_config.sh

# ---------------------------------------------------------------------------
# Start Logstash
# ---------------------------------------------------------------------------
echo "Starting Logstash (LS_SETTINGS_DIR=${LS_SETTINGS_DIR})..."
exec logstash \
    --path.settings "${LS_SETTINGS_DIR}" \
    --path.data /var/lib/logstash

#!/bin/bash

# Check if LOGSTASH_CONF_HOME is set
if [ -z "$LOGSTASH_CONF_HOME" ]; then
  echo "Error: LOGSTASH_CONF_HOME environment variable is not set"
  echo "Please set LOGSTASH_CONF_HOME to the path of your Logstash configuration directory"
  exit 1
fi

INPUT_DIR="$LOGSTASH_CONF_HOME/inputs"
SHARED_FILTER="$LOGSTASH_CONF_HOME/shared/pds-filter.conf"
SHARED_OUTPUT="$LOGSTASH_CONF_HOME/shared/pds-output-opensearch.conf"
PIPELINE_DIR="$LOGSTASH_CONF_HOME/pipelines"

for input_file in $LOGSTASH_CONF_HOME/inputs/*.conf; do
  name=$(basename "$input_file" .conf)
  cat "$input_file" $LOGSTASH_CONF_HOME/shared/pds-filter.conf $LOGSTASH_CONF_HOME/shared/pds-output-opensearch.conf \
    > "$LOGSTASH_CONF_HOME/pipelines/pipeline-${name}.conf"
done
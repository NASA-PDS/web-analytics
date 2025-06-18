#!/bin/bash

# Check if LS_SETTINGS_DIR is set
if [ -z "$LS_SETTINGS_DIR" ]; then
  echo "Error: LS_SETTINGS_DIR environment variable is not set"
  echo "Please set LS_SETTINGS_DIR to the path of your Logstash configuration directory"
  exit 1
fi

INPUT_DIR="$LS_SETTINGS_DIR/inputs"
SHARED_FILTER="$LS_SETTINGS_DIR/shared/pds-filter.conf"
SHARED_OUTPUT="$LS_SETTINGS_DIR/shared/pds-output-opensearch.conf"
PIPELINE_DIR="$LS_SETTINGS_DIR/pipelines"

mkdir -p $LS_SETTINGS_DIR/pipelines

for input_file in $LS_SETTINGS_DIR/inputs/*.conf; do
  name=$(basename "$input_file" .conf)
  cat "$input_file" $SHARED_FILTER $SHARED_OUTPUT \
    > "$PIPELINE_DIR/pipeline-${name}.conf"
  echo "Created $PIPELINE_DIR/pipeline-${name}.conf"
done
#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKSPACE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
export LS_SETTINGS_DIR="${WORKSPACE_DIR}/config/logstash/config"
export SCRIPT_DIR
echo "SCRIPT_DIR: $SCRIPT_DIR"

# Create output directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/output"

rm -fr $SCRIPT_DIR/output/*

TMP_CONF=$(mktemp)
echo "TMP_CONF: $TMP_CONF"
cat "$SCRIPT_DIR/config/test-input-https.conf" \
    "$LS_SETTINGS_DIR/shared/pds-filter.conf" \
    "$SCRIPT_DIR/config/test-output.conf" > "$TMP_CONF"

# "$SCRIPT_DIR/config/test-input-ftp.conf" 

logstash -f "$TMP_CONF" --log.level=debug

rm -f "$TMP_CONF"

# TMP_CONF2=$(mktemp)
# echo "TMP_CONF2: $TMP_CONF2"
# cat "$SCRIPT_DIR/config/test-input-ftp.conf" \
#     "$WORKSPACE_DIR/config/logstash/pds-filter.conf" \
#     "$SCRIPT_DIR/config/test-output.conf" > "$TMP_CONF2"
# rm -f "$TMP_CONF2"

# Get today's date in YYYY-MM-dd format
TODAY=$(date +%Y-%m-%d)

# Check results
echo "Checking test results..."
echo "Parse Failures:"
if [ -d "$SCRIPT_DIR/output/parse-failures/$TODAY" ]; then
    echo "Found parse failures:"
    find "$SCRIPT_DIR/output/parse-failures/$TODAY" -type f -name "*.json" -exec cat {} \;
else
    echo "No parse failures found"
fi

echo -e "\nBad Logs:"
if [ -d "$SCRIPT_DIR/output/bad-logs/$TODAY" ]; then
    echo "Found bad logs:"
    find "$SCRIPT_DIR/output/bad-logs/$TODAY" -type f -name "*.json" -exec cat {} \;
else
    echo "No bad logs found"
fi

echo -e "\nInvalid HTTP Methods:"
if [ -d "$SCRIPT_DIR/output/invalid-methods/$TODAY" ]; then
    echo "Found invalid HTTP methods:"
    find "$SCRIPT_DIR/output/invalid-methods/$TODAY" -type f -name "*.json" -exec cat {} \;
else
    echo "No invalid HTTP methods found"
fi

echo -e "\nTemplate Errors:"
if [ -d "$SCRIPT_DIR/output/template-errors/$TODAY" ]; then
    echo "Found template errors:"
    find "$SCRIPT_DIR/output/template-errors/$TODAY" -type f -name "*.json" -exec cat {} \;
else
    echo "No template errors found"
fi

echo -e "\nEmpty User Agents:"
if [ -d "$SCRIPT_DIR/output/empty-user-agents/$TODAY" ]; then
    echo "Found empty user agents:"
    find "$SCRIPT_DIR/output/empty-user-agents/$TODAY" -type f -name "*.json" -exec cat {} \;
else
    echo "No empty user agents found"
fi

echo -e "\nDuplicate Source Addresses:"
if [ -d "$SCRIPT_DIR/output/duplicate-sources/$TODAY" ]; then
    echo "Found duplicate source addresses:"
    find "$SCRIPT_DIR/output/duplicate-sources/$TODAY" -type f -name "*.json" -exec cat {} \;
else
    echo "No duplicate source addresses found"
fi

echo -e "\nProcessed Logs:"
if [ -d "$SCRIPT_DIR/output/processed-logs/$TODAY" ]; then
    echo "Found processed logs:"
    find "$SCRIPT_DIR/output/processed-logs/$TODAY" -type f -name "*.json" -exec cat {} \;
else
    echo "No processed logs found"
fi

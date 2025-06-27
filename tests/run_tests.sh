#!/bin/bash

# =============================================================================
# CONFIGURABLE TEST EXPECTATIONS
# =============================================================================
# Expected number of files in each output directory after test runs
EXPECTED_PARSE_FAILURES=0
EXPECTED_BAD_LOGS=0
EXPECTED_INVALID_METHODS=1
EXPECTED_TEMPLATE_ERRORS=0
EXPECTED_EMPTY_USER_AGENTS=2
EXPECTED_DUPLICATE_SOURCES=0
EXPECTED_PROCESSED_LOGS=22

# =============================================================================
# SCRIPT CONFIGURATION
# =============================================================================
# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORKSPACE_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
export LS_SETTINGS_DIR="${WORKSPACE_DIR}/config/logstash/config"
export SCRIPT_DIR=${SCRIPT_DIR}
export OUTPUT_DIR=${WORKSPACE_DIR}/target/test/
echo "SCRIPT_DIR: $SCRIPT_DIR"
echo "OUTPUT_DIR: $OUTPUT_DIR"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"
rm -fr $OUTPUT_DIR/*

TMP_CONF=$(mktemp)
echo "TMP_CONF: $TMP_CONF"
cat "$SCRIPT_DIR/config/test-input-https.conf" \
    "$LS_SETTINGS_DIR/shared/pds-filter.conf" \
    "$SCRIPT_DIR/config/test-output.conf" > "$TMP_CONF"

logstash -f "$TMP_CONF" --log.level=debug

rm -f "$TMP_CONF"

TMP_CONF2=$(mktemp)
echo "TMP_CONF2: $TMP_CONF2"
cat "$SCRIPT_DIR/config/test-input-ftp.conf" \
    "$LS_SETTINGS_DIR/shared/pds-filter.conf" \
    "$SCRIPT_DIR/config/test-output.conf" > "$TMP_CONF2"

logstash -f "$TMP_CONF2" --log.level=debug

rm -f "$TMP_CONF2"

# Function to count files in a directory
count_files() {
    local dir="$1"
    if [ -d "$dir" ]; then
        find "$dir" -type f -name "*.json" | wc -l
    else
        echo "0"
    fi
}

# Function to validate expected file counts
validate_directory() {
    local dir="$1"
    local expected="$2"
    local description="$3"

    local actual=$(count_files "$dir")
    echo -n "$description: "

    if [ "$actual" -eq "$expected" ]; then
        echo "✅ PASS ($actual files, expected $expected)"
        return 0
    else
        echo "❌ FAIL ($actual files, expected $expected)"
        return 1
    fi
}

# Check results and validate expected counts
echo "Checking test results..."
echo "=========================================="

# Initialize test results
test_passed=true

# Validate each output directory
if ! validate_directory "$OUTPUT_DIR/parse-failures/" "$EXPECTED_PARSE_FAILURES" "Parse Failures"; then
    test_passed=false
fi

if ! validate_directory "$OUTPUT_DIR/bad-logs/" "$EXPECTED_BAD_LOGS" "Bad Logs"; then
    test_passed=false
fi

if ! validate_directory "$OUTPUT_DIR/invalid-methods/" "$EXPECTED_INVALID_METHODS" "Invalid HTTP Methods"; then
    test_passed=false
fi

if ! validate_directory "$OUTPUT_DIR/template-errors/" "$EXPECTED_TEMPLATE_ERRORS" "Template Errors"; then
    test_passed=false
fi

if ! validate_directory "$OUTPUT_DIR/empty-user-agents/" "$EXPECTED_EMPTY_USER_AGENTS" "Empty User Agents"; then
    test_passed=false
fi

if ! validate_directory "$OUTPUT_DIR/duplicate-sources/" "$EXPECTED_DUPLICATE_SOURCES" "Duplicate Source Addresses"; then
    test_passed=false
fi

if ! validate_directory "$OUTPUT_DIR/processed-logs/" "$EXPECTED_PROCESSED_LOGS" "Processed Logs (Success)"; then
    test_passed=false
fi

echo "=========================================="

# Show detailed results for debugging
echo -e "\nDetailed Results:"
echo "Parse Failures:"
if [ -d "$OUTPUT_DIR/parse-failures/" ]; then
    echo "Found parse failures:"
    find "$OUTPUT_DIR/parse-failures/" -type f -name "*.json" -exec cat {} \;
else
    echo "No parse failures found"
fi

echo -e "\nBad Logs:"
if [ -d "$OUTPUT_DIR/bad-logs/" ]; then
    echo "Found bad logs:"
    find "$OUTPUT_DIR/bad-logs/" -type f -name "*.json" -exec cat {} \;
else
    echo "No bad logs found"
fi

echo -e "\nInvalid HTTP Methods:"
if [ -d "$OUTPUT_DIR/invalid-methods/" ]; then
    echo "Found invalid HTTP methods:"
    find "$OUTPUT_DIR/invalid-methods/" -type f -name "*.json" -exec cat {} \;
else
    echo "No invalid HTTP methods found"
fi

echo -e "\nTemplate Errors:"
if [ -d "$OUTPUT_DIR/template-errors/" ]; then
    echo "Found template errors:"
    find "$OUTPUT_DIR/template-errors/" -type f -name "*.json" -exec cat {} \;
else
    echo "No template errors found"
fi

echo -e "\nEmpty User Agents:"
if [ -d "$OUTPUT_DIR/empty-user-agents/" ]; then
    echo "Found empty user agents:"
    find "$OUTPUT_DIR/empty-user-agents/" -type f -name "*.json" -exec cat {} \;
else
    echo "No empty user agents found"
fi

echo -e "\nDuplicate Source Addresses:"
if [ -d "$OUTPUT_DIR/duplicate-sources/" ]; then
    echo "Found duplicate source addresses:"
    find "$OUTPUT_DIR/duplicate-sources/" -type f -name "*.json" -exec cat {} \;
else
    echo "No duplicate source addresses found"
fi

echo -e "\nProcessed Logs:"
if [ -d "$OUTPUT_DIR/processed-logs/" ]; then
    echo "Found processed logs:"
    find "$OUTPUT_DIR/processed-logs/" -type f -name "*.json" -exec cat {} \;
else
    echo "No processed logs found"
fi

# Final test result
echo "=========================================="
if [ "$test_passed" = true ]; then
    echo "🎉 ALL TESTS PASSED!"
    exit 0
else
    echo "💥 SOME TESTS FAILED!"
    exit 1
fi

#!/bin/bash

# Test runner script for PDS Web Analytics tests
# This script runs both unit tests and integration tests using unittest
# Usage: ./run_unit_tests.sh [options]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TEST_DIR="tests"
VERBOSE=""
FAIL_FAST=""
INTEGRATION_ONLY=""
UNIT_ONLY=""
TEST_FILE=""
TEST_NAME=""

# Function to print usage
print_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -v, --verbose           Run tests in verbose mode"
    echo "  -f, --fail-fast         Stop on first failure"
    echo "  -t, --test-file FILE    Run specific test file"
    echo "  -k, --test-name NAME    Run specific test by name"
    echo "  -i, --integration       Run only integration tests"
    echo "  -u, --unit              Run only unit tests"
    echo ""
    echo "Test Types:"
    echo "  Unit Tests:             Python-based tests for individual components"
    echo "  Integration Tests:      End-to-end tests for Logstash pipeline"
    echo ""
    echo "Examples:"
    echo "  $0                      # Run all tests (unit + integration)"
    echo "  $0 -v                   # Run all tests in verbose mode"
    echo "  $0 -i                   # Run only integration tests"
    echo "  $0 -u                   # Run only unit tests"
    echo "  $0 -t test_s3_sync.py   # Run only S3Sync tests"
    echo "  $0 -k test_init         # Run tests with 'init' in the name"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -f|--fail-fast)
            FAIL_FAST="-f"
            shift
            ;;
        -t|--test-file)
            TEST_FILE="$2"
            shift 2
            ;;
        -k|--test-name)
            TEST_NAME="$2"
            shift 2
            ;;
        -i|--integration)
            INTEGRATION_ONLY=true
            shift
            ;;
        -u|--unit)
            UNIT_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Check if we're in the right directory
if [[ ! -d "$TEST_DIR" ]]; then
    echo -e "${RED}Error: Test directory '$TEST_DIR' not found.${NC}"
    echo "Please run this script from the project root directory."
    exit 1
fi

# Check if Python is available
if ! command -v python &> /dev/null; then
    echo -e "${RED}Error: Python is not installed or not in PATH.${NC}"
    exit 1
fi

# Check if the package is installed in development mode
if ! python -c "import pds.web_analytics" 2>/dev/null; then
    echo -e "${YELLOW}Warning: pds.web_analytics package not found.${NC}"
    echo "Installing package in development mode..."
    pip install -e .
fi

# Determine which tests to run
if [[ "$INTEGRATION_ONLY" == true ]]; then
    echo -e "${BLUE}Running integration tests only...${NC}"
    TEST_PATTERN="$TEST_DIR/test_logstash_integration.py"
elif [[ "$UNIT_ONLY" == true ]]; then
    echo -e "${BLUE}Running unit tests only...${NC}"
    TEST_PATTERN="$TEST_DIR/test_s3_sync.py"
else
    echo -e "${BLUE}Running all tests (unit + integration)...${NC}"
    TEST_PATTERN="$TEST_DIR"
fi

# Function to run unittest tests
run_unittest() {
    local test_pattern="$1"
    local verbose_flag=""
    local fail_fast_flag=""

    if [[ "$VERBOSE" == "-v" ]]; then
        verbose_flag="-v"
    fi

    if [[ "$FAIL_FAST" == "-f" ]]; then
        fail_fast_flag="-f"
    fi

    # Build unittest command
    UNITTEST_CMD="python -m unittest"

    if [[ -n "$TEST_FILE" ]]; then
        # Run specific test file
        test_file_path="$TEST_DIR/$TEST_FILE"
        if [[ -f "$test_file_path" ]]; then
            UNITTEST_CMD="$UNITTEST_CMD $test_file_path"
        else
            echo -e "${RED}Error: Test file '$test_file_path' not found.${NC}"
            exit 1
        fi
    elif [[ -n "$TEST_NAME" ]]; then
        # Run specific test by name pattern
        UNITTEST_CMD="$UNITTEST_CMD -k $TEST_NAME $test_pattern"
    else
        # Run all tests in pattern
        UNITTEST_CMD="$UNITTEST_CMD discover $test_pattern"
    fi

    if [[ -n "$verbose_flag" ]]; then
        UNITTEST_CMD="$UNITTEST_CMD $verbose_flag"
    fi

    if [[ -n "$fail_fast_flag" ]]; then
        UNITTEST_CMD="$UNITTEST_CMD $fail_fast_flag"
    fi

    echo -e "${BLUE}Running unittest: $UNITTEST_CMD${NC}"
    eval $UNITTEST_CMD
}

# Run tests
echo -e "${BLUE}Starting test execution...${NC}"
echo "=================================="

if [[ "$INTEGRATION_ONLY" == true ]]; then
    # Run only integration tests
    run_unittest "$TEST_DIR/test_logstash_integration.py"

elif [[ "$UNIT_ONLY" == true ]]; then
    # Run only unit tests
    run_unittest "$TEST_DIR/test_s3_sync.py"

else
    # Run all tests
    echo -e "${BLUE}Running integration tests...${NC}"
    run_unittest "$TEST_DIR/test_logstash_integration.py"

    echo -e "${BLUE}Running unit tests...${NC}"
    run_unittest "$TEST_DIR/test_s3_sync.py"
fi

# Check if tests passed
if [[ $? -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi

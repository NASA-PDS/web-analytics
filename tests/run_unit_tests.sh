#!/bin/bash

# Test runner script for PDS Web Analytics unit tests
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
COVERAGE=""
FAIL_FAST=""
PARALLEL=""
MARKERS=""

# Function to print usage
print_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -v, --verbose           Run tests in verbose mode"
    echo "  -c, --coverage          Run tests with coverage report"
    echo "  -f, --fail-fast         Stop on first failure"
    echo "  -p, --parallel          Run tests in parallel"
    echo "  -m, --markers MARKERS   Run only tests with specific markers"
    echo "  -t, --test-file FILE    Run specific test file"
    echo "  -k, --test-name NAME    Run specific test by name"
    echo ""
    echo "Examples:"
    echo "  $0                      # Run all tests"
    echo "  $0 -v                   # Run all tests in verbose mode"
    echo "  $0 -c                   # Run tests with coverage"
    echo "  $0 -t test_s3_sync.py   # Run only S3Sync tests"
    echo "  $0 -k test_init         # Run tests with 'init' in the name"
    echo "  $0 -m 'not slow'        # Run tests not marked as slow"
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
        -c|--coverage)
            COVERAGE="--cov=src/pds/web_analytics --cov-report=html --cov-report=term-missing"
            shift
            ;;
        -f|--fail-fast)
            FAIL_FAST="-x"
            shift
            ;;
        -p|--parallel)
            PARALLEL="-n auto"
            shift
            ;;
        -m|--markers)
            MARKERS="-m $2"
            shift 2
            ;;
        -t|--test-file)
            TEST_FILE="$2"
            shift 2
            ;;
        -k|--test-name)
            TEST_NAME="-k $2"
            shift 2
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

# Check if pytest is installed
if ! command -v pytest &> /dev/null; then
    echo -e "${RED}Error: pytest is not installed.${NC}"
    echo "Please install pytest: pip install pytest"
    exit 1
fi

# Check if the package is installed in development mode
if ! python -c "import pds.web_analytics" 2>/dev/null; then
    echo -e "${YELLOW}Warning: pds.web_analytics package not found.${NC}"
    echo "Installing package in development mode..."
    pip install -e .
fi

# Build command
PYTEST_CMD="pytest $TEST_DIR"

if [[ -n "$TEST_FILE" ]]; then
    PYTEST_CMD="$PYTEST_CMD/$TEST_FILE"
fi

if [[ -n "$VERBOSE" ]]; then
    PYTEST_CMD="$PYTEST_CMD $VERBOSE"
fi

if [[ -n "$COVERAGE" ]]; then
    PYTEST_CMD="$PYTEST_CMD $COVERAGE"
fi

if [[ -n "$FAIL_FAST" ]]; then
    PYTEST_CMD="$PYTEST_CMD $FAIL_FAST"
fi

if [[ -n "$PARALLEL" ]]; then
    # Check if pytest-xdist is installed for parallel execution
    if ! python -c "import xdist" 2>/dev/null; then
        echo -e "${YELLOW}Warning: pytest-xdist not installed. Installing...${NC}"
        pip install pytest-xdist
    fi
    PYTEST_CMD="$PYTEST_CMD $PARALLEL"
fi

if [[ -n "$MARKERS" ]]; then
    PYTEST_CMD="$PYTEST_CMD $MARKERS"
fi

if [[ -n "$TEST_NAME" ]]; then
    PYTEST_CMD="$PYTEST_CMD $TEST_NAME"
fi

# Add common options
PYTEST_CMD="$PYTEST_CMD --tb=short --strict-markers"

echo -e "${BLUE}Running tests with command:${NC}"
echo "$PYTEST_CMD"
echo ""

# Run the tests
echo -e "${BLUE}Starting test execution...${NC}"
echo "=================================="

if eval $PYTEST_CMD; then
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    
    if [[ -n "$COVERAGE" ]]; then
        echo ""
        echo -e "${BLUE}Coverage report generated in htmlcov/index.html${NC}"
    fi
    
    exit 0
else
    echo ""
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi 
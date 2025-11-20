#!/bin/bash

# Load testing script for the Items API via Azure APIM
# This script uses 'hey' (a modern HTTP load generator) to generate load
# and properly handles APIM authentication with subscription keys

set -e

# Parse command line arguments
VERBOSE=false
DURATION=900  # Default 15 minutes (safe for Cloud Shell)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            DURATION=$1
            shift
            ;;
    esac
done

# Use APIM_GATEWAY_URL if available, otherwise fall back to APIM_URL
if [ -z "$APIM_URL" ]; then
    APIM_URL="${APIM_GATEWAY_URL}"
fi

# Use SUBSCRIPTION_KEY if available, otherwise fall back to APIM_KEY
if [ -z "$APIM_KEY" ]; then
    APIM_KEY="${SUBSCRIPTION_KEY}"
fi

# Configuration
RPS=${RPS:-10}             # Requests per second (workshop-appropriate load)
WORKERS=${WORKERS:-5}      # Number of concurrent workers

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if APIM URL and Key are provided
if [ -z "$APIM_URL" ]; then
    print_error "APIM_GATEWAY_URL or APIM_URL environment variable is required"
    echo ""
    echo "Usage: ./load-test-apim.sh [OPTIONS] [DURATION_IN_SECONDS]"
    echo ""
    echo "Options:"
    echo "  -v, --verbose    Show detailed output for each request type"
    echo ""
    echo "Environment variables:"
    echo "  APIM_GATEWAY_URL - APIM gateway URL (required, from workshop-env.sh)"
    echo "  APIM_URL         - Alternative to APIM_GATEWAY_URL"
    echo "  SUBSCRIPTION_KEY - APIM subscription key (required, from workshop-env.sh)"
    echo "  APIM_KEY         - Alternative to SUBSCRIPTION_KEY"
    echo "  RPS              - Requests per second (default: 3)"
    echo "  WORKERS          - Number of concurrent workers (default: 2)"
    echo ""
    echo "Examples:"
    echo "  source scripts/workshop-env.sh              # Load workshop variables"
    echo "  ./load-test-apim.sh                         # Run with defaults (15 min)"
    echo "  ./load-test-apim.sh 60                      # Run for 1 minute (quick test)"
    echo "  ./load-test-apim.sh --verbose 300           # Run for 5 minutes with verbose output"
    echo "  RPS=10 ./load-test-apim.sh 900              # Run for 15 minutes with 10 RPS"
    exit 1
fi

if [ -z "$APIM_KEY" ]; then
    print_error "SUBSCRIPTION_KEY or APIM_KEY environment variable is required"
    echo ""
    echo "Usage: ./load-test-apim.sh [OPTIONS] [DURATION_IN_SECONDS]"
    echo ""
    echo "Options:"
    echo "  -v, --verbose    Show detailed output for each request type"
    echo ""
    echo "Environment variables:"
    echo "  APIM_GATEWAY_URL - APIM gateway URL (required, from workshop-env.sh)"
    echo "  APIM_URL         - Alternative to APIM_GATEWAY_URL"
    echo "  SUBSCRIPTION_KEY - APIM subscription key (required, from workshop-env.sh)"
    echo "  APIM_KEY         - Alternative to SUBSCRIPTION_KEY"
    echo "  RPS              - Requests per second (default: 3)"
    echo "  WORKERS          - Number of concurrent workers (default: 2)"
    echo ""
    echo "Examples:"
    echo "  source scripts/workshop-env.sh              # Load workshop variables"
    echo "  ./load-test-apim.sh                         # Run with defaults (15 min)"
    echo "  ./load-test-apim.sh 60                      # Run for 1 minute (quick test)"
    echo "  ./load-test-apim.sh --verbose 300           # Run for 5 minutes with verbose output"
    echo "  RPS=10 ./load-test-apim.sh 900              # Run for 15 minutes with 10 RPS"
    exit 1
fi

# Remove trailing slash from APIM_URL if present
APIM_URL=${APIM_URL%/}

# Append /api path if not already present (workshop URLs point to gateway, not /api endpoint)
if [[ ! "$APIM_URL" =~ /api$ ]]; then
    APIM_URL="${APIM_URL}/api"
fi

print_info "Load Test Configuration:"
echo "  APIM URL: $APIM_URL"
echo "  Duration: ${DURATION}s (~$((DURATION / 60)) minutes)"
echo "  Target RPS: $RPS"
echo "  Workers: $WORKERS"
echo ""

# Check if hey is installed
if ! command -v hey &> /dev/null; then
    print_error "'hey' is not installed"
    echo ""
    echo "To install 'hey':"
    echo "  wget https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64"
    echo "  chmod +x hey_linux_amd64"
    echo "  mkdir -p ~/bin"
    echo "  mv hey_linux_amd64 ~/bin/hey"
    echo "  export PATH=\$PATH:~/bin"
    echo ""
    echo "Note: You may need to run 'export PATH=\$PATH:~/bin' in your current shell"
    echo ""
    exit 1
fi

HEY_CMD="hey"
print_info "Using 'hey' for load testing"

# Common headers for APIM
APIM_HEADER="Ocp-Apim-Subscription-Key: $APIM_KEY"

# Realistic traffic distribution (40% POST, 30% GET list, 20% GET item, 10% DELETE)
print_info "Starting realistic traffic simulation"
print_info "Running POST requests (40% of load)..."

# Calculate QPS for each request type, ensuring minimum of 1
POST_QPS=$(( (RPS * 40 + 99) / 100 ))  # Round up: 40% of RPS
GET_LIST_QPS=$(( (RPS * 30 + 99) / 100 ))  # 30% of RPS
GET_ITEM_QPS=$(( (RPS * 20 + 99) / 100 ))  # 20% of RPS
DELETE_QPS=$(( (RPS * 10 + 99) / 100 ))  # 10% of RPS

# Ensure minimum of 1 for each
POST_QPS=$(( POST_QPS < 1 ? 1 : POST_QPS ))
GET_LIST_QPS=$(( GET_LIST_QPS < 1 ? 1 : GET_LIST_QPS ))
GET_ITEM_QPS=$(( GET_ITEM_QPS < 1 ? 1 : GET_ITEM_QPS ))
DELETE_QPS=$(( DELETE_QPS < 1 ? 1 : DELETE_QPS ))

$HEY_CMD -z ${DURATION}s -q $POST_QPS -c $((WORKERS * 4 / 10 + 1)) \
    -m POST \
    -H "Content-Type: application/json" \
    -H "$APIM_HEADER" \
    -d '{"name":"LoadTest Item","quantity":100}' \
    "$APIM_URL/items" > /tmp/loadtest-apim-post.txt &
POST_PID=$!

print_info "Running GET list requests (30% of load)..."
$HEY_CMD -z ${DURATION}s -q $GET_LIST_QPS -c $((WORKERS * 3 / 10 + 1)) \
    -m GET \
    -H "$APIM_HEADER" \
    "$APIM_URL/items" > /tmp/loadtest-apim-get-list.txt &
GET_LIST_PID=$!

print_info "Running GET item requests (20% of load)..."
$HEY_CMD -z ${DURATION}s -q $GET_ITEM_QPS -c $((WORKERS * 2 / 10 + 1)) \
    -m GET \
    -H "$APIM_HEADER" \
    "$APIM_URL/items/1" > /tmp/loadtest-apim-get-item.txt &
GET_ITEM_PID=$!

print_info "Running DELETE requests (10% of load)..."
$HEY_CMD -z ${DURATION}s -q $DELETE_QPS -c $((WORKERS * 1 / 10 + 1)) \
    -m DELETE \
    -H "$APIM_HEADER" \
    "$APIM_URL/items/999" > /tmp/loadtest-apim-delete.txt &
DELETE_PID=$!

# Wait for all processes
wait $POST_PID
wait $GET_LIST_PID
wait $GET_ITEM_PID
wait $DELETE_PID

print_info "Traffic simulation completed"
echo ""

if [ "$VERBOSE" = true ]; then
    echo "==================================================================="
    echo "POST (40%):"
    echo "==================================================================="
    cat /tmp/loadtest-apim-post.txt
    echo ""
    echo "==================================================================="
    echo "GET List (30%):"
    echo "==================================================================="
    cat /tmp/loadtest-apim-get-list.txt
    echo ""
    echo "==================================================================="
    echo "GET Item (20%):"
    echo "==================================================================="
    cat /tmp/loadtest-apim-get-item.txt
    echo ""
    echo "==================================================================="
    echo "DELETE (10%):"
    echo "==================================================================="
    cat /tmp/loadtest-apim-delete.txt
else
    # Summary mode - show condensed output
    echo "==================================================================="
    echo "POST (40%):"
    echo "==================================================================="
    cat /tmp/loadtest-apim-post.txt | grep -A 6 "^Summary:" | head -7
    cat /tmp/loadtest-apim-post.txt | grep -A 10 "^Status code distribution:"
    echo ""
    echo "==================================================================="
    echo "GET List (30%):"
    echo "==================================================================="
    cat /tmp/loadtest-apim-get-list.txt | grep -A 6 "^Summary:" | head -7
    cat /tmp/loadtest-apim-get-list.txt | grep -A 10 "^Status code distribution:"
    echo ""
    echo "==================================================================="
    echo "GET Item (20%):"
    echo "==================================================================="
    cat /tmp/loadtest-apim-get-item.txt | grep -A 6 "^Summary:" | head -7
    cat /tmp/loadtest-apim-get-item.txt | grep -A 10 "^Status code distribution:"
    echo ""
    echo "==================================================================="
    echo "DELETE (10%):"
    echo "==================================================================="
    cat /tmp/loadtest-apim-delete.txt | grep -A 6 "^Summary:" | head -7
    cat /tmp/loadtest-apim-delete.txt | grep -A 10 "^Status code distribution:"
fi

echo ""
print_info "Load testing complete!"
print_info "Results saved to /tmp/loadtest-apim-*.txt"
print_info ""
print_info "Full results can be viewed with:"
echo "  cat /tmp/loadtest-apim-post.txt"
echo "  cat /tmp/loadtest-apim-get-list.txt"
echo "  cat /tmp/loadtest-apim-get-item.txt"
echo "  cat /tmp/loadtest-apim-delete.txt"

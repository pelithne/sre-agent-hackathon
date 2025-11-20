#!/bin/bash

# Load testing script for the Items API via Azure APIM
# This script uses 'hey' (a modern HTTP load generator) to generate load
# and properly handles APIM authentication with subscription keys

set -e

# Configuration
DURATION=${DURATION:-60}  # Duration in seconds
RPS=${RPS:-10}            # Requests per second
WORKERS=${WORKERS:-5}     # Number of concurrent workers

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
    print_error "APIM_URL environment variable is required"
    echo "Usage: APIM_URL=https://your-apim.azure-api.net APIM_KEY=your-key ./load-test-apim.sh"
    exit 1
fi

if [ -z "$APIM_KEY" ]; then
    print_error "APIM_KEY environment variable is required"
    echo "Usage: APIM_URL=https://your-apim.azure-api.net APIM_KEY=your-key ./load-test-apim.sh"
    exit 1
fi

# Remove trailing slash from APIM_URL if present
APIM_URL=${APIM_URL%/}

print_info "Load Test Configuration:"
echo "  APIM URL: $APIM_URL"
echo "  Duration: ${DURATION}s"
echo "  Target RPS: $RPS"
echo "  Workers: $WORKERS"
echo ""

# Check if hey is installed
if ! command -v hey &> /dev/null; then
    print_warn "'hey' is not installed. Attempting to use docker version..."
    HEY_CMD="docker run --rm williamyeh/hey"
else
    HEY_CMD="hey"
    print_info "Using local 'hey' installation"
fi

# Common headers for APIM
APIM_HEADER="Ocp-Apim-Subscription-Key: $APIM_KEY"

# Test 1: POST /items (40% of load - Create items)
print_info "Test 1/4: Creating items via APIM (POST /items)"
$HEY_CMD -z ${DURATION}s -q $RPS -c $WORKERS \
    -m POST \
    -H "Content-Type: application/json" \
    -H "$APIM_HEADER" \
    -d '{"name":"LoadTest Item via APIM","quantity":100}' \
    "$APIM_URL/items" | tee /tmp/loadtest-apim-post.txt

echo ""
sleep 2

# Test 2: GET /items (30% of load - List items)
print_info "Test 2/4: Listing items via APIM (GET /items)"
$HEY_CMD -z ${DURATION}s -q $RPS -c $WORKERS \
    -m GET \
    -H "$APIM_HEADER" \
    "$APIM_URL/items" | tee /tmp/loadtest-apim-get-list.txt

echo ""
sleep 2

# Test 3: Full traffic distribution (40% POST, 30% GET list, 20% GET item, 10% DELETE)
print_info "Test 3/4: Full traffic distribution simulation"
print_info "Running POST requests (40% of load)..."
$HEY_CMD -z ${DURATION}s -q $((RPS * 4 / 10)) -c $((WORKERS * 4 / 10 + 1)) \
    -m POST \
    -H "Content-Type: application/json" \
    -H "$APIM_HEADER" \
    -d '{"name":"Full Load Item","quantity":75}' \
    "$APIM_URL/items" > /tmp/loadtest-apim-dist-post.txt &
POST_PID=$!

print_info "Running GET list requests (30% of load)..."
$HEY_CMD -z ${DURATION}s -q $((RPS * 3 / 10)) -c $((WORKERS * 3 / 10 + 1)) \
    -m GET \
    -H "$APIM_HEADER" \
    "$APIM_URL/items" > /tmp/loadtest-apim-dist-get-list.txt &
GET_LIST_PID=$!

print_info "Running GET item requests (20% of load)..."
$HEY_CMD -z ${DURATION}s -q $((RPS * 2 / 10)) -c $((WORKERS * 2 / 10 + 1)) \
    -m GET \
    -H "$APIM_HEADER" \
    "$APIM_URL/items/1" > /tmp/loadtest-apim-dist-get-item.txt &
GET_ITEM_PID=$!

print_info "Running DELETE requests (10% of load)..."
$HEY_CMD -z ${DURATION}s -q $((RPS * 1 / 10)) -c $((WORKERS * 1 / 10 + 1)) \
    -m DELETE \
    -H "$APIM_HEADER" \
    "$APIM_URL/items/999" > /tmp/loadtest-apim-dist-delete.txt &
DELETE_PID=$!

# Wait for all processes
wait $POST_PID
wait $GET_LIST_PID
wait $GET_ITEM_PID
wait $DELETE_PID

print_info "Full distribution test completed"
echo "POST (40%):"
cat /tmp/loadtest-apim-dist-post.txt | grep -E "Status|Requests/sec|Latency|Slowest"
echo ""
echo "GET List (30%):"
cat /tmp/loadtest-apim-dist-get-list.txt | grep -E "Status|Requests/sec|Latency|Slowest"
echo ""
echo "GET Item (20%):"
cat /tmp/loadtest-apim-dist-get-item.txt | grep -E "Status|Requests/sec|Latency|Slowest"
echo ""
echo "DELETE (10%):"
cat /tmp/loadtest-apim-dist-delete.txt | grep -E "Status|Requests/sec|Latency|Slowest"
echo ""

# Test 4: Spike test (burst of traffic)
print_info "Test 4/4: Spike test (burst of ${WORKERS} concurrent requests)"
$HEY_CMD -n 100 -c $WORKERS \
    -m GET \
    -H "$APIM_HEADER" \
    "$APIM_URL/items" | tee /tmp/loadtest-apim-spike.txt

echo ""
print_info "Load testing complete!"
print_info "Results saved to /tmp/loadtest-apim-*.txt"
print_info ""
print_info "Full results can be viewed with:"
echo "  cat /tmp/loadtest-apim-dist-post.txt"
echo "  cat /tmp/loadtest-apim-dist-get-list.txt"
echo "  cat /tmp/loadtest-apim-dist-get-item.txt"
echo "  cat /tmp/loadtest-apim-dist-delete.txt"

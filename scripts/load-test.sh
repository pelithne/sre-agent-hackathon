#!/bin/bash

# Simple load testing script for the Items API
# This script uses 'hey' (a modern HTTP load generator) to generate load
# Installation: go install github.com/rakyll/hey@latest
# Or use the docker version if you don't have Go installed

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

# Check if API URL is provided
if [ -z "$API_URL" ]; then
    print_error "API_URL environment variable is required"
    echo "Usage: API_URL=https://your-api.azurecontainerapps.io ./load-test.sh"
    exit 1
fi

# Remove trailing slash from API_URL if present
API_URL=${API_URL%/}

print_info "Load Test Configuration:"
echo "  API URL: $API_URL"
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

# Test 1: POST /items (Create items)
print_info "Test 1/4: Creating items (POST /items)"
$HEY_CMD -z ${DURATION}s -q $RPS -c $WORKERS \
    -m POST \
    -H "Content-Type: application/json" \
    -d '{"name":"LoadTest Item","quantity":100}' \
    "$API_URL/items" | tee /tmp/loadtest-post.txt

echo ""
sleep 2

# Test 2: GET /items (List items)
print_info "Test 2/4: Listing items (GET /items)"
$HEY_CMD -z ${DURATION}s -q $RPS -c $WORKERS \
    -m GET \
    "$API_URL/items" | tee /tmp/loadtest-get-list.txt

echo ""
sleep 2

# Test 3: Mixed load (70% GET, 30% POST)
print_info "Test 3/4: Mixed load simulation"
print_info "Running GET requests (70% of load)..."
$HEY_CMD -z ${DURATION}s -q $((RPS * 7 / 10)) -c $((WORKERS * 7 / 10)) \
    -m GET \
    "$API_URL/items" > /tmp/loadtest-mixed-get.txt &
GET_PID=$!

print_info "Running POST requests (30% of load)..."
$HEY_CMD -z ${DURATION}s -q $((RPS * 3 / 10)) -c $((WORKERS * 3 / 10)) \
    -m POST \
    -H "Content-Type: application/json" \
    -d '{"name":"Mixed Load Item","quantity":50}' \
    "$API_URL/items" > /tmp/loadtest-mixed-post.txt &
POST_PID=$!

# Wait for both processes
wait $GET_PID
wait $POST_PID

print_info "Mixed load test completed"
cat /tmp/loadtest-mixed-get.txt
echo ""
cat /tmp/loadtest-mixed-post.txt
echo ""

# Test 4: Spike test (burst of traffic)
print_info "Test 4/4: Spike test (burst of ${WORKERS} concurrent requests)"
$HEY_CMD -n 100 -c $WORKERS \
    -m GET \
    "$API_URL/items" | tee /tmp/loadtest-spike.txt

echo ""
print_info "Load testing complete!"
print_info "Results saved to /tmp/loadtest-*.txt"

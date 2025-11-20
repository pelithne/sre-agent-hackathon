# Command-Line Load Testing

This directory contains scripts for performing load testing against the Items API via Azure APIM from your local machine or CI/CD pipeline.

## Overview

The load testing approach uses external CLI tools to generate HTTP traffic **outside** the monitored Azure infrastructure. This ensures that:

- Load testing doesn't consume Azure Container App resources
- Test infrastructure is not monitored by the SRE agent
- Tests can run from developer workstations or CI/CD pipelines
- Simple, flexible, and easy to understand

## Prerequisites

You need to install `hey` (HTTP load generator) from the official repository: https://github.com/rakyll/hey

### Installation (Azure Cloud Shell or any Linux environment)

```bash
# Download pre-built binary
wget https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64

# Make it executable
chmod +x hey_linux_amd64

# Create ~/bin directory and move hey there
mkdir -p ~/bin
mv hey_linux_amd64 ~/bin/hey

# Add to PATH (add this to your ~/.bashrc or ~/.zshrc to make it permanent)
export PATH=$PATH:~/bin

# Verify installation
hey -version
```

**Note:** The `hey` binary is from the official repository: https://github.com/rakyll/hey

### Other Platforms

```bash
# macOS
brew install hey

# Linux/WSL with Go installed
go install github.com/rakyll/hey@latest

# Windows with Go installed
go install github.com/rakyll/hey@latest
```

## Scripts

### 1. `get-apim-credentials.sh`

Retrieves APIM URL and subscription key from Azure.

**Usage:**

```bash
chmod +x scripts/get-apim-credentials.sh
./scripts/get-apim-credentials.sh
```

**Output:**

```bash
export APIM_URL="https://your-apim.azure-api.net"
export APIM_KEY="your-subscription-key"
```

### 2. `load-test.sh`

Basic load testing against the API directly (without APIM).

**Usage:**

```bash
chmod +x scripts/load-test.sh

# Basic usage
API_URL=https://your-api.azurecontainerapps.io ./scripts/load-test.sh

# With custom parameters
API_URL=https://your-api.azurecontainerapps.io \
DURATION=120 \
RPS=20 \
WORKERS=10 \
./scripts/load-test.sh
```

**Parameters:**

- `API_URL` (required): The API endpoint URL
- `DURATION` (default: 60): Test duration in seconds
- `RPS` (default: 10): Target requests per second
- `WORKERS` (default: 5): Number of concurrent workers

### 3. `load-test-apim.sh`

Load testing via Azure APIM with proper authentication.

**Usage:**

```bash
chmod +x scripts/load-test-apim.sh

# First, get credentials
eval $(./scripts/get-apim-credentials.sh | grep export)

# Then run load test
./scripts/load-test-apim.sh

# Or in one command
APIM_URL="https://your-apim.azure-api.net" \
APIM_KEY="your-subscription-key" \
DURATION=90 \
RPS=15 \
WORKERS=8 \
./scripts/load-test-apim.sh
```

**Parameters:**

- `APIM_URL` (required): APIM gateway URL
- `APIM_KEY` (required): APIM subscription key
- `DURATION` (default: 60): Test duration in seconds
- `RPS` (default: 10): Target requests per second
- `WORKERS` (default: 5): Number of concurrent workers

## Load Test Scenarios

The `load-test-apim.sh` script runs 4 different test scenarios:

### Test 1: POST Requests

Creates new items via `POST /items`

- Duration: Configurable (default 60s)
- RPS: Configurable (default 10)
- Headers: APIM subscription key
- Body: `{"name":"LoadTest Item via APIM","quantity":100}`

### Test 2: GET List Requests

Retrieves all items via `GET /items`

- Duration: Configurable (default 60s)
- RPS: Configurable (default 10)
- Headers: APIM subscription key

### Test 3: Full Traffic Distribution

Simulates realistic traffic patterns with concurrent requests:

- **40% POST** `/items` - Create items
- **30% GET** `/items` - List all items
- **20% GET** `/items/{id}` - Get specific item
- **10% DELETE** `/items/{id}` - Delete item

This runs all four request types in parallel for the configured duration.

### Test 4: Spike Test

Burst of concurrent requests to test peak load handling:

- 100 total requests
- Concurrent workers (configurable)
- `GET /items` endpoint

## Example Workflow

```bash
# 1. Make scripts executable
chmod +x scripts/*.sh

# 2. Get APIM credentials
./scripts/get-apim-credentials.sh

# 3. Export the credentials
export APIM_URL="https://srepeter11-dev-apim-k7irm5zhslxac.azure-api.net"
export APIM_KEY="your-actual-key-here"

# 4. Run a light load test (60s, 10 RPS)
./scripts/load-test-apim.sh

# 5. Run a heavier load test (120s, 30 RPS, 15 workers)
DURATION=120 RPS=30 WORKERS=15 ./scripts/load-test-apim.sh

# 6. Run a spike test
DURATION=30 RPS=50 WORKERS=20 ./scripts/load-test-apim.sh
```

## Reading Results

Each test saves results to `/tmp/loadtest-apim-*.txt`. The output includes:

- **Status code distribution**: HTTP response codes (200, 201, 404, 500, etc.)
- **Requests/sec**: Actual achieved request rate
- **Latency distribution**: Average, 50th, 95th, 99th percentiles
- **Slowest/Fastest requests**: Min/max response times
- **Error rate**: Percentage of failed requests

**Example output:**

```
Summary:
  Total:        60.1234 secs
  Slowest:      0.5432 secs
  Fastest:      0.0123 secs
  Average:      0.0456 secs
  Requests/sec: 9.98
  
Status code distribution:
  [201] 599 responses
  [200] 1 responses
```

## Monitoring During Load Tests

While running load tests, you can monitor the impact using:

1. **Azure Portal**: Monitor Container App metrics (CPU, memory, requests)
2. **Chaos Dashboard**: Visit `/admin/chaos` to see real-time metrics
3. **Application Insights**: Check request rates, response times, failures
4. **APIM Analytics**: Review API usage and performance through APIM

## CI/CD Integration

These scripts can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run Load Test
  env:
    APIM_URL: ${{ secrets.APIM_URL }}
    APIM_KEY: ${{ secrets.APIM_KEY }}
  run: |
    chmod +x scripts/load-test-apim.sh
    DURATION=30 RPS=20 ./scripts/load-test-apim.sh
```

## Troubleshooting

### `hey` command not found

Install `hey` using the instructions in Prerequisites, or ensure Docker is installed for the fallback.

### APIM authentication errors (401)

Verify your APIM subscription key:

```bash
./scripts/get-apim-credentials.sh
```

### Low actual RPS vs target RPS

This can happen if:
- The API is slow to respond (increase `WORKERS`)
- Network latency is high
- The API is throttling requests

Try increasing `WORKERS` to allow more concurrent connections.

### Connection refused

Ensure the APIM URL is correct and accessible:

```bash
curl -H "Ocp-Apim-Subscription-Key: $APIM_KEY" "$APIM_URL/items"
```

## Alternative Tools

If `hey` doesn't meet your needs, consider:

- **Apache Bench (ab)**: `ab -n 1000 -c 10 https://api-url/items`
- **wrk**: More advanced scripting with Lua
- **JMeter CLI**: Reusable test plans but requires Java
- **Custom Python script**: Using `requests` library with threading

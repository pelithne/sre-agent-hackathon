# Chaos Engineering Guide

## Overview

The Workshop API includes built-in chaos engineering capabilities that allow you to simulate various failure scenarios without redeploying the application. This guide explains how to use these features for SRE training and troubleshooting exercises.

## Architecture

### Endpoint Separation

The API has two distinct endpoint groups:

1. **Business APIs** (`/api/*`) - Exposed through APIM
   - Subject to chaos fault injection
   - Accessible via APIM gateway URL with subscription key
   - Examples: `/api/items`, `/api/items/{id}`

2. **Admin/Chaos APIs** (`/admin/*`) - Internal to Container App only
   - **NOT** exposed through APIM
   - Accessible only via direct Container App URL
   - Used for controlling fault injection
   - Examples: `/admin/chaos`, `/admin/chaos/status`

## Available Chaos Faults

### 1. Memory Leak
**Description:** Allocates memory that won't be freed, simulating memory leaks.

**Intensity:** KB of memory leaked per request (1-100)

**Use Case:** Practice diagnosing OOM (Out of Memory) issues

**Effects:**
- Container memory usage increases over time
- Eventually triggers OOM killer
- Container restarts

### 2. CPU Spike
**Description:** Spawns background thread that burns CPU cycles.

**Intensity:** CPU utilization percentage (1-100)

**Use Case:** Practice diagnosing high CPU usage

**Effects:**
- Container CPU metrics spike
- Response times may increase
- Affects container health scores

### 3. Random Errors
**Description:** Returns HTTP 500 errors randomly.

**Intensity:** Error rate percentage (1-100)

**Use Case:** Practice error rate investigation

**Effects:**
- Intermittent failures
- Error logs in Application Insights
- Affects success rate metrics

### 4. Slow Responses
**Description:** Adds artificial delay to all requests.

**Intensity:** Delay in seconds (1-100)

**Use Case:** Practice diagnosing latency issues

**Effects:**
- Increased response times
- Potential timeout errors
- P95/P99 latency spikes

### 5. Connection Leak
**Description:** Database connections opened but not closed properly.

**Intensity:** Leak probability percentage (1-100)

**Use Case:** Practice diagnosing connection pool exhaustion

**Effects:**
- PostgreSQL connection count increases
- Eventually hits max_connections limit
- New requests fail with "too many connections"

### 6. Corrupt Data
**Description:** Returns malformed JSON responses instead of valid data.

**Intensity:** Corruption rate percentage (1-100)

**Use Case:** Practice diagnosing data integrity issues

**Effects:**
- Invalid JSON responses
- Client parsing errors
- Difficult to reproduce bugs

## Accessing the Chaos Dashboard

### Step 1: Get Container App URL

```bash
# Get the Container App FQDN (direct URL, not APIM)
CONTAINER_APP_URL=$(az containerapp show \
  --name ${BASE_NAME}-dev-api \
  --resource-group ${RESOURCE_GROUP} \
  --query "properties.configuration.ingress.fqdn" -o tsv)

echo "Container App URL: https://${CONTAINER_APP_URL}"
```

### Step 2: Open the Dashboard

Navigate to: `https://${CONTAINER_APP_URL}/admin/chaos`

The dashboard provides:
- Visual status of all faults (ACTIVE/INACTIVE)
- Enable/Disable buttons for each fault
- Intensity sliders
- Auto-refresh every 5 seconds

## Using the Chaos API Programmatically

### Get Current Status

```bash
curl https://${CONTAINER_APP_URL}/admin/chaos/status | jq .
```

Example response:
```json
{
  "memory_leak": {
    "enabled": false,
    "intensity": 50,
    "leak_data": []
  },
  "cpu_spike": {
    "enabled": false,
    "intensity": 50,
    "thread": null
  },
  "random_errors": {
    "enabled": false,
    "intensity": 30
  },
  "slow_responses": {
    "enabled": false,
    "intensity": 3.0
  },
  "connection_leak": {
    "enabled": false,
    "intensity": 50,
    "leaked_connections": []
  },
  "corrupt_data": {
    "enabled": false,
    "intensity": 20
  }
}
```

### Enable a Fault

```bash
# Enable random errors with 50% error rate
curl -X POST https://${CONTAINER_APP_URL}/admin/chaos/random_errors/enable \
  -H "Content-Type: application/json" \
  -d '{"enabled": true, "intensity": 50}'
```

### Disable a Fault

```bash
# Disable random errors
curl -X POST https://${CONTAINER_APP_URL}/admin/chaos/random_errors/disable \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}'
```

### Disable All Faults

```bash
# Emergency stop - disable everything
curl -X POST https://${CONTAINER_APP_URL}/admin/chaos/disable-all \
  -H "Content-Type: application/json" \
  -d '{}'
```

## Workshop Exercise Examples

### Exercise 1: Diagnosing High Error Rates

**Scenario:** Enable random errors at 30% rate

```bash
# Enable the fault
curl -X POST https://${CONTAINER_APP_URL}/admin/chaos/random_errors/enable \
  -H "Content-Type: application/json" \
  -d '{"enabled": true, "intensity": 30}'

# Test through APIM (will experience errors)
for i in {1..10}; do
  curl -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_GATEWAY_URL/api/items"
  echo ""
done
```

**Investigation Steps:**
1. Ask SRE Agent about high error rates
2. Check Application Insights for error patterns
3. View Container App logs
4. Identify the chaos fault is active
5. Disable the fault
6. Verify error rate returns to normal

### Exercise 2: Memory Leak Investigation

**Scenario:** Enable memory leak with 10MB per request

```bash
# Enable memory leak (10MB = intensity 10240)
curl -X POST https://${CONTAINER_APP_URL}/admin/chaos/memory_leak/enable \
  -H "Content-Type: application/json" \
  -d '{"enabled": true, "intensity": 10240}'

# Generate traffic to trigger leak
for i in {1..20}; do
  curl -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_GATEWAY_URL/api/items"
done
```

**Investigation Steps:**
1. Monitor container memory metrics in Azure Portal
2. Ask SRE Agent about increasing memory usage
3. Check for memory leak patterns
4. Review Container App restart events
5. Disable the fault and observe memory stabilization

### Exercise 3: Connection Pool Exhaustion

**Scenario:** Enable connection leak at 80% rate

```bash
# Enable connection leak
curl -X POST https://${CONTAINER_APP_URL}/admin/chaos/connection_leak/enable \
  -H "Content-Type: application/json" \
  -d '{"enabled": true, "intensity": 80}'

# Generate traffic
for i in {1..50}; do
  curl -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_GATEWAY_URL/api/items" &
done
wait
```

**Investigation Steps:**
1. Monitor PostgreSQL connection count
2. Observe "too many connections" errors
3. Ask SRE Agent for troubleshooting guidance
4. Check database connection metrics
5. Disable fault and observe connection cleanup

## Best Practices

### 1. Start with Low Intensity
Begin with low intensity values (10-30%) and gradually increase to understand impact.

### 2. Monitor Before and After
Always establish baseline metrics before enabling faults.

### 3. Use the Dashboard
The visual dashboard is easier than curl commands for interactive learning.

### 4. Document Findings
Record what metrics changed when each fault was enabled.

### 5. Clean Up After Exercises
Always disable all faults after completing an exercise:

```bash
curl -X POST https://${CONTAINER_APP_URL}/admin/chaos/disable-all \
  -H "Content-Type: application/json" \
  -d '{}'
```

### 6. Verify Cleanup
Check that faults are disabled:

```bash
curl https://${CONTAINER_APP_URL}/admin/chaos/status | jq '.[] | select(.enabled == true)'
```

This should return empty if all faults are disabled.

## Troubleshooting the Chaos System

### Fault Won't Enable

**Check:** Container App logs for errors
```bash
az containerapp logs show \
  --name ${BASE_NAME}-dev-api \
  --resource-group ${RESOURCE_GROUP} \
  --tail 50
```

### Dashboard Not Loading

**Check:** Container App is running
```bash
az containerapp show \
  --name ${BASE_NAME}-dev-api \
  --resource-group ${RESOURCE_GROUP} \
  --query "properties.runningStatus"
```

### Fault Persists After Disable

**Solution:** Restart the Container App
```bash
az containerapp restart \
  --name ${BASE_NAME}-dev-api \
  --resource-group ${RESOURCE_GROUP}
```

Note: This will clear all in-memory fault state.

## Security Considerations

### Admin Endpoints are Internal Only

The `/admin/*` endpoints are **NOT** configured in APIM, so they:
- Cannot be accessed through the APIM gateway URL
- Require direct access to Container App
- Are not exposed to public internet (if Container App ingress is internal)

### For Production Use

If deploying to production, consider:
- Adding authentication to admin endpoints
- Restricting access via IP allowlisting
- Using Azure Private Link
- Implementing role-based access control

## Advanced Scenarios

### Combining Multiple Faults

```bash
# Enable multiple faults simultaneously
curl -X POST https://${CONTAINER_APP_URL}/admin/chaos/random_errors/enable \
  -d '{"enabled": true, "intensity": 20}'

curl -X POST https://${CONTAINER_APP_URL}/admin/chaos/slow_responses/enable \
  -d '{"enabled": true, "intensity": 2}'

curl -X POST https://${CONTAINER_APP_URL}/admin/chaos/memory_leak/enable \
  -d '{"enabled": true, "intensity": 5120}'
```

This creates a realistic "everything is broken" scenario for advanced troubleshooting practice.

### Scheduled Fault Injection

Use cron jobs or Azure Logic Apps to enable/disable faults on a schedule:

```bash
# Example: Enable random errors every hour for 10 minutes
# (This would be run from a scheduled task)
curl -X POST https://${CONTAINER_APP_URL}/admin/chaos/random_errors/enable \
  -d '{"enabled": true, "intensity": 40}'

sleep 600  # 10 minutes

curl -X POST https://${CONTAINER_APP_URL}/admin/chaos/random_errors/disable \
  -d '{"enabled": false}'
```

## Next Steps

After mastering chaos engineering basics:
1. Practice with Azure SRE Agent to diagnose fault-induced issues
2. Create custom monitoring alerts for each fault type
3. Document runbooks for each failure scenario
4. Conduct chaos game days with your team

---

**Remember:** Chaos engineering is about building confidence in system resilience. Always ensure you can quickly disable faults and restore normal operation.

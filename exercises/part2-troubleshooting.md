# Part 2: SRE Agent Troubleshooting with Chaos Engineering

## Overview

In this exercise, you'll learn how to use Azure SRE Agent to diagnose and fix common issues in cloud applications. Azure SRE Agent is an AI-powered reliability assistant that helps teams diagnose and resolve production issues, reduce operational toil, and lower mean time to resolution (MTTR).

You'll use the **Chaos Engineering Dashboard** to simulate realistic failure scenarios, then work with Azure SRE Agent to investigate and resolve each issue. This hands-on approach mirrors real-world incident response.

**Estimated Time:** 60-90 minutes

## Prerequisites

- Completed [Part 1: Setup](./part1-setup.md)
- Working infrastructure with API deployed
- Azure account with appropriate permissions
- Environment variables from Part 1 (see below)

### Load Environment Variables

If you're in a new terminal session, reload the environment variables from Part 1:

```bash
# Load the workshop environment helper and variables
source scripts/workshop-env.sh

# This will automatically:
# - Load all saved variables from ~/.workshop-env
# - Display current workshop variables
# - Provide helper functions for managing variables
```

If variables are missing, you can manually set them:

```bash
# Set variables manually if needed
set_var "BASE_NAME" "sre<your-initials>"
set_var "RESOURCE_GROUP" "${BASE_NAME}-workshop"
set_var "APIM_GATEWAY_URL" "<your-apim-gateway-url>"
set_var "SUBSCRIPTION_KEY" "<your-subscription-key>"

# Verify all required variables are set
verify_vars
```

## Learning Objectives

By the end of this exercise, you will:
- Create and configure an Azure SRE Agent
- Use the Chaos Engineering Dashboard to simulate failures
- Leverage SRE Agent to diagnose issues using natural language
- Troubleshoot random errors, slow responses, memory leaks, and CPU spikes
- Practice real-world incident response workflows
- Master Azure diagnostic patterns with AI assistance

---

## Setup: Create Azure SRE Agent

Before starting the troubleshooting exercises, you need to create an Azure SRE Agent instance.

### Step 1: Register Microsoft.App Namespace

```bash
az provider register --namespace "Microsoft.App"
```

### Step 2: Create the Agent

1. Navigate to the [Azure Portal](https://aka.ms/sreagent/portal)
2. Click **Create**
3. Fill in the agent details:
   - **Subscription**: Your Azure subscription
   - **Resource Group**: Create a new one (e.g., `${BASE_NAME}-sre-agent-rg`)
   - **Agent name**: Choose a name (e.g., `${BASE_NAME}-sre-agent`)
   - **Region**: Select **East US 2**, **Sweden Central**, or **Australia East**

4. Click **Choose resource groups**
5. Search for and select your workshop resource group (`${BASE_NAME}-workshop`)
6. Click **Save**
7. Click **Create**

> **Note**: The agent can monitor resources in any Azure region, but the agent itself must be deployed in one of the supported regions.

### Step 3: Access the Agent Chat

Once deployment completes:

1. Go to **Azure SRE Agent** in the Azure Portal
2. Select your agent from the list
3. The chat interface will open

Test it with: `What can you help me with?`

### Step 4: Access the Chaos Dashboard

Open the Chaos Engineering Dashboard to simulate failures:

```bash
# Get the Container App URL
CONTAINER_APP_URL=$(az containerapp show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --query "properties.configuration.ingress.fqdn" -o tsv)

echo "Chaos Dashboard: https://${CONTAINER_APP_URL}/admin/chaos"
```

Open this URL in your browser. You'll see the 🔥 Chaos Engineering Dashboard with 6 fault types:
- Memory Leak
- CPU Spike
- Memory Leak
- CPU Spike
- Slow Responses
- Random Errors
- Corrupt Data
- Connection Leak

---

## Exercise 1: Memory Leak Detectiontion

### Scenario

The Container App is consuming increasing amounts of memory and eventually crashes or becomes unresponsive.

### Your Task

Simulate a memory leak and use SRE Agent to diagnose the issue.

### Step 1: Enable Memory Leak

1. Open the Chaos Engineering Dashboard
2. Find the **Memory Leak** card
3. Set the intensity slider to **10** minutes (memory will leak to 95% over 10 minutes)
4. Click **Enable**

### Step 2: Monitor Memory Consumption

Watch the memory grow over time. Ask SRE Agent to help you monitor:

```
My Container App (<your-base-name>-dev-api) seems to be consuming 
increasing amounts of memory. How can I monitor its memory usage in real-time?
```

The agent will guide you to check Container App metrics or use Azure Monitor.

### Step 3: Check Application Logs

After a minute or two, ask SRE Agent to check the logs:

```
I'm seeing high memory usage in my Container App. Can you check the application 
logs for any memory-related messages? The app is <your-base-name>-dev-api in 
resource group <your-base-name>-workshop.
```

The SRE Agent may find log messages like:
- "Memory allocated: 500 MB / 972 MB (51%)"
- "Allocating memory buffer: targeting X GB over Y minutes"

Follow up with:

```
The logs show progressive memory allocation messages. This looks like memory 
is being intentionally allocated. How should I investigate what's causing this 
memory growth in a production environment?
```

The SRE Agent will provide guidance on:
- Checking container memory limits
- Reviewing memory metrics in Azure Monitor
- Understanding OOM (Out of Memory) kill scenarios
- Best practices for memory management

### Step 4: Disable the Memory Leak

1. Return to the Chaos Engineering Dashboard
2. Find the **Memory Leak** card
3. Click **Disable**
4. Observe the memory being released (logs will show "Releasing allocated memory buffers")

### Step 5: Verify Memory Returns to Normal

Ask SRE Agent:

```
I've disabled the memory leak chaos fault. How can I verify that memory 
usage has returned to normal levels?
```

### Key Learnings

- **Memory leaks grow over time**: Unlike CPU spikes, memory issues are gradual
- **Container memory limits protect the system**: Azure Container Apps enforce memory limits
- **Gradual failures are harder to detect**: Time-based issues require monitoring trends
- **Chaos helps test monitoring**: Memory leak simulation validates your alerting setup
- **SRE Agent guides remediation**: Even for simulated issues, best practices apply

---

## Exercise 2: High CPU Utilization

### Scenario

The API is experiencing high CPU usage, causing slow responses and potential throttling.

### Your Task

Simulate CPU pressure and diagnose with SRE Agent.

### Step 1: Enable CPU Spike

1. Open the Chaos Engineering Dashboard
2. Find the **CPU Spike** card
3. Set the intensity slider to **80%** (80% CPU utilization)
4. Click **Enable**

### Step 2: Observe Performance Impact

Test the API - you may notice slightly slower responses:

```bash
for i in {1..5}; do
  curl -w "Request $i - Time: %{time_total}s\n" -o /dev/null -s \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_GATEWAY_URL/api/items"
done
```

### Step 3: Investigate with SRE Agent

```
My Container App (<your-base-name>-dev-api) is showing high CPU usage.
How can I investigate what's causing the CPU spike and whether it's impacting performance?
```

**Follow-up after the agent suggests checking logs:**

```
I'm seeing high CPU usage in the metrics. The application logs don't show obvious 
errors at INFO level. What are common causes of high CPU in production and how 
would I troubleshoot them?
```

> Note: The chaos fault logs at DEBUG level ("Background processing thread started"), so they won't appear in standard log queries. This simulates a real-world scenario where CPU issues might not have obvious log indicators.

The SRE Agent will provide insights on:
- Inefficient algorithms or code
- Missing database indexes causing full table scans
- Excessive logging or serialization
- Auto-scaling triggers based on CPU
- Right-sizing container resources

### Step 4: Disable CPU Spike

1. Return to the Chaos Engineering Dashboard
2. Find the **CPU Spike** card
3. Click **Disable**

### Step 5: Verify CPU Returns to Normal

```bash
# Responses should be consistently fast
for i in {1..5}; do
  curl -w "Request $i - Time: %{time_total}s\n" -o /dev/null -s \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_GATEWAY_URL/api/items"
done
```

### Key Learnings

- **CPU affects all requests**: Unlike memory leaks, CPU pressure impacts every operation
- **Background threads can cause CPU spikes**: The chaos fault uses a background thread to burn CPU
- **Monitoring CPU trends is critical**: Sustained high CPU indicates scaling or optimization needs
- **Auto-scaling responds to CPU**: Container Apps can scale based on CPU metrics
- **SRE Agent connects symptoms to causes**: High CPU leads to exploration of code efficiency, database queries, and resource allocation

---

## Exercise 3: Slow API Response Times

### Scenario

Users report that the API is extremely slow, with response times of 5-10 seconds instead of the normal sub-200ms performance.

### Your Task

Use the Chaos Dashboard to simulate slow responses, then diagnose with SRE Agent.

### Step 1: Enable Slow Responses

1. Open the Chaos Engineering Dashboard
2. Find the **Slow Responses** card
3. Set the intensity slider to **5** seconds
4. Click **Enable**

### Step 2: Measure Current Performance

Test the response time - it should be very slow:

```bash
# Measure response time (look at the time_total)
curl -w "\nTime: %{time_total}s\n" -o /dev/null -s \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_GATEWAY_URL/api/items"
```

Run this a few times. You should see response times around 5+ seconds.

### Step 3: Investigate with SRE Agent

Ask the SRE Agent for help:

```
My API (<your-base-name>-dev-api in resource group <your-base-name>-workshop) is experiencing severe performance issues.
Response times are 5-10 seconds when they should be under 200ms.
How should I investigate what's causing the slowdown?
```

**What to expect:**
- Agent will suggest checking Application Insights for slow operations
- May recommend reviewing Container App logs
- Could suggest examining database performance metrics

**Follow-up after reviewing logs:**

```
I'm seeing consistent 5+ second response times. The application logs at INFO level 
don't show obvious delays. What could cause systematic slowness like this?
```

> Note: The chaos fault logs at DEBUG level ("Processing request: 5s"), simulating scenarios where slow operations might not be immediately obvious in logs.

### Step 4: Disable the Slow Response Fault

1. Return to the Chaos Engineering Dashboard
2. Find the **Slow Responses** card
3. Click **Disable**

### Step 5: Verify Performance Restored

Test again - response time should be fast:

```bash
# Should complete in under 200ms
curl -w "\nTime: %{time_total}s\n" -o /dev/null -s \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_GATEWAY_URL/api/items"
```

### Step 6: Ask SRE Agent About Performance Best Practices

```
Now that I've disabled the chaos fault, what are best practices for monitoring 
and preventing real performance issues in Azure Container Apps?
```

The agent will provide recommendations on:
- Setting up Application Insights alerts for slow responses
- Configuring appropriate CPU/memory resources
- Using auto-scaling effectively
- Avoiding cold starts with min replicas

### Key Learnings

- **Performance degradation is immediately observable**: Response time measurements make issues obvious
- **SRE Agent correlates symptoms with causes**: Describing slow performance leads to targeted diagnostics
- **Chaos faults simulate realistic scenarios**: Slow responses mirror network latency, overloaded databases, or inefficient code
- **Quick toggles enable rapid testing**: Dashboard allows instant enable/disable for testing alert thresholds
- **Baseline metrics matter**: Knowing normal performance (< 200ms) helps identify anomalies

---

## Exercise 4: Random API Errors

### Scenario

Users are reporting intermittent 500 Internal Server Error responses from the API. Some requests succeed, others fail randomly.

### Your Task

Use the Chaos Dashboard to simulate random errors, then investigate with SRE Agent.

### Step 1: Enable Random Errors

1. Open the Chaos Engineering Dashboard in your browser
2. Find the **Random Errors** card
3. Set the intensity slider to **50%** (50% error rate)
4. Click **Enable**
5. Observe the status change to **ACTIVE**

### Step 2: Reproduce the Issue

Test the API multiple times - you should see intermittent failures:

```bash
# Run several requests - about half should fail
for i in {1..10}; do
  echo "Request $i:"
  curl -s -X GET \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_GATEWAY_URL/api/items" | jq -r '.message // "Success"'
  echo ""
done
```

You should see a mix of successful responses and error messages like:
- "Internal server error"
- "Service temporarily unavailable"
- "Database connection timeout"

### Step 3: Investigate with SRE Agent

Open your Azure SRE Agent chat and describe the symptoms:

**Initial Query:**
```
I'm seeing intermittent 500 errors from my Container App API (<your-base-name>-dev-api in resource group <your-base-name>-workshop). 
About 50% of requests fail with various error messages like "Internal server error" and "Service temporarily unavailable".
The other 50% succeed normally. What's causing this random behavior?
```

> **Replace** `<your-base-name>` with your actual BASE_NAME.

**What to expect:**
- SRE Agent will suggest checking application logs for error patterns
- Follow the agent's commands to examine recent logs
- Look for error messages like "Request failed: Service temporarily unavailable"
- Notice the errors are logged but without a clear root cause
- Agent may suggest checking for recent deployments or configuration changes

**Continue the conversation:**

When the agent finds error patterns in the logs, ask:
```
The logs show "Request failed: [various error messages]" but no clear root cause. 
These errors are happening randomly - about 50% of requests.
How can I identify what's causing these intermittent failures?
```

**The agent should guide you to:**
- Analyze the error pattern (intermittent, percentage-based failures)
- Check application health and recent changes
- Review metrics for any correlations
- Eventually, you may discover the Chaos Dashboard shows an active fault

### Step 4: Disable the Chaos Fault

Return to the Chaos Engineering Dashboard and:
1. Find the **Random Errors** card
2. Click the **Disable** button
3. Observe the status change to **INACTIVE**

Alternatively, use the API to disable it:
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}' \
  "https://${CONTAINER_APP_URL}/admin/chaos/random_errors/disable"
```

### Step 5: Verify the Fix

Test the API again - all requests should now succeed:

```bash
# All 10 requests should succeed
for i in {1..10}; do
  echo "Request $i:"
  curl -s -X GET \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_GATEWAY_URL/api/items" | jq -r 'if type=="array" then "Success" else .message end'
done
```

### Key Learnings

- **SRE Agent accelerates log analysis**: Instead of manually searching logs, describe symptoms and let the agent find patterns
- **Chaos engineering creates safe testing**: Controlled failures help practice incident response
- **Error patterns matter**: Intermittent failures often indicate percentage-based chaos faults or resource exhaustion
- **Dashboard provides visibility**: The Chaos Dashboard shows active faults at a glance
- **Quick remediation**: Disabling chaos faults takes seconds, perfect for testing monitoring alerts

### Troubleshooting Pattern Applied

**SRE Agent-Guided Chaos Investigation**:
1. **Describe symptoms** (intermittent 500 errors, 50% failure rate)
2. **Let agent suggest diagnostics** (check logs for patterns)
3. **Share findings** (CHAOS logs discovered)
4. **Identify root cause** (active chaos fault)
5. **Remediate quickly** (disable via dashboard)
6. **Verify resolution** (all requests succeed)

---

## Exercise 5: Data Corruption Issues

### Scenario

Users report receiving corrupted or invalid JSON responses from the API intermittently.

### Your Task

Simulate data corruption and investigate.

### Step 1: Enable Data Corruption

1. Open the Chaos Engineering Dashboard
2. Find the **Corrupt Data** card
3. Set the intensity slider to **30%** (30% of responses will be corrupted)
4. Click **Enable**

### Step 2: Observe Corrupted Responses

Test the API multiple times:

```bash
for i in {1..10}; do
  echo "Request $i:"
  curl -s -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_GATEWAY_URL/api/items"
  echo ""
done
```

About 30% of responses will show:
```json
{
  "corrupted": true,
  "error": "Data corruption injected",
  "random": 0.12345
}
```

### Step 3: Investigate with SRE Agent

```
Users are reporting corrupted JSON responses from my API.
Some responses are valid, others contain unexpected fields like "corrupted": true.
How should I investigate this data integrity issue?
```

**After reviewing logs:**

```
The logs show "Response serialization error - data integrity issue detected" messages.
Some responses contain unexpected "corrupted": true fields.
What could cause data corruption or serialization errors in production?
```

The agent will discuss:
- Serialization/deserialization bugs
- Database encoding issues
- Cache corruption
- Middleware or proxy modifications
- Memory corruption (rare but possible)

### Step 4: Disable Data Corruption

1. Return to the Chaos Engineering Dashboard
2. Find the **Corrupt Data** card
3. Click **Disable**

### Step 5: Verify Data Integrity

All responses should now be valid:

```bash
for i in {1..5}; do
  curl -s -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_GATEWAY_URL/api/items" | jq 'type'
done
```

All should return `"array"` (valid item list).

### Key Learnings

- **Data corruption is critical**: Unlike performance issues, corrupted data affects application correctness
- **Intermittent corruption is hardest to debug**: Partial failures require careful log analysis
- **Middleware can modify responses**: The chaos fault intercepts responses at the middleware level
- **Client-side validation matters**: Applications should validate API responses
- **SRE Agent helps distinguish chaos from real issues**: Even simulated problems teach troubleshooting patterns

---

## Exercise 6: Connection Pool Exhaustion

### Scenario

After sustained load, the API starts failing with database connection errors.

### Your Task

Simulate connection leaks and diagnose with SRE Agent.

### Step 1: Enable Connection Leak

1. Open the Chaos Engineering Dashboard
2. Find the **Connection Leak** card
3. Set the intensity slider to **50%** (50% of database requests leak connections)
4. Click **Enable**

### Step 2: Generate Load

Make several requests to exhaust the connection pool:

```bash
# Generate sustained requests
for i in {1..20}; do
  curl -s -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_GATEWAY_URL/api/items" > /dev/null &
done
wait
```

### Step 3: Observe Connection Errors

After generating load, you may see connection errors. Ask SRE Agent:

```
My API is failing with database connection errors after load testing. 
Can you help me investigate connection pool issues?
```

The agent will guide you through:
- Checking for connection pool exhaustion errors
- Reviewing database connection limits
- Understanding proper connection management

> Note: Connection leak logs appear at DEBUG level ("Database connection allocated but not returned to pool"), simulating real scenarios where connection leaks aren't always explicitly logged.

### Step 4: Disable Connection Leak

1. Return to the Chaos Engineering Dashboard
2. Find the **Connection Leak** card  
3. Click **Disable**
4. Observe logs showing "Database connection cleanup completed"

### Step 5: Verify Connections Restored

The API should handle requests normally again:

```bash
curl -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_GATEWAY_URL/api/items" | jq 'length'
```

### Key Learnings

- **Connection leaks are resource exhaustion**: Similar to memory leaks but for network resources
- **Limits protect the database**: PostgreSQL enforces max_connections
- **Proper cleanup is essential**: Always close database connections in finally blocks
- **Load testing reveals leaks**: Connection issues appear under sustained traffic
- **SRE Agent provides code-level guidance**: The agent can suggest proper connection management patterns

---

## Best Practices for Using SRE Agent with Chaos Engineering

### 1. Describe Symptoms, Not Solutions

**Good:**
```
My API returns 500 errors about 50% of the time. The other 50% succeed normally.
Container App: <your-base-name>-dev-api in resource group <your-base-name>-workshop
```

**Less Effective:**
```
I think there's a chaos fault enabled
```

### 2. Share Relevant Log Excerpts

```
The logs show:
- "Request failed: Service temporarily unavailable" 
- "Memory allocated: 500 MB / 972 MB (51%)"
- "Response serialization error - data integrity issue detected"
What patterns do these indicate?
```

### 3. Understand Logging Levels

Some issues log at DEBUG level and won't appear in standard queries:
- High CPU from background threads
- Slow request processing delays  
- Connection leak tracking

This mirrors real-world scenarios where not all issues are explicitly logged.

### 3. Ask About Real-World Equivalents

```
I'm seeing these symptoms in my testing environment. In production, 
what are common causes of:
- Intermittent 500 errors
- Progressive memory growth
- High CPU with no obvious cause
- Slow database query performance
```

### 4. Request Best Practices

```
I've resolved this chaos fault. What monitoring should I set up 
to detect similar issues in production before users are impacted?
```

### 5. Use Chaos Faults for Alert Testing

```
I want to test my memory usage alerts. Can you help me configure 
an alert that triggers when memory exceeds 80%?
```

### 6. Discovering Active Chaos Faults

If you're struggling to identify the root cause, remember:
- Check the **Chaos Engineering Dashboard** at `https://<your-container-app-url>/admin/chaos`
- Active faults will show as **ACTIVE** status
- Some fault logs appear at DEBUG level (not visible in standard log queries)
- This simulates real-world scenarios where root causes aren't always obvious

---

## Advanced Challenge: Multi-Fault Scenario

### Scenario

Enable multiple chaos faults simultaneously:
- **Memory Leak**: 3 minutes
- **Slow Responses**: 2 seconds
- **Random Errors**: 20%

### Your Task

1. Enable all three faults via the dashboard
2. Ask SRE Agent how to prioritize investigation when multiple issues occur
3. Practice triaging by impact (availability vs. performance)
4. Disable faults in order of severity

**SRE Agent Query:**
```
My API is experiencing multiple problems:
- Some requests fail with 500 errors (about 20%)
- All successful requests take 2+ seconds
- CPU usage is very high

How should I triage and investigate these overlapping issues?
```

The agent will help you:
- Prioritize by user impact (availability > performance)
- Identify independent vs. cascading failures
- Create a systematic investigation plan
- Verify each fix independently

---

## Summary Checklist

After completing Part 2, you should be able to:

- [ ] Use the Chaos Engineering Dashboard to simulate failures
- [ ] Describe symptoms clearly to Azure SRE Agent
- [ ] Investigate random errors and identify chaos fault patterns
- [ ] Diagnose slow response times and performance degradation
- [ ] Monitor and troubleshoot memory leaks  
- [ ] Detect and resolve high CPU utilization
- [ ] Identify data corruption in API responses
- [ ] Understand connection pool exhaustion and management
- [ ] Triage multiple simultaneous issues
- [ ] Apply chaos engineering for proactive testing

---

## What's Next?

**[Part 3: Monitoring & Alerts](./part3-monitoring.md)** - Learn to set up proactive monitoring using the chaos faults to test alert configurations and incident response procedures.

---

## Additional Resources

- [Azure SRE Agent Documentation](https://learn.microsoft.com/en-us/azure/sre-agent/)
- [Chaos Engineering Principles](https://principlesofchaos.org/)
- [Azure Monitor Documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/)
- [Container Apps Troubleshooting](https://docs.microsoft.com/en-us/azure/container-apps/troubleshooting)

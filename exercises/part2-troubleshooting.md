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
- Investigate CPU performance issues with SRE Agent
- Troubleshoot complex multi-symptom production scenarios
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

Open this URL in your browser. You'll see the 🔥 Chaos Engineering Dashboard with fault types including:
- Memory Leak
- CPU Spike
- Slow Responses
- Random Errors
- Corrupt Data
- Connection Leak

---

## Exercise 1: High CPU Utilization Investigation

### Scenario

The API is experiencing high CPU usage over a sustained period. This exercise introduces you to Azure SRE Agent with a straightforward performance issue.

**Learning Focus**: Get familiar with SRE Agent by investigating a single, clear symptom.

### Your Task

Simulate a gradual CPU increase and diagnose with SRE Agent.

### Step 1: Enable CPU Spike

1. Open the Chaos Engineering Dashboard
2. Find the **CPU Spike** card
3. Set the intensity slider to **80%** (80% CPU utilization)
4. Click **Enable**

> **Note**: The CPU spike will gradually build up over approximately 10 minutes as the chaos fault initializes background processing threads.

### Step 2: Wait for CPU to Increase

Monitor the CPU utilization as it increases:

```bash
# Check current CPU metrics (wait a few minutes after enabling)
az monitor metrics list \
  --resource $(az containerapp show \
    --name ${BASE_NAME}-dev-api \
    --resource-group $RESOURCE_GROUP \
    --query id -o tsv) \
  --metric "UsageNanoCores" \
  --start-time $(date -u -d '10 minutes ago' '+%Y-%m-%dT%H:%M:%S') \
  --interval PT1M \
  --query 'value[0].timeseries[0].data[-5:]' \
  --output json \
  | jq -r '["TIMESTAMP","CPU_NANOCORES"], ["----------","-------------"], (.[] | [.timeStamp, (.average // 0 | round)]) | @tsv' \
  | column -t -s $'\t'
```

### Step 3: Investigate with SRE Agent

After a few minutes, when CPU usage is elevated, ask the SRE Agent:

```
My Container App (<your-base-name>-dev-api) is showing sustained high CPU usage around 80%.
How can I investigate what's causing the CPU spike and whether it's impacting performance?
```

> **Replace** `<your-base-name>` with your actual BASE_NAME.

**Follow-up questions to explore:**

```
I'm seeing high CPU usage in the metrics. The application logs don't show obvious 
errors at INFO level. What are common causes of high CPU in production and how 
would I troubleshoot them?
```

```
What Azure Container Apps features can help automatically handle high CPU scenarios?
```

**What to expect:**
- SRE Agent will suggest checking Container App metrics
- May recommend reviewing CPU-related logs (though chaos logs are at DEBUG level)
- Will discuss common causes: inefficient algorithms, missing indexes, excessive processing
- Should mention auto-scaling capabilities based on CPU metrics

> **Note**: The chaos fault logs at DEBUG level ("Worker thread initialized"), so it won't appear in standard INFO-level log queries. This simulates real-world scenarios where CPU issues might not have obvious log indicators—you must rely on metrics and profiling.

### Step 4: Learn About CPU-Based Auto-Scaling

Ask SRE Agent about preventing CPU issues:

```
How can I configure auto-scaling for my Container App to handle CPU spikes automatically?
```

### Step 5: Disable CPU Spike

1. Return to the Chaos Engineering Dashboard
2. Find the **CPU Spike** card
3. Click **Disable**

### Step 6: Verify CPU Returns to Normal

After disabling, CPU should gradually return to baseline (check metrics again using the command from Step 2).

### Key Learnings

- **SRE Agent accelerates diagnosis**: Describe symptoms in natural language instead of manual metric hunting
- **Metrics are essential**: CPU issues may not appear in application logs
- **Gradual issues require monitoring trends**: Unlike instant failures, CPU buildup needs time-series analysis
- **Auto-scaling responds to CPU**: Container Apps can scale replicas based on CPU metrics
- **Background processes can cause CPU spikes**: Not all CPU usage comes from request processing
- **SRE Agent connects symptoms to solutions**: From "high CPU" to exploring scaling, optimization, and resource allocation

---

## Exercise 2: Complex Multi-Symptom Investigation

### Scenario

Users are reporting serious API issues: some requests fail completely, others return corrupted data. This is a realistic production incident where multiple symptoms present simultaneously, requiring careful investigation and correlation.

**Learning Focus**: Practice investigating complex, multi-symptom failures that mirror real-world incidents.

### Prerequisites for This Exercise

#### Install the `hey` Load Testing Tool

If you haven't installed `hey` yet, install it now. The instruction below installs the tool in "your own" bin directory. This is so that it will work in **Azure Cloud Shell**.

```bash
# Create ~/bin directory if it doesn't exist
mkdir -p ~/bin

# Download hey
wget -O ~/bin/hey https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64

# Make it executable
chmod +x ~/bin/hey

# Add to PATH for current session
export PATH="$HOME/bin:$PATH"

# Verify installation
hey -version
```

> **Note**: This installation is compatible with Azure Cloud Shell and doesn't require sudo privileges.

### Step 1: Start Load Testing

Before introducing any faults, start a 15-minute load test to establish baseline traffic:

```bash
# Start load test (runs in background for 15 minutes)
./scripts/load-test-apim.sh --duration 900
```

> **Note**: The load test generates a traffic mix (POST 40%, GET list 30%, GET item 20%, DELETE 10%) at around 10 requests/second. 

### Step 2: Enable Multiple Faults

After the load test has been running for 1-2 minutes, introduce the faults:

1. Open the Chaos Engineering Dashboard
2. **Enable Random Errors**:
   - Find the **Random Errors** card
   - Set intensity to **30%** (30% of requests will fail)
   - Click **Enable**

3. **Enable Corrupt Data**:
   - Find the **Corrupt Data** card  
   - Set intensity to **20%** (20% of successful responses will be corrupted)
   - Click **Enable**

### Step 3: Let Traffic Run with Faults

**Wait 3-5 minutes** to let the load test generate enough traffic with the enabled faults. This creates the error patterns and corrupted responses that will appear in logs.

You can verify faults are active:

```bash
# Quick manual test to see errors
curl -s -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_GATEWAY_URL/api/items" | jq '.'
```

Run this several times—you should see a mix of:
- Successful responses (array of items)
- 500 errors with messages like "Database connection pool exhausted"
- Corrupted responses with unexpected fields

### Step 4: Investigate with SRE Agent

Now that you have traffic with both errors and corruption, ask SRE Agent for help:

**Initial Investigation:**
```
I'm experiencing serious issues with my API (<your-base-name>-dev-api in resource group <your-base-name>-workshop).
Users report:
- Many requests failing with 500 errors
- Some successful responses contain corrupted or invalid data
- This started happening in the last few minutes

Can you help me investigate what's causing these problems?
```

> **Replace** `<your-base-name>` with your actual BASE_NAME.

**What to expect:**
- SRE Agent will suggest checking recent logs
- Should find ERROR level messages like "Request failed: Database connection pool exhausted"
- May find "Data integrity error" messages in the logs
- Will help you identify patterns in the failures

**Follow-up with correlation questions:**

```
I see two different types of issues in the logs:
1. ERROR: "Request failed: Database connection pool exhausted" 
2. ERROR: "Data integrity error: Object of type 'Decimal' is not JSON serializable"

Are these related? Could they have a common root cause?
```

**Explore production scenarios:**

```
In a real production environment, what could cause both database errors AND 
data serialization issues to appear simultaneously? How would I determine 
if these are independent problems or symptoms of the same underlying issue?
```

**What to expect from SRE Agent:**
- Discussion of cascading failures (overloaded database causing both connection errors and data issues)
- Suggestions for checking database health and connection pool settings
- Recommendations to examine recent deployments or configuration changes
- Guidance on which issue to prioritize (availability vs. data integrity)

### Step 5: Ask About Mitigation Strategies

```
Given these combined symptoms (30% error rate and 20% data corruption), 
what immediate mitigation steps should I take while investigating the root cause?
```


### Step 6: Disable Faults

After completing your investigation:

1. Return to the Chaos Engineering Dashboard
2. **Disable Random Errors**: Click **Disable** on the Random Errors card
3. **Disable Corrupt Data**: Click **Disable** on the Corrupt Data card


All requests should now succeed with valid responses.

### Step 8: Learn About Preventing Combined Failures

Ask SRE Agent about resilience:

```
Now that I've resolved these chaos faults, what monitoring and alerting 
should I set up to detect similar combined failure scenarios in production?
```

## Additional Resources

- [Azure SRE Agent Documentation](https://learn.microsoft.com/en-us/azure/sre-agent/)
- [Chaos Engineering Principles](https://principlesofchaos.org/)
- [Azure Monitor Documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/)
- [Container Apps Troubleshooting](https://docs.microsoft.com/en-us/azure/container-apps/troubleshooting)
- [Application Insights for Distributed Tracing](https://docs.microsoft.com/en-us/azure/azure-monitor/app/distributed-tracing)

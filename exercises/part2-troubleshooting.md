# Part 2: SRE Agent Troubleshooting

## Overview

In this exercise, you'll learn how to use Azure SRE Agent to diagnose and fix common issues in cloud applications. Azure SRE Agent is an AI-powered reliability assistant that helps teams diagnose and resolve production issues, reduce operational toil, and lower mean time to resolution (MTTR).

You'll work through several realistic failure scenarios that SREs encounter in production environments, using Azure SRE Agent's natural language interface to investigate and resolve issues.

**Estimated Time:** 60-90 minutes

## Prerequisites

- Completed [Part 1: Setup](./part1-setup.md)
- Working infrastructure with API deployed
- Azure account with appropriate permissions
- Environment variables from Part 1 (see below)

### Load Environment Variables

If you're in a new terminal session, reload the environment variables from Part 1:

```bash
# Load saved environment variables
source ~/.workshop-env

# Or set them manually if needed:
export BASE_NAME="sre<your-initials>"
export RESOURCE_GROUP="${BASE_NAME}-workshop"
export APIM_URL="<your-apim-gateway-url>"
export SUBSCRIPTION_KEY="<your-subscription-key>"
```

> **Tip**: To retrieve your APIM URL and subscription key if you've lost them, see the commands in Part 1, Step 9.

## Learning Objectives

By the end of this exercise, you will:
- Create and configure an Azure SRE Agent
- Use natural language queries to investigate resource health
- Diagnose API connectivity problems with AI assistance
- Troubleshoot database connection failures
- Analyze performance degradation using SRE Agent
- Understand Azure diagnostic patterns and tools

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

---

## Exercise 1: API Returning 500 Errors

### Scenario

Users are reporting that the API returns 500 Internal Server Error when trying to create items. The health endpoint works fine, but all CRUD operations fail.

### Your Task

Investigate and fix the issue using SRE Agent.

### Step 1: Simulate the Issue

First, let's break the database connection to simulate the problem:

```bash
# Get the PostgreSQL server name
PSQL_SERVER=$(az postgres flexible-server list \
  --resource-group $RESOURCE_GROUP \
  --query "[0].name" -o tsv)

# Break the connection by updating the connection string with an invalid hostname
az containerapp secret set \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --secrets "db-connection-string=postgresql://invalid-host:5432/workshopdb"

# Force creation of a new revision by updating with a dummy environment variable
az containerapp update \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars "FORCE_UPDATE=$(date +%s)"
```

Wait about 30 seconds for the new revision to deploy, then proceed.

### Step 2: Reproduce the Issue

First, verify your environment variables are set:

```bash
# Verify variables are set
echo "APIM URL: $APIM_URL"
echo "Subscription Key: $SUBSCRIPTION_KEY"
```

If either is empty, reload them from Part 1 (see Prerequisites section above).

Now test the API - this should fail with 500 error:

```bash
curl -X POST \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test", "description": "Test item"}' \
  "$APIM_URL/api/items"
```

### Step 3: Gather Initial Information

In your Azure SRE Agent chat interface, ask:
```
I'm getting 500 errors from my Container App API when making POST requests. 
The health endpoint returns 200 OK. How should I investigate this?
```

The agent will suggest checking logs and provide guidance on diagnostic steps.

### Step 4: Check Container App Logs

Based on SRE Agent's guidance, check the logs:

```bash
az containerapp logs show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --tail 50
```

### Step 5: Analyze the Error with SRE Agent

Share the log findings with SRE Agent:
```
My Container App logs show database connection errors: 
'could not translate host name'. What could cause this?
```

The agent will help identify potential root causes and suggest investigation steps.

### Common Root Causes

1. **Incorrect connection string** - Check environment variables
2. **Network connectivity** - Verify VNet integration
3. **Database firewall** - Check if Container App subnet is allowed
4. **DNS resolution** - Private endpoint DNS configuration

### Step 6: Diagnose with SRE Agent

Ask the agent for specific diagnostic steps:
```
How can I verify PostgreSQL private endpoint DNS resolution 
from my Container App in Azure?
```

The agent will provide Azure-specific commands and checks.

### Step 7: Fix the Issue

Follow SRE Agent's recommendations. The issue is the invalid database connection string we set earlier.

**Get the correct connection string:**
```bash
# Get the PostgreSQL connection details
PSQL_SERVER=$(az postgres flexible-server list \
  --resource-group $RESOURCE_GROUP \
  --query "[0].name" -o tsv)

PSQL_HOST=$(az postgres flexible-server show \
  --resource-group $RESOURCE_GROUP \
  --name $PSQL_SERVER \
  --query "fullyQualifiedDomainName" -o tsv)

# Construct the correct connection string (use the password from your deployment)
CORRECT_DB_URL="postgresql://sqladmin:YourSecurePassword123@${PSQL_HOST}:5432/workshopdb?sslmode=require"

# Update the secret with the correct connection string
az containerapp secret set \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --secrets "db-connection-string=${CORRECT_DB_URL}"

# Force creation of a new revision to apply the secret change
az containerapp update \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars "FORCE_UPDATE=$(date +%s)"
```

Wait about 30 seconds for the new revision to deploy.

### Step 8: Verify the Fix

After applying the fix, test again:
```bash
curl -X POST \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "Fixed", "description": "After troubleshooting"}' \
  "$APIM_URL/api/items" | jq .
```

### Key Learnings

- Always check application logs first
- Connection string errors are common in container deployments
- VNet integration requires proper DNS configuration
- Azure SRE Agent provides contextual guidance for Azure-specific networking issues

---

## Exercise 2: High Response Times

### Scenario

The API is responding, but users report slow response times (5-10 seconds). Normal response time should be under 200ms.

### Your Task

Identify the performance bottleneck and optimize.

### Step 1: Simulate the Performance Issue

Enable slow mode to simulate slow database queries:

```bash
az containerapp update \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars "SLOW_MODE_DELAY=3.0"
```

Wait about 30 seconds for the new revision to deploy with slow mode enabled.

### Step 2: Measure Current Performance

```bash
# Time a simple GET request - look at the "time_total" value
curl -w "\nTime: %{time_total}s\n" -o /dev/null -s \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/api/items"
```

Run this a few times to see the response time. You should notice slower responses due to resource constraints.

### Step 3: Ask SRE Agent for Investigation Strategy

In the Azure SRE Agent chat, ask:
```
My API response times are 5-10 seconds, but should be under 200ms. 
I'm using Container Apps, PostgreSQL, and APIM. 
How should I investigate where the bottleneck is?
```

The agent will suggest a diagnostic approach.

### Step 4: Check Application Insights

```bash
APP_INSIGHTS_ID=$(az resource show \
  --ids $(az resource list \
    --resource-group $RESOURCE_GROUP \
    --resource-type "microsoft.insights/components" \
    --query "[0].id" -o tsv) \
  --query "properties.AppId" -o tsv)

# Query slow requests
az monitor app-insights query \
  --app $APP_INSIGHTS_ID \
  --analytics-query "
    requests 
    | where timestamp > ago(1h)
    | summarize avg(duration), max(duration), percentile(duration, 95) by name
    | order by avg_duration desc
  " \
  --output table
```

### Step 5: Check Container App Environment Variables

Ask Azure SRE Agent:
```
My Container App API is slow. Could environment variables be affecting performance?
```

Check the current environment variables:

```bash
az containerapp show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --query "properties.template.containers[0].env[?name=='SLOW_MODE_DELAY']"
```

You should see `SLOW_MODE_DELAY` set to `3.0`, which is causing the artificial delay.
```

### Step 6: Investigate Database Performance

Ask Azure SRE Agent:
```
Application Insights shows my API endpoints are taking 5+ seconds. 
How can I check if the PostgreSQL database is the bottleneck?
```

The agent will guide you through checking database metrics:

```bash
# Check PostgreSQL metrics
az monitor metrics list \
  --resource $(az postgres flexible-server show \
    --resource-group $RESOURCE_GROUP \
    --name ${BASE_NAME}-dev-psql-* \
    --query id -o tsv) \
  --metric "cpu_percent" \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --interval PT5M \
  --output table
```

### Step 7: Common Performance Issues

Ask Azure SRE Agent:
```
What are common causes of slow API responses in Azure Container Apps?
```

Potential issues the agent may identify:
1. **Misconfigured environment variables** - Debug/slow mode settings left enabled
2. **Missing indexes** - Database queries scanning full tables
3. **Under-provisioned compute** - Not enough vCores/memory
4. **Connection pooling** - Too many connection overhead
5. **Network latency** - Cross-region calls
5. **Cold start** - Container Apps scaling from zero

### Step 8: Fix the Issue

Based on the investigation, disable slow mode to restore normal performance:

```bash
az containerapp update \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars "SLOW_MODE_DELAY=0"
```

Wait about 30 seconds for the new revision to deploy.

### Step 9: Verify the Fix

Test the response time again:

```bash
# Time a simple GET request - look at the "time_total" value
curl -w "\nTime: %{time_total}s\n" -o /dev/null -s \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/api/items"
```

Response time should be back to normal (under 200ms).

Ask Azure SRE Agent to confirm best practices:
```
What are the recommended CPU and memory settings for a Python FastAPI 
application in Azure Container Apps?
```

### Step 10: Optimize Based on Findings

If database is slow, ask Azure SRE Agent:
```
How can I add indexes to my PostgreSQL database to improve 
query performance on the 'items' table?
```

If Container App is slow, ask:
```
"How can I configure Container Apps to always have at least 
one replica running to avoid cold starts?"
```

### Step 7: Apply Optimization

Example: Update Container App scale settings
```bash
az containerapp update \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --min-replicas 1 \
  --max-replicas 3
```

### Step 8: Re-test Performance

```bash
# Run multiple requests and measure
for i in {1..10}; do
  curl -w "Request $i - Time: %{time_total}s\n" -o /dev/null -s \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_URL/api/items"
done
```

### Key Learnings

- Use Application Insights to identify slow operations
- Database queries are often the performance bottleneck
- Cold starts can significantly impact response times
- SRE Agent can suggest Azure-specific optimizations

---

## Exercise 3: Container App Not Starting

### Scenario

After deploying a new version of the API, the Container App fails to start. Users get 503 Service Unavailable errors.

### Your Task

Diagnose why the container won't start and fix it.

### Step 1: Reproduce the Issue

```bash
# Deploy a broken version - use a non-existent image to simulate image pull failure
az containerapp update \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --image mcr.microsoft.com/azuredocs/nonexistent-image:broken
```

Wait about 60 seconds for the deployment to fail. The revision will fail to provision because the container image doesn't exist.

### Step 2: Check App Status

```bash
az containerapp show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --query "properties.{Status: runningStatus, Health: latestRevisionName}"
```

### Step 3: Consult SRE Agent

```
"My Container App shows status 'Failed' and won't start. 
How can I see why it's failing?"
```

### Step 4: Check Revision Status

```bash
az containerapp revision list \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --query "[].{Name: name, Status: properties.provisioningState, Active: properties.active, Message: properties.runningState}" \
  --output table
```

### Step 5: View System Logs

```bash
az containerapp logs show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --type system
```

### Common Container Startup Issues

Ask Azure SRE Agent:
```
What are the most common reasons a Container App fails to start in Azure?
```

Potential causes the agent may identify:
1. **Image pull errors** - Can't access ACR or image doesn't exist
2. **Insufficient resources** - Not enough CPU/memory
3. **Failed health probes** - App doesn't respond to health checks
4. **Missing secrets** - Required environment variables not set
5. **Application crash** - Code error on startup

### Step 6: Fix the Image

The issue is the non-existent image. Restore the working API image:

```bash
# Get the ACR name and working image
ACR_NAME=$(az acr list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)
WORKING_IMAGE="${ACR_NAME}.azurecr.io/workshop-api:v1.0.1"

# Restore the working image
az containerapp update \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --image $WORKING_IMAGE
```

Wait about 30 seconds for the new revision to deploy successfully.

### Step 7: Verify the Fix

```bash
# Check revision status
az containerapp revision list \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --query "reverse(sort_by([].{Name: name, Status: properties.provisioningState, Active: properties.active, Traffic: properties.trafficWeight}, &Name)) | [0:2]" \
  --output table

# Test the API
curl -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" "$APIM_URL/health"
```

### Advanced: Diagnose ACR Access Issues

If you see image pull errors with your own ACR images, ask Azure SRE Agent:
```
My Container App can't pull from ACR with error 'unauthorized'. 
I'm using managed identity. What could be wrong?
```

Check role assignments based on agent guidance:
```bash
IDENTITY_PRINCIPAL_ID=$(az identity show \
  --name ${BASE_NAME}-dev-identity \
  --resource-group $RESOURCE_GROUP \
  --query principalId -o tsv)

az role assignment list \
  --assignee $IDENTITY_PRINCIPAL_ID \
  --all
```

### Advanced: Fix ACR Access Issues

If managed identity is missing ACR pull permission:
```bash
az role assignment create \
  --assignee $IDENTITY_PRINCIPAL_ID \
  --role AcrPull \
  --scope $(az acr show --name $ACR_NAME --query id -o tsv)
```

Then force creation of a new revision to apply the role assignment:
```bash
az containerapp update \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars "FORCE_UPDATE=$(date +%s)"
```

### Key Learnings

- System logs show infrastructure-level errors
- Application logs show code-level errors
- Managed identity permissions can break after redeployments
- Container Apps revision history helps identify when issues started

---

## Exercise 4: APIM Gateway Timeout

### Scenario

API calls through APIM are timing out after 30 seconds, but direct calls to the Container App work fine.

### Your Task

Identify and fix the APIM timeout configuration.

### Step 1: Reproduce the Issue

```bash
# Simulate a slow endpoint (if you have one)
# Or observe timeout behavior
curl -v -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/api/items"
```

### Step 2: Ask Azure SRE Agent

In the Azure SRE Agent chat:
```
API calls through APIM are timing out after 30 seconds, 
but direct calls to my backend work. How do I fix APIM timeout settings?
```

The agent will guide you through checking APIM configuration.

### Step 3: Check APIM Backend Configuration

```bash
APIM_NAME=$(az apim list \
  --resource-group $RESOURCE_GROUP \
  --query "[0].name" -o tsv)

# Check API settings
az apim api show \
  --resource-group $RESOURCE_GROUP \
  --service-name $APIM_NAME \
  --api-id workshop-api
```

### Step 4: Check Backend Timeout Settings

Ask Azure SRE Agent:
```
How do I configure timeout settings for an API in Azure APIM?
```

### Step 5: Update APIM Policy

Follow the agent's guidance to add a timeout policy. Check current policy:

```bash
az apim api operation show \
  --resource-group $RESOURCE_GROUP \
  --service-name $APIM_NAME \
  --api-id workshop-api \
  --operation-id list-items
```

### Step 6: Apply Policy Update

Use Azure Portal to update API policies:
1. Navigate to APIM → APIs → workshop-api
2. Select "All operations"
3. In the Inbound processing section, add:

```xml
<policies>
    <inbound>
        <base />
        <set-backend-service backend-id="backend-id" />
        <timeout>120</timeout>
    </inbound>
</policies>
```

Or use CLI:
```bash
az apim api update \
  --resource-group $RESOURCE_GROUP \
  --service-name $APIM_NAME \
  --api-id workshop-api \
  --set properties.serviceUrl='https://your-backend-url'
```

### Key Learnings

- APIM has separate timeout configurations from backend services
- Policy files control APIM behavior
- Direct backend testing helps isolate APIM issues
- SRE Agent can generate policy XML for common scenarios

---

## Exercise 5: Database Connection Pool Exhaustion

### Scenario

After load testing, the API starts returning errors: "too many connections" or "connection pool exhausted"

### Your Task

Diagnose and fix the connection pooling issue.

### Step 1: Generate Load

```bash
# Simple load test (requires apache bench)
ab -n 100 -c 10 \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/api/items"
```

Or use curl in a loop:
```bash
for i in {1..50}; do
  curl -s -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_URL/api/items" &
done
wait
```

### Step 2: Observe Errors

Check logs for connection errors:
```bash
az containerapp logs show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --tail 100 | grep -i "connection"
```

### Step 3: Ask Azure SRE Agent

In the Azure SRE Agent chat:
```
My Python FastAPI app is getting 'too many connections' errors 
from PostgreSQL after load testing. How should I handle this?
```

The agent will provide guidance on connection management strategies.

### Step 4: Check PostgreSQL Connection Limits

```bash
# Check current connections
az postgres flexible-server parameter show \
  --resource-group $RESOURCE_GROUP \
  --server-name ${BASE_NAME}-dev-psql-* \
  --name max_connections
```

### Step 5: Implement Connection Pooling

Based on the agent's recommendations, ensure connection pooling is configured in your application:

```python
# In your FastAPI app, ensure proper pooling:
from sqlalchemy import create_engine
from sqlalchemy.pool import QueuePool

engine = create_engine(
    DATABASE_URL,
    poolclass=QueuePool,
    pool_size=5,          # Number of persistent connections
    max_overflow=10,      # Additional connections when pool is full
    pool_timeout=30,      # Timeout waiting for connection
    pool_recycle=3600,    # Recycle connections after 1 hour
    pool_pre_ping=True    # Verify connections before using
)
```

### Step 6: Adjust PostgreSQL Settings

Ask Azure SRE Agent:
```
How can I increase max_connections in Azure PostgreSQL Flexible Server?
```

Follow the agent's guidance:

```bash
az postgres flexible-server parameter set \
  --resource-group $RESOURCE_GROUP \
  --server-name ${BASE_NAME}-dev-psql-* \
  --name max_connections \
  --value 100
```

### Step 7: Scale Container App

```bash
# Allow more replicas to distribute load
az containerapp update \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --max-replicas 5
```

### Key Learnings

- Connection pooling is critical for database-backed APIs
- PostgreSQL has hard limits on connections
- Scaling horizontally requires considering database connections
- Each Container App replica needs its own connection pool

---

## Exercise 6: Missing Environment Variables

### Scenario

After updating a secret, the API can't connect to Application Insights and logs aren't appearing.

### Your Task

Diagnose and fix the configuration issue.

### Step 1: Reproduce the Issue

```bash
# Update a secret incorrectly
az containerapp secret set \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --secrets "appinsights-connection-string=invalid-value"
```

### Step 2: Check Application Insights

```bash
APP_INSIGHTS_ID=$(az resource show \
  --ids $(az resource list \
    --resource-group $RESOURCE_GROUP \
    --resource-type "microsoft.insights/components" \
    --query "[0].id" -o tsv) \
  --query "properties.AppId" -o tsv)

# No recent requests should appear
az monitor app-insights query \
  --app $APP_INSIGHTS_ID \
  --analytics-query "requests | where timestamp > ago(5m)" \
  --output table
```

### Step 3: Ask Azure SRE Agent

In the Azure SRE Agent chat:
```
My Container App is running but not sending telemetry to Application Insights. 
How can I troubleshoot this?
```

The agent will guide you through verification steps.

### Step 4: Verify Environment Variables

```bash
# List all environment variables
az containerapp show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --query "properties.template.containers[0].env"
```

### Step 5: Check Secret References

```bash
# List secrets
az containerapp secret list \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP
```

### Step 6: Fix the Configuration

Ask Azure SRE Agent:
```
How do I update a Container App secret and ensure the app picks up the new value?
```

Get the correct connection string and follow the agent's guidance:
```bash
APP_INSIGHTS_NAME=$(az resource list \
  --resource-group $RESOURCE_GROUP \
  --resource-type "microsoft.insights/components" \
  --query "[0].name" -o tsv)

CORRECT_CONNECTION_STRING=$(az monitor app-insights component show \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query connectionString -o tsv)

# Update the secret
az containerapp secret set \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --secrets "appinsights-connection-string=$CORRECT_CONNECTION_STRING"

# Restart to pick up new value
az containerapp restart \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP
```

### Key Learnings

- Secrets and environment variables require app restart
- Application Insights integration needs correct connection string format
- SRE Agent can help distinguish between different types of configuration issues

---

## Exercise 7: Regional Outage Simulation

### Scenario

You need to prepare for a potential Azure regional outage. How would you investigate resilience?

### Your Task

Use SRE Agent to understand your architecture's resilience and create an action plan.

### Step 1: Ask About Current Setup

```
"I have Container Apps, PostgreSQL, and APIM in swedencentral. 
What happens if this region goes down? How can I check my setup's resilience?"
```

### Step 2: Check Resource Distribution

```bash
# Check which resources are in which regions
az resource list \
  --resource-group $RESOURCE_GROUP \
  --query "[].{Name: name, Type: type, Location: location}" \
  --output table
```

### Step 3: Investigate Service Health

```bash
# Check service health for your region
az service-health event list \
  --query "[?properties.impactedRegions[?regionName=='swedencentral']]"
```

### Step 4: Ask About DR Strategy

Ask Azure SRE Agent:
```
What disaster recovery options do I have for Azure Container Apps 
and PostgreSQL Flexible Server across regions?
```

The agent will provide guidance on DR strategies for your architecture.

### Step 5: Create Resilience Checklist

Ask Azure SRE Agent to help create a comprehensive plan:
```
Create a checklist for improving the resilience of my setup including:
- Multi-region deployment
- Backup and restore procedures  
- Health monitoring
- Failover testing
```

### Key Learnings

- Azure SRE Agent can help plan disaster recovery strategies
- Understanding regional dependencies is critical
- Proactive resilience planning prevents outage impact

---

## Advanced Challenge: Multi-Service Failure

### Scenario

Multiple issues are occurring simultaneously:
1. API returns 500 errors intermittently
2. Response times vary between 200ms and 10s
3. Some requests succeed, others fail
4. Error rate increased after a deployment 2 hours ago

### Your Task

Use SRE Agent to:
1. Triage and prioritize the issues
2. Identify the root cause
3. Create an action plan
4. Implement fixes
5. Verify resolution

### Suggested SRE Agent Conversation Flow

```
"I have multiple issues with my Azure Container Apps API:
- Intermittent 500 errors
- Variable response times (200ms to 10s)  
- Errors started 2 hours ago after deployment
How should I approach troubleshooting this systematically?"
```

Follow SRE Agent's guidance through:
1. **Gather context** - Recent changes, deployment logs
2. **Check metrics** - Error rates, latency percentiles
3. **Analyze logs** - Pattern recognition in failures
4. **Form hypothesis** - Most likely cause based on symptoms
5. **Test hypothesis** - Targeted diagnostic commands
6. **Implement fix** - Rollback or targeted fix
7. **Verify** - Confirm resolution with metrics

---

## Best Practices for Using SRE Agent

### 1. Provide Context

✅ **Good:**
```
"My Azure Container App API returns 500 errors when accessing PostgreSQL. 
The error message is 'connection refused'. Both resources are in the same VNet.
Container App: srepk-dev-api in rg sre-workshop-pk"
```

❌ **Bad:**
```
"My API doesn't work"
```

### 2. Share Error Messages

Always include:
- Exact error messages
- Status codes
- Timestamps
- Resource names

### 3. Describe What Changed

```
"After deploying a new container image 30 minutes ago, 
API response time increased from 100ms to 5000ms"
```

### 4. Include Diagnostic Steps Already Taken

```
"I've checked:
- Container App logs show no errors
- Health endpoint returns 200
- Database metrics show normal CPU/memory
What should I check next?"
```

### 5. Ask for Verification Steps

```
"After applying your suggested fix, how can I verify it worked?"
```

---

## Troubleshooting Patterns

### Pattern 1: Start Wide, Then Narrow

1. Is the entire service down? → Check service health
2. Is it region-specific? → Check regional status
3. Is it one resource? → Check resource health
4. Is it a configuration? → Check recent changes

### Pattern 2: Follow the Request Path

1. APIM Gateway → Check gateway logs, policies
2. Network → Check VNet, NSGs, private endpoints
3. Container App → Check app logs, health probes
4. Database → Check connection, queries, performance

### Pattern 3: Compare Working vs Broken

- Different regions?
- Different time periods?
- Different API operations?
- Different user types?

---

## Summary Checklist

After completing Part 2, you should be able to:

- [ ] Create and configure Azure SRE Agent
- [ ] Use natural language queries to diagnose API failures
- [ ] Investigate database connection issues with AI assistance
- [ ] Analyze performance problems with Application Insights
- [ ] Troubleshoot Container App startup failures
- [ ] Configure APIM timeout policies
- [ ] Handle connection pool exhaustion
- [ ] Fix configuration and secret issues
- [ ] Plan for regional resilience
- [ ] Approach multi-service failures systematically

---

## What's Next?

**[Part 3: Monitoring & Alerts](./part3-monitoring.md)** - Learn to set up proactive monitoring, configure alerts, and use Azure SRE Agent for incident investigation.

---

## Additional Resources

- [Azure SRE Agent Documentation](https://learn.microsoft.com/en-us/azure/sre-agent/)
- [Azure Monitor Documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/)
- [Container Apps Troubleshooting](https://docs.microsoft.com/en-us/azure/container-apps/troubleshooting)
- [PostgreSQL Troubleshooting Guide](https://docs.microsoft.com/en-us/azure/postgresql/flexible-server/how-to-troubleshoot-common-connection-issues)
- [APIM Policy Reference](https://docs.microsoft.com/en-us/azure/api-management/api-management-policies)

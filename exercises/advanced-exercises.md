# Advanced Exercises

## Overview

These advanced exercises are designed for experienced SREs who want to explore more complex scenarios. Each exercise builds on the core workshop and introduces production-grade SRE practices.

**Estimated Time:** 2-4 hours (select exercises based on interest)

## Prerequisites

- Completed [Part 1: Setup](./part1-setup.md), [Part 2: Troubleshooting](./part2-troubleshooting.md), and [Part 3: Monitoring](./part3-monitoring.md)
- Comfortable with Azure CLI, KQL, and infrastructure automation
- Understanding of SRE principles and practices

---

## Exercise 1: Auto-Remediation with Azure Automation

### Scenario

Implement automated remediation for common issues using Azure Automation and Logic Apps.

### Objective

Automatically restart Container App when health checks fail repeatedly.

### Step 1: Create Automation Account

```bash
# Create automation account
az automation account create \
  --name "${BASE_NAME}-automation" \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# Enable managed identity
az automation account update \
  --name "${BASE_NAME}-automation" \
  --resource-group $RESOURCE_GROUP \
  --assign-identity
```

### Step 2: Grant Permissions

```bash
# Get automation account principal ID
AUTOMATION_PRINCIPAL_ID=$(az automation account show \
  --name "${BASE_NAME}-automation" \
  --resource-group $RESOURCE_GROUP \
  --query identity.principalId -o tsv)

# Grant Contributor role to restart Container Apps
az role assignment create \
  --assignee $AUTOMATION_PRINCIPAL_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP"
```

### Step 3: Create Runbook

In your Azure SRE Agent chat, ask:
```
Create a PowerShell runbook for Azure Automation that restarts a 
Container App when triggered by an alert. Include logging and error handling.
```

Create the runbook:

```bash
cat > restart-container-app.ps1 << 'EOF'
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$ContainerAppName,
    
    [Parameter(Mandatory=$false)]
    [string]$WebhookData
)

# Connect using managed identity
Connect-AzAccount -Identity

Write-Output "Starting remediation for Container App: $ContainerAppName"
Write-Output "Resource Group: $ResourceGroupName"

try {
    # Get current revision
    $containerApp = Get-AzContainerApp -ResourceGroupName $ResourceGroupName -Name $ContainerAppName
    $currentRevision = $containerApp.LatestRevisionName
    
    Write-Output "Current revision: $currentRevision"
    
    # Restart by deactivating and reactivating
    Write-Output "Restarting Container App..."
    Update-AzContainerApp -ResourceGroupName $ResourceGroupName -Name $ContainerAppName -ForceRestart
    
    Write-Output "Container App restart initiated successfully"
    
    # Wait for health check
    Start-Sleep -Seconds 30
    
    $updatedApp = Get-AzContainerApp -ResourceGroupName $ResourceGroupName -Name $ContainerAppName
    Write-Output "New revision: $($updatedApp.LatestRevisionName)"
    
    # Log to Application Insights (optional)
    $telemetry = @{
        action = "auto-remediation"
        type = "container-app-restart"
        resource = $ContainerAppName
        result = "success"
        timestamp = (Get-Date).ToString("o")
    }
    
    Write-Output "Remediation completed successfully"
    Write-Output ($telemetry | ConvertTo-Json)
    
} catch {
    Write-Error "Failed to restart Container App: $_"
    
    $telemetry = @{
        action = "auto-remediation"
        type = "container-app-restart"
        resource = $ContainerAppName
        result = "failed"
        error = $_.Exception.Message
        timestamp = (Get-Date).ToString("o")
    }
    
    Write-Output ($telemetry | ConvertTo-Json)
    throw
}
EOF

# Import runbook
az automation runbook create \
  --name "Restart-ContainerApp" \
  --automation-account-name "${BASE_NAME}-automation" \
  --resource-group $RESOURCE_GROUP \
  --type PowerShell \
  --location $LOCATION

az automation runbook replace-content \
  --name "Restart-ContainerApp" \
  --automation-account-name "${BASE_NAME}-automation" \
  --resource-group $RESOURCE_GROUP \
  --content @restart-container-app.ps1

# Publish runbook
az automation runbook publish \
  --name "Restart-ContainerApp" \
  --automation-account-name "${BASE_NAME}-automation" \
  --resource-group $RESOURCE_GROUP
```

### Step 4: Create Webhook

```bash
# Create webhook for the runbook
WEBHOOK_URL=$(az automation runbook create-webhook \
  --name "Restart-ContainerApp" \
  --automation-account-name "${BASE_NAME}-automation" \
  --resource-group $RESOURCE_GROUP \
  --webhook-name "container-app-restart-webhook" \
  --expiry-time "2026-12-31T23:59:59Z" \
  --is-enabled true \
  --parameters resourceGroupName=$RESOURCE_GROUP containerAppName=${BASE_NAME}-dev-api \
  --query uri -o tsv)

echo "Webhook URL (save this securely): $WEBHOOK_URL"
```

### Step 5: Create Action Group with Webhook

```bash
# Create action group that calls webhook
az monitor action-group create \
  --name "Auto-Remediation-Restart" \
  --resource-group $RESOURCE_GROUP \
  --short-name "AutoRestart" \
  --webhook-receiver \
    name="RestartWebhook" \
    service-uri="$WEBHOOK_URL" \
    use-common-alert-schema=true
```

### Step 6: Load Testing

Use Azure SRE Agent to design load testing:
```
Create a load testing strategy for my API to validate these optimizations.
Include ramp-up patterns and success criteria.
```

### Step 7: Test Auto-Remediation

```bash
# Simulate health check failures (in your API code)
# Or manually trigger the webhook
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "ResourceGroupName": "'$RESOURCE_GROUP'",
    "ContainerAppName": "'${BASE_NAME}-dev-api'"
  }'

# Check automation job status
az automation job list \
  --automation-account-name "${BASE_NAME}-automation" \
  --resource-group $RESOURCE_GROUP \
  --output table
```

### Discussion with Azure SRE Agent

In your Azure SRE Agent chat, ask:
```
What are the risks of auto-remediation and when should I use 
human-in-the-loop instead of fully automated remediation?
```

### Key Learnings

- Auto-remediation reduces MTTR for known issues
- Always include logging and metrics in runbooks
- Test remediation scripts thoroughly before production
- Consider circuit breakers to prevent remediation loops
- Human oversight required for complex issues

---

## Exercise 2: Chaos Engineering with Azure Chaos Studio

### Scenario

Use Chaos Studio to test system resilience by injecting failures.

### Objective

Run chaos experiments to validate monitoring, alerting, and recovery procedures.

### Step 1: Enable Chaos Studio

```bash
# Register Chaos Studio provider
az provider register --namespace Microsoft.Chaos

# Create chaos experiment targeting Container App
az chaos experiment create \
  --name "container-app-cpu-pressure" \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

### Step 2: Design Chaos Experiment

In your Azure SRE Agent chat, ask:
```
Design a chaos engineering experiment to test if my monitoring 
and alerting works correctly when Container App CPU spikes.
```

Experiment design:
1. **Hypothesis**: High CPU alerts fire within 2 minutes
2. **Blast Radius**: Single Container App instance
3. **Abort Conditions**: Error rate > 50%
4. **Duration**: 10 minutes
5. **Monitoring**: Watch alerts, dashboards, and SRE response

### Step 3: Create CPU Pressure Experiment

```bash
# Create experiment manifest
cat > chaos-cpu-pressure.json << 'EOF'
{
  "location": "swedencentral",
  "identity": {
    "type": "SystemAssigned"
  },
  "properties": {
    "steps": [
      {
        "name": "CPU Pressure Step",
        "branches": [
          {
            "name": "CPU Pressure Branch",
            "actions": [
              {
                "type": "continuous",
                "name": "urn:csci:microsoft:containerApps:cpuPressure/1.0",
                "parameters": [
                  {
                    "key": "virtualMachineScaleSetInstances",
                    "value": "[0]"
                  },
                  {
                    "key": "cpuLoadPercentage",
                    "value": "90"
                  }
                ],
                "duration": "PT10M",
                "selectorId": "Selector1"
              }
            ]
          }
        ]
      }
    ],
    "selectors": [
      {
        "id": "Selector1",
        "type": "List",
        "targets": [
          {
            "type": "ChaosTarget",
            "id": "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.App/containerApps/${BASE_NAME}-dev-api/providers/Microsoft.Chaos/targets/Microsoft-ContainerApps"
          }
        ]
      }
    ]
  }
}
EOF
```

### Step 4: Alternative - Manual Chaos Testing

Since Chaos Studio requires specific setup, you can manually inject failures:

**CPU Pressure:**
```bash
# Add CPU-intensive endpoint to your API
# Then call it repeatedly
for i in {1..100}; do
  curl -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_URL/api/items" &
done
```

**Network Latency:**
```bash
# Update Container App with artificial delay in code
# Or use APIM policy to add delay
```

**Database Failures:**
```bash
# Temporarily block database firewall
az postgres flexible-server firewall-rule delete \
  --resource-group $RESOURCE_GROUP \
  --name $(az postgres flexible-server list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv) \
  --rule-name "AllowVNet"
```

### Step 5: Run Experiment and Observe

Before running experiment:
1. Open monitoring dashboard
2. Prepare SRE Agent conversation
3. Document baseline metrics
4. Notify team (if applicable)

During experiment:
1. Watch for alert notifications
2. Monitor dashboard metrics
3. Use Azure SRE Agent to investigate
4. Document response timeline

After experiment:
1. Verify system recovery
2. Review alert effectiveness
3. Identify gaps in monitoring
4. Update runbooks

### Step 6: Write Chaos Report

In your Azure SRE Agent chat, ask:
```
Help me write a chaos engineering report. Experiment: CPU pressure 
for 10 minutes. Result: Alert fired after 3 minutes, team responded 
in 5 minutes, false alarm (CPU normal after load stopped). Gap: Need 
to distinguish between artificial load and real issues.
```

### Key Learnings

- Chaos engineering validates monitoring effectiveness
- Run experiments during business hours with team ready
- Start with small blast radius
- Document learnings and improve based on results
- Regular chaos tests build confidence

---

## Exercise 3: Multi-Region Resilience Testing

### Scenario

Test failover procedures and data consistency in multi-region setup.

### Objective

Understand the impact of regional outages and validate DR procedures.

### Step 1: Design Multi-Region Architecture

In your Azure SRE Agent chat, ask:
```
Design a multi-region architecture for my Container App and PostgreSQL 
setup. Consider RPO, RTO, and cost constraints.
```

Typical design:
- Primary region: Sweden Central
- Secondary region: West Europe
- Azure Front Door for global routing
- PostgreSQL read replicas or geo-replication
- Shared Container Registry

### Step 2: Document Current State (Single Region)

```bash
# Document RTO/RPO for current setup
echo "Current Architecture Assessment" > resilience-report.md
echo "================================" >> resilience-report.md
echo "" >> resilience-report.md
echo "## Single Region Setup" >> resilience-report.md
echo "- Region: $LOCATION" >> resilience-report.md
echo "- RTO (Recovery Time Objective): Manual deployment ~15 minutes" >> resilience-report.md
echo "- RPO (Recovery Point Objective): Last database backup" >> resilience-report.md
echo "" >> resilience-report.md
```

### Step 3: Simulate Regional Outage

```bash
# Document current metrics
echo "## Pre-Outage Metrics" >> resilience-report.md
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    requests
    | where timestamp > ago(5m)
    | summarize RequestCount = count(), AvgDuration = avg(duration)
  " >> resilience-report.md

# Simulate outage by stopping Container App
az containerapp revision deactivate \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --revision $(az containerapp revision list \
    --name ${BASE_NAME}-dev-api \
    --resource-group $RESOURCE_GROUP \
    --query "[0].name" -o tsv)

# Document detection time
START_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "Outage started: $START_TIME" >> resilience-report.md
```

### Step 4: Execute DR Procedure

In your Azure SRE Agent chat, ask:
```
My primary region is down. Walk me through the DR procedure to 
deploy to a secondary region using my existing Bicep templates.
```

```bash
# Deploy to secondary region
SECONDARY_REGION="westeurope"
SECONDARY_RG="${RESOURCE_GROUP}-dr"

# Create DR resource group
az group create --name $SECONDARY_RG --location $SECONDARY_REGION

# Deploy infrastructure to DR region
az deployment group create \
  --name workshop-dr-deployment-$(date +%Y%m%d-%H%M%S) \
  --resource-group $SECONDARY_RG \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam \
  --parameters baseName="${BASE_NAME}dr" \
  --parameters location=$SECONDARY_REGION \
  --parameters containerImage=sreagentacr574f2c.azurecr.io/workshop-api:v1.0.1
```

### Step 5: Measure RTO/RPO

```bash
# Document recovery time
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "Recovery completed: $END_TIME" >> resilience-report.md

# Calculate RTO
echo "Calculating RTO..." >> resilience-report.md

# Test DR endpoint
DR_APIM_URL=$(az apim show \
  --name $(az apim list --resource-group $SECONDARY_RG --query "[0].name" -o tsv) \
  --resource-group $SECONDARY_RG \
  --query gatewayUrl -o tsv)

curl "$DR_APIM_URL/api/health"
```

### Step 6: Analyze Data Consistency

```bash
# Compare database states (if replicated)
echo "## Data Consistency Check" >> resilience-report.md

# Query item count in primary (if available)
# Query item count in DR
# Document any data loss

echo "RPO Analysis: [Document data loss if any]" >> resilience-report.md
```

### Step 7: Cost Analysis

In your Azure SRE Agent chat, ask:
```
Calculate the monthly cost difference between single-region 
and active-passive multi-region setup for this architecture.
```

### Key Learnings

- DR testing reveals gaps in procedures
- RTO/RPO requirements drive architecture decisions
- Automation critical for fast failover
- Regular DR drills improve response time
- Document procedures before you need them

---

## Exercise 4: Performance Optimization Deep-Dive

### Scenario

Systematically identify and resolve performance bottlenecks.

### Objective

Improve API response time from P95 500ms to <200ms.

### Step 1: Establish Baseline

```bash
# Run load test to establish baseline
cat > load-test.sh << 'EOF'
#!/bin/bash
echo "Running baseline performance test..."
for i in {1..1000}; do
  curl -s -w "%{time_total}\n" -o /dev/null \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_URL/api/items" >> response-times.txt &
done
wait
EOF

chmod +x load-test.sh
./load-test.sh

# Calculate percentiles
sort -n response-times.txt | awk '
  BEGIN { count=0; sum=0; }
  { times[count++]=$1; sum+=$1; }
  END {
    print "Average: " sum/count "s";
    print "P50: " times[int(count*0.50)] "s";
    print "P95: " times[int(count*0.95)] "s";
    print "P99: " times[int(count*0.99)] "s";
  }
'
```

### Step 2: Profile with Application Insights

In your Azure SRE Agent chat, ask:
```
Write KQL queries to identify performance bottlenecks in my API. 
Look at request duration, dependency calls, and database queries.
```

```bash
# Find slowest operations
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    requests
    | where timestamp > ago(1h)
    | summarize 
        Count = count(),
        AvgDuration = avg(duration),
        P95Duration = percentile(duration, 95)
      by name
    | order by P95Duration desc
  " \
  --output table

# Analyze database dependencies
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    dependencies
    | where timestamp > ago(1h) and type == 'SQL'
    | summarize 
        Count = count(),
        AvgDuration = avg(duration),
        P95Duration = percentile(duration, 95)
      by name
    | order by P95Duration desc
  " \
  --output table
```

### Step 3: Identify Optimization Opportunities

In your Azure SRE Agent chat to analyze results, ask:
```
Based on these metrics: GET /items avg 450ms, database query avg 
380ms, 100 database calls per request. What optimizations should I implement?
```

Common optimizations:
1. **Add database indexes**
2. **Implement caching (Redis)**
3. **Reduce N+1 queries**
4. **Enable HTTP response caching**
5. **Optimize database queries**
6. **Add connection pooling** (already done)

### Step 4: Implement Caching Layer

```bash
# Create Azure Cache for Redis
az redis create \
  --name "${BASE_NAME}-cache" \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --sku Basic \
  --vm-size c0 \
  --enable-non-ssl-port false

# Get Redis connection string
REDIS_KEY=$(az redis list-keys \
  --name "${BASE_NAME}-cache" \
  --resource-group $RESOURCE_GROUP \
  --query primaryKey -o tsv)

REDIS_HOST="${BASE_NAME}-cache.redis.cache.windows.net"
REDIS_CONNECTION_STRING="rediss://:${REDIS_KEY}@${REDIS_HOST}:6380"
```

Update Container App with Redis:

```bash
az containerapp update \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --set-env-vars \
    "REDIS_URL=${REDIS_CONNECTION_STRING}" \
    "CACHE_TTL=300"
```

### Step 5: Add Caching to API Code

In your Azure SRE Agent chat, ask:
```
Show me how to add Redis caching to my FastAPI GET /items endpoint 
with a 5-minute TTL.
```

Example code (add to your API):

```python
import redis.asyncio as redis
from fastapi import FastAPI
import json

app = FastAPI()
redis_client = redis.from_url(os.getenv("REDIS_URL"))

@app.get("/items")
async def list_items():
    # Try cache first
    cache_key = "items:all"
    cached = await redis_client.get(cache_key)
    
    if cached:
        return json.loads(cached)
    
    # Query database
    items = await db.fetch_all("SELECT * FROM items")
    
    # Cache result
    await redis_client.setex(
        cache_key, 
        int(os.getenv("CACHE_TTL", 300)),
        json.dumps(items)
    )
    
    return items
```

### Step 6: Add Database Indexes

```bash
# Connect to PostgreSQL and add indexes
POSTGRES_HOST=$(az postgres flexible-server show \
  --resource-group $RESOURCE_GROUP \
  --name $(az postgres flexible-server list \
    --resource-group $RESOURCE_GROUP \
    --query "[0].name" -o tsv) \
  --query fullyQualifiedDomainName -o tsv)

# Create index on commonly queried columns
psql "host=$POSTGRES_HOST dbname=workshopdb user=sqladmin password=SecurePassword123 sslmode=require" << 'EOF'
-- Add index on created_at for ordering
CREATE INDEX IF NOT EXISTS idx_items_created_at ON items(created_at DESC);

-- Add index on name for searching (if applicable)
CREATE INDEX IF NOT EXISTS idx_items_name ON items(name);

-- Analyze table
ANALYZE items;
EOF
```

### Step 7: Re-test Performance

```bash
# Run load test again
./load-test.sh

# Compare results
sort -n response-times.txt | awk '
  BEGIN { count=0; sum=0; }
  { times[count++]=$1; sum+=$1; }
  END {
    print "After Optimization:";
    print "Average: " sum/count "s";
    print "P50: " times[int(count*0.50)] "s";
    print "P95: " times[int(count*0.95)] "s";
    print "P99: " times[int(count*0.99)] "s";
  }
'
```

### Step 8: Document Improvements

```bash
# Query Application Insights for before/after comparison
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    requests
    | where name == 'GET /items'
    | summarize 
        AvgBefore = avgif(duration, timestamp < datetime(2025-11-06T15:00:00Z)),
        AvgAfter = avgif(duration, timestamp >= datetime(2025-11-06T15:00:00Z)),
        ImprovementPct = (avgif(duration, timestamp < datetime(2025-11-06T15:00:00Z)) - 
                          avgif(duration, timestamp >= datetime(2025-11-06T15:00:00Z))) * 100.0 / 
                          avgif(duration, timestamp < datetime(2025-11-06T15:00:00Z))
  " \
  --output table
```

### Key Learnings

- Always establish baseline before optimizing
- Profile first, optimize second (don't guess)
- Caching provides biggest wins for read-heavy workloads
- Database indexes critical for query performance
- Monitor after optimization to verify improvements

---

## Exercise 5: Security Incident Investigation

### Scenario

Suspicious activity detected. Investigate potential security breach.

### Objective

Use Azure SRE Agent and Azure tools to investigate security incident.

### Step 1: Receive Security Alert

Scenario:
```
"Security Alert: Unusual API access pattern detected
- 10,000 requests from single IP in 5 minutes
- Multiple failed authentication attempts
- Unusual geographic location (suspicious country)
- Time: 2025-11-06 03:00-03:05 UTC"
```

### Step 2: Initial Triage with Azure SRE Agent

In your Azure SRE Agent chat, ask:
```
I received a security alert for unusual API access. Walk me through 
the investigation steps to determine if this is a real security incident 
or false positive.
```

The agent will guide you through:
1. Verify alert details
2. Check request patterns
3. Analyze authentication logs
4. Assess impact
5. Determine if containment needed

### Step 3: Analyze Request Patterns

```bash
# Query suspicious requests
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    requests
    | where timestamp between (datetime(2025-11-06T03:00:00Z) .. datetime(2025-11-06T03:05:00Z))
    | summarize 
        RequestCount = count(),
        UniqueURLs = dcount(url),
        UniqueOperations = dcount(name),
        SuccessRate = countif(success == true) * 100.0 / count()
      by client_IP
    | order by RequestCount desc
  " \
  --output table
```

### Step 4: Check for Attack Patterns

```bash
# Look for SQL injection attempts
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    requests
    | where timestamp > ago(1h)
    | where url contains 'SELECT' or url contains 'UNION' or url contains '--'
    | project timestamp, client_IP, url, resultCode
  " \
  --output table

# Check for unauthorized access attempts
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    requests
    | where timestamp > ago(1h) and resultCode == '401'
    | summarize Count = count() by client_IP, bin(timestamp, 1m)
    | where Count > 100
    | order by timestamp desc
  " \
  --output table
```

### Step 5: Review APIM Access Logs

```bash
# Check APIM subscription key usage
az apim api-management-api list \
  --resource-group $RESOURCE_GROUP \
  --service-name $(az apim list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)

# Query APIM logs in Application Insights
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    requests
    | where timestamp > ago(1h)
    | extend SubscriptionId = tostring(customDimensions['Subscription-Id'])
    | where isnotempty(SubscriptionId)
    | summarize 
        Requests = count(),
        FailedRequests = countif(success == false)
      by SubscriptionId, client_IP
    | order by Requests desc
  " \
  --output table
```

### Step 6: Assess Impact

In your Azure SRE Agent chat, ask:
```
Based on these findings: 10,000 requests, all GET /items, same subscription 
key, 98% success rate, no SQL injection attempts. Is this a security incident 
or legitimate traffic?
```

### Step 7: Take Containment Actions (If Needed)

```bash
# If confirmed malicious, block IP in APIM
cat > apim-ip-filter-policy.xml << 'EOF'
<policies>
    <inbound>
        <ip-filter action="forbid">
            <address>SUSPICIOUS_IP_HERE</address>
        </ip-filter>
        <base />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
EOF

# Revoke subscription key if compromised
az apim subscription update \
  --resource-group $RESOURCE_GROUP \
  --service-name $(az apim list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv) \
  --subscription-id "suspicious-subscription-id" \
  --state suspended
```

### Step 8: Document Security Incident

Ask SRE Agent:
```
"Help me write a security incident report for this event. Include 
timeline, investigation steps, findings, containment actions, and 
recommendations to prevent future incidents."
```

### Step 9: Implement Rate Limiting

```bash
# Add rate limiting to APIM to prevent future abuse
cat > apim-rate-limit-policy.xml << 'EOF'
<policies>
    <inbound>
        <rate-limit-by-key calls="100" 
                           renewal-period="60" 
                           counter-key="@(context.Request.IpAddress)" />
        <quota-by-key calls="10000" 
                      renewal-period="86400" 
                      counter-key="@(context.Subscription.Id)" />
        <base />
    </inbound>
</policies>
EOF
```

### Key Learnings

- Security incidents require systematic investigation
- Application Insights provides forensic data
- APIM policies can prevent and mitigate attacks
- Rate limiting and IP filtering are essential controls
- Document all security incidents for future reference

---

## Exercise 6: Cost Optimization Analysis

### Scenario

Monthly Azure costs are higher than expected. Identify optimization opportunities.

### Objective

Reduce infrastructure costs by 20% without impacting performance or reliability.

### Step 1: Analyze Current Costs

Ask SRE Agent:
```
"How do I analyze Azure costs for my resource group and identify 
the top cost drivers?"
```

```bash
# Get cost data for last 30 days
az costmanagement query \
  --type Usage \
  --dataset-aggregation '{"totalCost":{"name":"Cost","function":"Sum"}}' \
  --dataset-grouping name="ResourceGroup" type="Dimension" \
  --timeframe MonthToDate \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --query "properties.rows" \
  --output table

# Get cost by resource type
az costmanagement query \
  --type Usage \
  --dataset-aggregation '{"totalCost":{"name":"Cost","function":"Sum"}}' \
  --dataset-grouping name="ResourceType" type="Dimension" \
  --dataset-filter "{\"dimensions\":{\"name\":\"ResourceGroup\",\"operator\":\"In\",\"values\":[\"$RESOURCE_GROUP\"]}}" \
  --timeframe MonthToDate \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --query "properties.rows" \
  --output table
```

### Step 2: Identify Optimization Opportunities

In your Azure SRE Agent chat, ask:
```
I have: Container Apps (3 replicas, 1 vCPU, 2GB each), PostgreSQL 
Flexible Server (B1ms), APIM Consumption tier, Application Insights. 
What cost optimizations can I implement?
```

Common optimizations:
1. **Right-size Container Apps** based on actual usage
2. **Reduce database tier** if underutilized
3. **Implement auto-scaling** to reduce idle resources
4. **Use Azure Reservations** for predictable workloads
5. **Clean up unused resources**
6. **Optimize Application Insights** sampling

### Step 3: Analyze Resource Utilization

```bash
# Container App CPU utilization
az monitor metrics list \
  --resource $(az containerapp show \
    --name ${BASE_NAME}-dev-api \
    --resource-group $RESOURCE_GROUP \
    --query id -o tsv) \
  --metric "UsageNanoCores" \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --interval PT1H \
  --aggregation Average \
  --output table

# Database utilization
POSTGRES_ID=$(az postgres flexible-server show \
  --resource-group $RESOURCE_GROUP \
  --name $(az postgres flexible-server list \
    --resource-group $RESOURCE_GROUP \
    --query "[0].name" -o tsv) \
  --query id -o tsv)

az monitor metrics list \
  --resource $POSTGRES_ID \
  --metric "cpu_percent" \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --interval PT1H \
  --aggregation Average \
  --output table
```

### Step 4: Implement Optimizations

```bash
# Example: Reduce Container App scale if underutilized
az containerapp update \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --min-replicas 1 \
  --max-replicas 2 \
  --cpu 0.5 \
  --memory 1Gi

# Example: Reduce Application Insights sampling
az monitor app-insights component update \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --sampling-percentage 50
```

### Step 5: Calculate Savings

Ask SRE Agent:
```
"If I reduce Container App from 1 vCPU to 0.5 vCPU and memory from 2GB to 1GB, 
what's the monthly cost savings?"
```

### Step 6: Monitor Impact

After optimization, monitor:
- Performance metrics (ensure no degradation)
- Error rates
- Response times
- User experience

### Key Learnings

- Regular cost reviews identify waste
- Right-sizing based on actual usage saves money
- Balance cost optimization with performance
- Monitor impact of cost-saving changes
- Use Azure Cost Management for visibility

---

## Exercise 7: Custom Metrics and Dashboards

### Scenario

Build custom business metrics dashboard for stakeholders.

### Objective

Track business KPIs like items created per day, active users, API adoption.

### Step 1: Define Business Metrics

In your Azure SRE Agent chat, ask:
```
I want to track business metrics for my API. Suggest KPIs for: 
user adoption, feature usage, and business value delivered.
```

Example metrics:
- Items created per day
- Unique API consumers
- API call distribution by operation
- Error rate by customer
- Feature adoption rate

### Step 2: Create Custom KQL Queries

```bash
# Items created per day
QUERY_ITEMS_PER_DAY='
requests
| where timestamp > ago(30d) and name == "POST /items"
| where success == true
| summarize ItemsCreated = count() by bin(timestamp, 1d)
| render timechart
'

# Unique API consumers (by subscription key)
QUERY_UNIQUE_CONSUMERS='
requests
| where timestamp > ago(30d)
| extend SubscriptionId = tostring(customDimensions["Subscription-Id"])
| summarize by SubscriptionId
| count
'

# Operation distribution
QUERY_OPERATION_DIST='
requests
| where timestamp > ago(7d)
| summarize RequestCount = count() by name
| render piechart
'
```

### Step 3: Create Custom Dashboard

```bash
# Export queries to dashboard JSON
cat > business-dashboard.json << 'EOF'
{
  "name": "Business Metrics Dashboard",
  "tiles": [
    {
      "title": "Items Created Per Day",
      "query": "requests | where timestamp > ago(30d) and name == 'POST /items' and success == true | summarize ItemsCreated = count() by bin(timestamp, 1d) | render timechart"
    },
    {
      "title": "API Call Distribution",
      "query": "requests | where timestamp > ago(7d) | summarize RequestCount = count() by name | render piechart"
    }
  ]
}
EOF
```

### Step 4: Share with Stakeholders

Create Power BI report or export dashboard for sharing with non-technical stakeholders.

### Key Learnings

- Business metrics drive product decisions
- Custom dashboards provide stakeholder visibility
- KQL enables flexible metric definition
- Regular metric reviews align teams

---

## Challenge: Build Your Own SRE Scenario

### Your Mission

Design and implement your own advanced SRE scenario based on your team's needs.

### Ideas

1. **GitOps Deployment** - Implement automated deployment with GitHub Actions
2. **Cost Anomaly Detection** - Alert on unexpected cost spikes
3. **Compliance Monitoring** - Track security and compliance metrics
4. **Customer Impact Tracking** - Correlate incidents with customer churn
5. **Predictive Monitoring** - Use ML to predict failures

### Deliverables

- Scenario description and objectives
- Implementation steps
- SRE Agent conversation examples
- Testing and validation
- Documentation and runbooks

---

## Best Practices Summary

### Advanced SRE Principles

✅ **Automation First** - Automate toil and repetitive tasks  
✅ **Chaos Engineering** - Test failure modes proactively  
✅ **Security-First** - Investigate anomalies quickly  
✅ **Cost Awareness** - Optimize continuously  
✅ **Business Alignment** - Track metrics that matter  
✅ **Documentation** - Share knowledge through runbooks and RCAs  
✅ **Continuous Learning** - Every incident is learning opportunity  

### Using SRE Agent for Advanced Scenarios

✅ Ask for design reviews and architecture recommendations  
✅ Request cost-benefit analysis for optimizations  
✅ Get help writing complex KQL queries  
✅ Draft incident reports and postmortems  
✅ Validate security configurations  
✅ Generate runbooks and playbooks  

---

## Congratulations! 🎉

You've completed the advanced SRE exercises! You now have hands-on experience with:

- Auto-remediation and runbook automation
- Chaos engineering and resilience testing
- Multi-region DR planning and execution
- Performance optimization methodology
- Security incident investigation
- Cost optimization analysis
- Custom business metrics

Continue building your SRE skills by applying these practices to your production systems!

---

## Additional Resources

- [Google SRE Book](https://sre.google/sre-book/table-of-contents/)
- [Azure Architecture Center - Reliability](https://docs.microsoft.com/en-us/azure/architecture/framework/resiliency/)
- [Chaos Engineering Principles](https://principlesofchaos.org/)
- [Azure Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework/)
- [Cost Optimization Best Practices](https://docs.microsoft.com/en-us/azure/cost-management-billing/costs/cost-mgt-best-practices)

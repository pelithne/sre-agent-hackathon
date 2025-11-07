# Part 3: Monitoring & Alerts

## Overview

In this exercise, you'll learn to set up proactive monitoring and alerting for your Azure infrastructure. You'll configure Azure Monitor alerts, create dashboards, and use Azure SRE Agent to investigate incidents and create Root Cause Analysis (RCA) reports.

**Estimated Time:** 60-90 minutes

## Prerequisites

- Completed [Part 1: Setup](./part1-setup.md) and [Part 2: Troubleshooting](./part2-troubleshooting.md)
- Working infrastructure with API deployed
- Application Insights configured
- Azure SRE Agent created and configured (from Part 2)

## Learning Objectives

By the end of this exercise, you will:
- Configure Azure Monitor metric alerts
- Set up log-based alerts for error conditions
- Create availability tests for API endpoints
- Build monitoring dashboards
- Use Azure SRE Agent to investigate alert notifications
- Write comprehensive RCA reports with Azure SRE Agent assistance
- Implement alert action groups for incident response

---

## Exercise 1: Configure Basic Metric Alerts

### Scenario

Set up alerts to notify you when your application experiences issues before users complain.

### Step 1: Create Action Group

Action groups define who gets notified and how when an alert fires.

```bash
# Create an action group with email notification
az monitor action-group create \
  --name "SRE-Workshop-Alerts" \
  --resource-group $RESOURCE_GROUP \
  --short-name "SREAlert" \
  --email-receiver \
    name="Admin" \
    email="your-email@example.com" \
    use-common-alert-schema=true
```

### Step 2: Create CPU Alert for Container App

In your Azure SRE Agent chat, ask:
```
How do I create an alert in Azure Monitor that notifies me when 
my Container App CPU usage exceeds 80% for 5 minutes?
```

Create the alert:

```bash
# Get Container App resource ID
CONTAINER_APP_ID=$(az containerapp show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --query id -o tsv)

# Create CPU alert
az monitor metrics alert create \
  --name "High-CPU-Container-App" \
  --resource-group $RESOURCE_GROUP \
  --scopes $CONTAINER_APP_ID \
  --condition "avg UsageNanoCores > 800000000" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action "SRE-Workshop-Alerts" \
  --description "Container App CPU usage above 80%"
```

### Step 3: Create Memory Alert

```bash
az monitor metrics alert create \
  --name "High-Memory-Container-App" \
  --resource-group $RESOURCE_GROUP \
  --scopes $CONTAINER_APP_ID \
  --condition "avg WorkingSetBytes > 858993459" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action "SRE-Workshop-Alerts" \
  --description "Container App memory usage above 80% (800MB of 1GB)"
```

### Step 4: Create Database CPU Alert

```bash
# Get PostgreSQL resource ID
POSTGRES_ID=$(az postgres flexible-server show \
  --resource-group $RESOURCE_GROUP \
  --name $(az postgres flexible-server list \
    --resource-group $RESOURCE_GROUP \
    --query "[0].name" -o tsv) \
  --query id -o tsv)

# Create database CPU alert
az monitor metrics alert create \
  --name "High-CPU-Database" \
  --resource-group $RESOURCE_GROUP \
  --scopes $POSTGRES_ID \
  --condition "avg cpu_percent > 80" \
  --window-size 5m \
  --evaluation-frequency 1m \
  --action "SRE-Workshop-Alerts" \
  --description "PostgreSQL CPU usage above 80%"
```

### Step 5: Create Database Storage Alert

```bash
az monitor metrics alert create \
  --name "Low-Storage-Database" \
  --resource-group $RESOURCE_GROUP \
  --scopes $POSTGRES_ID \
  --condition "avg storage_percent > 85" \
  --window-size 5m \
  --evaluation-frequency 5m \
  --action "SRE-Workshop-Alerts" \
  --description "PostgreSQL storage usage above 85%"
```

### Step 6: Verify Alerts

```bash
# List all alerts
az monitor metrics alert list \
  --resource-group $RESOURCE_GROUP \
  --output table

# Get detailed alert configuration
az monitor metrics alert show \
  --name "High-CPU-Container-App" \
  --resource-group $RESOURCE_GROUP
```

### Step 7: Test Alert (Optional)

Generate CPU load to trigger alert:

```bash
# Generate load using API requests
for i in {1..1000}; do
  curl -s -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_URL/api/items" > /dev/null &
done
```

### Key Learnings

- Metric alerts monitor resource utilization
- Action groups centralize notification configuration
- Thresholds should be based on SLOs
- Alert evaluation frequency affects detection speed

---

## Exercise 2: Log-Based Alerts

### Scenario

Set up alerts based on application logs to catch errors and anomalies.

### Step 1: Create Failed Request Alert

In your Azure SRE Agent chat, ask:
```
How do I create a log-based alert in Application Insights that fires 
when there are more than 10 failed requests (5xx errors) in 5 minutes?
```

Get Application Insights resource ID:

```bash
APP_INSIGHTS_ID=$(az monitor app-insights component show \
  --app $(az resource list \
    --resource-group $RESOURCE_GROUP \
    --resource-type "microsoft.insights/components" \
    --query "[0].name" -o tsv) \
  --resource-group $RESOURCE_GROUP \
  --query id -o tsv)
```

Create the alert:

```bash
az monitor scheduled-query create \
  --name "High-Error-Rate" \
  --resource-group $RESOURCE_GROUP \
  --scopes $APP_INSIGHTS_ID \
  --condition "count > 10" \
  --condition-query "requests | where resultCode startswith '5' | summarize count()" \
  --window-size 5m \
  --evaluation-frequency 5m \
  --action-groups "SRE-Workshop-Alerts" \
  --description "More than 10 server errors in 5 minutes" \
  --severity 2
```

### Step 2: Create Slow Response Time Alert

```bash
az monitor scheduled-query create \
  --name "Slow-Response-Time" \
  --resource-group $RESOURCE_GROUP \
  --scopes $APP_INSIGHTS_ID \
  --condition "avg_duration > 5000" \
  --condition-query "requests | summarize avg_duration = avg(duration)" \
  --window-size 5m \
  --evaluation-frequency 5m \
  --action-groups "SRE-Workshop-Alerts" \
  --description "Average response time above 5 seconds" \
  --severity 3
```

### Step 3: Create Exception Alert

```bash
az monitor scheduled-query create \
  --name "Application-Exceptions" \
  --resource-group $RESOURCE_GROUP \
  --scopes $APP_INSIGHTS_ID \
  --condition "count > 5" \
  --condition-query "exceptions | summarize count()" \
  --window-size 5m \
  --evaluation-frequency 5m \
  --action-groups "SRE-Workshop-Alerts" \
  --description "More than 5 exceptions in 5 minutes" \
  --severity 2
```

### Step 4: Create Database Connection Error Alert

```bash
az monitor scheduled-query create \
  --name "Database-Connection-Errors" \
  --resource-group $RESOURCE_GROUP \
  --scopes $APP_INSIGHTS_ID \
  --condition "count > 3" \
  --condition-query "traces | where message contains 'database' and message contains 'error' | summarize count()" \
  --window-size 10m \
  --evaluation-frequency 5m \
  --action-groups "SRE-Workshop-Alerts" \
  --description "Database connection errors detected" \
  --severity 1
```

### Step 5: Verify Log Alerts

```bash
# List scheduled query rules
az monitor scheduled-query list \
  --resource-group $RESOURCE_GROUP \
  --output table
```

### Step 6: Test Log Alert

Generate errors to trigger alerts:

```bash
# Trigger 5xx errors by making invalid requests
for i in {1..15}; do
  curl -X POST \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    -H "Content-Type: application/json" \
    -d '{"invalid": "data"}' \
    "$APIM_URL/api/items"
done
```

Wait 5-10 minutes and check if alert fired:

```bash
az monitor metrics alert show \
  --name "High-Error-Rate" \
  --resource-group $RESOURCE_GROUP \
  --query "properties.lastUpdatedTime"
```

### Key Learnings

- Log alerts use KQL queries for complex conditions
- Scheduled queries run at defined intervals
- Alert severity helps prioritize incidents
- Log-based alerts can detect application-specific issues

---

## Exercise 3: Availability Tests

### Scenario

Set up synthetic monitoring to test API availability from multiple regions.

### Step 1: Create Standard Availability Test

In your Azure SRE Agent chat, ask:
```
How do I create an availability test in Application Insights 
that checks my API endpoint every 5 minutes from multiple regions?
```

Using Azure Portal (CLI doesn't fully support availability tests):

1. Navigate to Application Insights
2. Go to **Availability**
3. Click **+ Add Standard test**
4. Configure:
   - Test name: "API-Health-Check"
   - URL: `$APIM_URL/api/health`
   - Test frequency: 5 minutes
   - Test locations: Select 3-5 locations
   - Success criteria: Status code 200
   - Timeout: 30 seconds
   - Parse dependent requests: No
5. Click **Create**

### Step 2: Create Multi-Step Availability Test

For more complex scenarios (POST requests, authentication):

1. Click **+ Add Custom test**
2. Configure:
   - Test name: "API-CRUD-Operations"
   - Upload web test: (Create XML file)

Example XML for multi-step test:

```xml
<WebTest Name="API-CRUD-Test" Enabled="True" Timeout="120">
  <Items>
    <Request Method="GET" Url="$APIM_URL/api/health" 
      ThinkTime="0" Timeout="30">
      <Headers>
        <Header Name="Ocp-Apim-Subscription-Key" Value="$SUBSCRIPTION_KEY"/>
      </Headers>
      <ValidationRules>
        <ValidationRule Classname="Microsoft.VisualStudio.TestTools.WebTesting.Rules.ValidateResponseStatusCode" 
          DisplayName="Status Code" Expected="200" />
      </ValidationRules>
    </Request>
    <Request Method="GET" Url="$APIM_URL/api/items"
      ThinkTime="2" Timeout="30">
      <Headers>
        <Header Name="Ocp-Apim-Subscription-Key" Value="$SUBSCRIPTION_KEY"/>
      </Headers>
    </Request>
  </Items>
</WebTest>
```

### Step 3: Configure Availability Alert

Application Insights automatically creates alerts for availability tests:

1. In Availability, click on your test
2. Click **Open Rules (Alerts) page**
3. Edit the alert rule:
   - Alert criteria: Failed locations >= 2 over 5 minutes
   - Action group: SRE-Workshop-Alerts
   - Severity: 1 (Critical)

### Step 4: View Availability Results

```bash
# Query availability results
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    availabilityResults
    | where timestamp > ago(1h)
    | summarize 
        SuccessRate = avg(success) * 100,
        AvgDuration = avg(duration)
      by name, location
    | order by SuccessRate asc
  " \
  --output table
```

### Key Learnings

- Availability tests provide proactive monitoring
- Multi-region testing detects geographic issues
- Synthetic monitoring catches issues before users do
- Availability SLA tracking helps meet targets

---

## Exercise 4: Create Monitoring Dashboard

### Scenario

Build a comprehensive dashboard for monitoring application health.

### Step 1: Create Dashboard Using Portal

1. Navigate to **Dashboards** in Azure Portal
2. Click **+ New dashboard**
3. Name it: "SRE Workshop - Application Health"

### Step 2: Add Key Metrics Tiles

Add the following tiles:

**Container App Metrics:**
- CPU Usage (avg over time)
- Memory Usage (avg over time)
- Request Count (sum over time)
- Response Time (avg over time)

**PostgreSQL Metrics:**
- CPU Percent
- Memory Percent
- Storage Percent
- Active Connections

**Application Insights:**
- Failed Requests
- Server Response Time
- Availability (from availability tests)
- Exception Count

### Step 3: Add Log Analytics Queries

Add custom query tiles:

**Error Rate by Operation:**
```kusto
requests
| where timestamp > ago(24h)
| summarize 
    TotalRequests = count(),
    FailedRequests = countif(success == false),
    ErrorRate = (countif(success == false) * 100.0 / count())
  by name
| order by ErrorRate desc
```

**Request Duration Percentiles:**
```kusto
requests
| where timestamp > ago(1h)
| summarize 
    p50 = percentile(duration, 50),
    p95 = percentile(duration, 95),
    p99 = percentile(duration, 99)
  by bin(timestamp, 5m)
| render timechart
```

**Top Exceptions:**
```kusto
exceptions
| where timestamp > ago(24h)
| summarize Count = count() by type, outerMessage
| order by Count desc
| take 10
```

### Step 4: Export and Share Dashboard

```bash
# Export dashboard to JSON (from portal or use API)
# Dashboards can be shared with team members or exported for backup
```

### Step 5: Ask SRE Agent for Dashboard Recommendations

```
"I have a FastAPI application on Container Apps with PostgreSQL and APIM. 
What key metrics should I include in my monitoring dashboard for SRE purposes?"
```

### Key Learnings

- Dashboards provide at-a-glance health status
- Custom KQL queries add application-specific insights
- Sharing dashboards improves team visibility
- Regular dashboard reviews help identify trends

---

## Exercise 5: Incident Investigation with Azure SRE Agent

### Scenario

An alert fired indicating high error rates. Use Azure SRE Agent to investigate and document the incident.

### Step 1: Receive Alert Notification

Simulate receiving an alert:
```
"Alert: High-Error-Rate fired at 2025-11-06 14:30 UTC
More than 10 server errors detected in the last 5 minutes
Resource: workshop-api in sre-workshop-pk"
```

### Step 2: Initial Triage with Azure SRE Agent

In your Azure SRE Agent chat, ask:
```
I received an alert for high error rate (>10 5xx errors in 5 minutes) 
from my API at 14:30 UTC. What's the first thing I should check to 
understand the scope and impact?
```

The agent will guide you through:
1. Check current error rate
2. Identify affected endpoints
3. Determine if issue is ongoing
4. Assess user impact

### Step 3: Gather Context

Follow the agent's recommendations:

```bash
# Check current error rate
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    requests
    | where timestamp > ago(15m)
    | summarize 
        Total = count(),
        Failed = countif(resultCode startswith '5'),
        ErrorRate = (countif(resultCode startswith '5') * 100.0 / count())
      by bin(timestamp, 1m)
    | order by timestamp desc
  " \
  --output table

# Identify affected endpoints
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    requests
    | where timestamp > ago(15m) and resultCode startswith '5'
    | summarize Count = count() by name, resultCode
    | order by Count desc
  " \
  --output table
```

### Step 4: Analyze Error Details

In your Azure SRE Agent chat, ask:
```
The errors are on POST /items endpoint with 500 status code. 
How can I see the actual error messages from Application Insights?
```

```bash
# Get error details
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    requests
    | where timestamp > ago(15m) 
      and name == 'POST /items'
      and resultCode == '500'
    | project timestamp, resultCode, duration, customDimensions
    | take 10
  " \
  --output json
```

### Step 5: Check Related Telemetry

```bash
# Check for exceptions
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    exceptions
    | where timestamp > ago(15m)
    | project timestamp, type, outerMessage, problemId
    | take 10
  " \
  --output table

# Check traces/logs
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    traces
    | where timestamp > ago(15m) and message contains 'error'
    | project timestamp, message, severityLevel
    | take 20
  " \
  --output table
```

### Step 6: Correlate with Infrastructure

In your Azure SRE Agent chat, ask:
```
The errors started at 14:30. How can I check if there were 
any infrastructure changes or deployments around that time?
```

```bash
# Check recent deployments
az containerapp revision list \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --query "[].{Name: name, Created: properties.createdTime, Active: properties.active}" \
  --output table

# Check activity log for changes
az monitor activity-log list \
  --resource-group $RESOURCE_GROUP \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
  --query "[].{Time: eventTimestamp, Operation: operationName.localizedValue, Status: status.localizedValue}" \
  --output table
```

### Step 7: Identify Root Cause

After gathering data, ask Azure SRE Agent:
```
Based on these findings:
- Errors started at 14:30
- Only POST /items endpoint affected
- Error message: 'database connection refused'
- No recent deployments
- PostgreSQL CPU at 5%

What's the likely root cause and how should I fix it?
```

### Key Learnings

- Systematic investigation follows the request path
- Application Insights correlates related telemetry
- Activity logs show infrastructure changes
- Azure SRE Agent helps form hypotheses from symptoms

---

## Exercise 6: Root Cause Analysis (RCA) Report

### Scenario

After resolving an incident, document it with an RCA report using Azure SRE Agent.

### Step 1: Prepare Incident Details

Gather:
- Alert timestamp
- Detection time
- Resolution time
- Affected components
- User impact
- Timeline of investigation
- Root cause
- Fix applied

### Step 2: Ask Azure SRE Agent to Draft RCA

In your Azure SRE Agent chat, ask:
```
Help me write an RCA report for this incident:
- Date: 2025-11-06 14:30-15:15 UTC
- Issue: High error rate (85% failures) on POST /items endpoint
- Detection: Azure Monitor alert
- Root cause: PostgreSQL max_connections limit reached due to missing connection pooling
- Impact: Users unable to create items for 45 minutes
- Fix: Implemented connection pooling with pool_size=5, max_overflow=10
- Prevention: Added alert for database connection count
```

### Step 3: Review Azure SRE Agent's Draft

The agent will generate something like:

```markdown
# Root Cause Analysis: API POST Failures - November 6, 2025

## Executive Summary
On November 6, 2025, between 14:30 and 15:15 UTC (45 minutes), users 
experienced 85% failure rate when creating items via the API. The issue 
was caused by PostgreSQL connection exhaustion due to missing connection 
pooling in the application.

## Impact
- **Duration:** 45 minutes (14:30-15:15 UTC)
- **Affected Users:** All users attempting to create items
- **Error Rate:** 85% of POST /items requests
- **Service Level Impact:** Availability SLO breached (99.9% → 96.2%)

## Timeline
- **14:30 UTC** - Alert fired: High-Error-Rate >10 5xx errors
- **14:32 UTC** - On-call engineer notified
- **14:35 UTC** - Investigation started using SRE Agent
- **14:42 UTC** - Root cause identified: database connection limit
- **14:50 UTC** - Fix deployed: connection pooling implemented
- **15:00 UTC** - Fix verified, error rate dropping
- **15:15 UTC** - Error rate normalized, incident closed

## Root Cause
The FastAPI application was creating a new PostgreSQL connection for 
each request without connection pooling. Under load, this quickly 
exceeded PostgreSQL's max_connections limit (100), causing new 
connection attempts to fail.

## Resolution
Implemented SQLAlchemy connection pooling with:
- pool_size=5 (persistent connections per replica)
- max_overflow=10 (additional connections when needed)
- pool_recycle=3600 (recycle connections hourly)
- pool_pre_ping=True (verify connections before use)

## Prevention
1. Added monitoring alert for database active_connections >80
2. Load tested application with realistic traffic patterns
3. Documented connection pooling requirements
4. Added connection pool metrics to dashboard

## Action Items
- [ ] Review all services for proper connection pooling
- [ ] Implement load testing in CI/CD pipeline
- [ ] Create runbook for database connection issues
- [ ] Schedule quarterly load testing exercises

## Lessons Learned
- Connection pooling is critical for database-backed APIs
- Load testing reveals scalability issues before production
- Application Insights quickly identified the affected endpoint
- Azure SRE Agent expedited root cause identification
```

### Step 4: Enhance RCA with Details

In your Azure SRE Agent chat, ask:
```
Add a technical details section to the RCA explaining how 
connection pooling prevents this issue
```

### Step 5: Save and Share RCA

```bash
# Create RCA directory if it doesn't exist
mkdir -p incidents

# Save RCA report
cat > incidents/rca-2025-11-06-api-failures.md << 'EOF'
[Paste Azure SRE Agent's RCA here]
EOF

# Commit to repository for team visibility
git add incidents/rca-2025-11-06-api-failures.md
git commit -m "docs: Add RCA for API failure incident on 2025-11-06"
```

### Key Learnings

- RCA documents prevent repeated issues
- Azure SRE Agent accelerates RCA writing
- Action items improve future reliability
- Sharing RCAs builds team knowledge

---

## Exercise 7: Proactive SLO Monitoring

### Scenario

Define and monitor Service Level Objectives (SLOs) for your API.

### Step 1: Define SLOs with Azure SRE Agent

In your Azure SRE Agent chat, ask:
```
I have a REST API serving customer requests. Help me define 
appropriate SLOs for availability, latency, and error rate.
```

Example SLOs:
- **Availability:** 99.9% (43 minutes downtime/month)
- **Latency P95:** < 500ms for 95% of requests
- **Error Rate:** < 0.1% (1 in 1000 requests)

### Step 2: Calculate Error Budget

In your Azure SRE Agent chat, ask:
```
With a 99.9% availability SLO, what's my error budget for one month?
```

**Answer:** 43.2 minutes of downtime or 0.1% error rate

### Step 3: Create SLO Tracking Query

```bash
# Create custom log query for SLO tracking
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    requests
    | where timestamp > startofmonth(now())
    | summarize 
        TotalRequests = count(),
        SuccessfulRequests = countif(success == true),
        AvailabilityPercent = (countif(success == true) * 100.0 / count()),
        ErrorBudgetUsed = (100 - (countif(success == true) * 100.0 / count())) / 0.1 * 100,
        P95Latency = percentile(duration, 95)
    | extend 
        AvailabilitySLO = 99.9,
        LatencySLO = 500,
        AvailabilityStatus = iff(AvailabilityPercent >= 99.9, '✓ Meeting SLO', '✗ Breaching SLO'),
        LatencyStatus = iff(P95Latency <= 500, '✓ Meeting SLO', '✗ Breaching SLO')
  " \
  --output table
```

### Step 4: Create SLO Alert

```bash
# Alert when error budget is 75% consumed
az monitor scheduled-query create \
  --name "SLO-Error-Budget-Warning" \
  --resource-group $RESOURCE_GROUP \
  --scopes $APP_INSIGHTS_ID \
  --condition "error_budget_used > 75" \
  --condition-query "
    requests
    | where timestamp > startofmonth(now())
    | summarize 
        SuccessRate = (countif(success == true) * 100.0 / count()),
        error_budget_used = (100 - (countif(success == true) * 100.0 / count())) / 0.1 * 100
  " \
  --window-size 1h \
  --evaluation-frequency 1h \
  --action-groups "SRE-Workshop-Alerts" \
  --description "Error budget 75% consumed - implement corrective actions" \
  --severity 2
```

### Step 5: Add SLO Dashboard

Add to your monitoring dashboard:
- Current month availability %
- Error budget remaining
- P95 latency trend
- SLO burn rate

### Key Learnings

- SLOs balance reliability with development velocity
- Error budgets allow for planned changes
- Tracking SLOs drives operational decisions
- SRE Agent helps calculate and interpret SLOs

---

## Exercise 8: Alert Fatigue Management

### Scenario

You're getting too many alerts. Use SRE Agent to optimize your alerting strategy.

### Step 1: Analyze Alert Patterns

Ask SRE Agent:
```
"I'm receiving 20-30 alerts per day, many are false positives or 
low severity. How should I tune my alerts to reduce noise while 
maintaining effective monitoring?"
```

### Step 2: Review Alert Rules

```bash
# List all alerts and their fire history
az monitor metrics alert list \
  --resource-group $RESOURCE_GROUP \
  --query "[].{Name: name, Enabled: enabled, Severity: properties.severity}" \
  --output table
```

### Step 3: Identify Noisy Alerts

```bash
# Query alert firing history from activity log
az monitor activity-log list \
  --resource-group $RESOURCE_GROUP \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ) \
  --query "[?contains(operationName.value, 'Microsoft.Insights/AlertRules')].{Time: eventTimestamp, Alert: operationName.localizedValue, Status: status.localizedValue}" \
  --output table
```

### Step 4: Apply SRE Agent Recommendations

Common optimization strategies:
1. **Increase thresholds** for less critical alerts
2. **Lengthen time windows** to avoid transient spikes
3. **Combine related alerts** into single rules
4. **Disable low-value alerts** during business hours
5. **Use multi-condition alerts** (AND logic)

### Step 5: Implement Alert Tuning

```bash
# Example: Increase CPU threshold from 80% to 90%
az monitor metrics alert update \
  --name "High-CPU-Container-App" \
  --resource-group $RESOURCE_GROUP \
  --condition "avg UsageNanoCores > 900000000"

# Example: Lengthen evaluation window from 5m to 10m
az monitor metrics alert update \
  --name "High-Memory-Container-App" \
  --resource-group $RESOURCE_GROUP \
  --window-size 10m
```

### Step 6: Create Alert Runbooks

Ask SRE Agent:
```
"Create a runbook template for responding to 'High-CPU-Container-App' alerts"
```

SRE Agent will provide:
- Investigation steps
- Common causes
- Resolution procedures
- Escalation criteria

### Key Learnings

- Alert quality over quantity
- Regular alert review prevents fatigue
- Runbooks improve response consistency
- SRE Agent helps optimize alert rules

---

## Advanced Challenge: Distributed Tracing

### Scenario

Implement end-to-end tracing across APIM → Container App → PostgreSQL.

### Step 1: Enable Distributed Tracing

Application Insights automatically tracks requests across services when:
- Services use the same instrumentation key
- Correlation IDs are propagated
- OpenTelemetry or Application Insights SDK is used

### Step 2: Analyze Request Flow

Ask SRE Agent:
```
"How can I trace a single request through APIM, Container App, 
and database to identify where time is spent?"
```

```bash
# Query end-to-end transaction
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    requests
    | where timestamp > ago(1h)
    | take 10
    | join kind=inner (
        dependencies
        | where timestamp > ago(1h)
      ) on operation_Id
    | project 
        timestamp,
        RequestName = name,
        RequestDuration = duration,
        DependencyName = name1,
        DependencyDuration = duration1,
        DependencyType = type1
    | order by timestamp desc
  " \
  --output table
```

### Step 3: Visualize in Application Map

1. Navigate to Application Insights
2. Open **Application Map**
3. View components and dependencies
4. Click on connections to see metrics
5. Identify slow dependencies

### Key Learnings

- Distributed tracing reveals multi-service bottlenecks
- Application Map visualizes service dependencies
- Correlation IDs enable end-to-end tracing
- Database queries often cause slowdowns

---

## Best Practices Summary

### Alert Design
✅ Alert on symptoms, not causes  
✅ Use actionable alert descriptions  
✅ Include runbook links in alerts  
✅ Set appropriate severity levels  
✅ Test alerts regularly  

### Monitoring Strategy
✅ Monitor the four golden signals: latency, traffic, errors, saturation  
✅ Use both metrics and logs  
✅ Implement synthetic monitoring  
✅ Track SLOs, not just SLAs  
✅ Review dashboards in team meetings  

### Incident Response
✅ Document all incidents with RCAs  
✅ Use SRE Agent to accelerate investigation  
✅ Follow a consistent incident process  
✅ Share learnings across teams  
✅ Track MTTR and MTTD metrics  

### Using SRE Agent Effectively
✅ Provide context in questions  
✅ Ask for KQL queries and CLI commands  
✅ Request runbooks and checklists  
✅ Use it to draft RCA reports  
✅ Validate recommendations before applying  

---

## Summary Checklist

After completing Part 3, you should have:

- [ ] Action group configured for alerts
- [ ] 4+ metric alerts on critical resources
- [ ] 3+ log-based alerts for application issues
- [ ] Availability tests running from multiple regions
- [ ] Comprehensive monitoring dashboard
- [ ] SLO tracking queries created
- [ ] Practice incident investigation with SRE Agent
- [ ] Written at least one RCA report
- [ ] Optimized alerts to reduce noise
- [ ] Documented alert runbooks

---

## What's Next?

You've now completed the core workshop exercises! Consider these advanced topics:

**[Advanced Exercises](./advanced-exercises.md)** (Optional):
- Auto-remediation with Azure Automation
- Chaos engineering experiments
- Multi-region failover testing
- Security incident investigation
- Performance optimization deep-dive

---

## Additional Resources

- [Azure Monitor Best Practices](https://docs.microsoft.com/en-us/azure/azure-monitor/best-practices)
- [Application Insights Query Language (KQL)](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/)
- [SRE Book - Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/)
- [Creating Good Alerts](https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-overview)
- [Writing RCA Reports](https://sre.google/sre-book/postmortem-culture/)

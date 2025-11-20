# Part 3: Monitoring & Alerts

## Overview

In this exercise, you'll learn to set up proactive monitoring and alerting for your Azure infrastructure. You'll configure Azure Monitor alerts, create dashboards, and use Azure SRE Agent to investigate incidents and create Root Cause Analysis (RCA) reports.

**Estimated Time:** 60-90 minutes

## Prerequisites

- Completed [Part 1: Setup](./part1-setup.md) and [Part 2: Troubleshooting](./part2-troubleshooting.md)
- Working infrastructure with API deployed
- Application Insights configured
- Azure SRE Agent created and configured (from Part 2)

### Load Environment Variables

If you're in a new terminal session, load your workshop environment:

```bash
# Load the workshop environment helper and variables
source scripts/workshop-env.sh

# Verify all required variables are set
verify_vars
```

## Learning Objectives

By the end of this exercise, you will:
- Configure Azure Monitor metric alerts using percentage-based metrics
- Create action groups for alert notifications
- Use Azure Container Apps chaos engineering to test alerts
- Configure Azure SRE Agent incident response plans
- Understand Review mode vs. Autonomous mode for agent actions
- Implement automated incident detection and remediation workflows
- Monitor and analyze SRE Agent's automated incident response

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
  --action email Admin your-email@example.com
```

### Step 2: Create CPU Alert for Container App

Create the alert:

```bash
# Get Container App resource ID and persist it
CONTAINER_APP_ID=$(az containerapp show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --query id -o tsv)

# Save it for future use
set_var CONTAINER_APP_ID "$CONTAINER_APP_ID"

# Create CPU alert using percentage (Preview)
az monitor metrics alert create \
  --name "High-CPU-Container-App-percent" \
  --resource-group $RESOURCE_GROUP \
  --scopes $CONTAINER_APP_ID \
  --condition "avg CpuPercentage > 80" \
  --window-size 1m \
  --evaluation-frequency 1m \
  --action "SRE-Workshop-Alerts" \
  --description "Container App CPU usage above 80%"
```

### Step 3: Create Memory Alert

```bash
# Create Memory alert using percentage (Preview)
az monitor metrics alert create \
  --name "High-Memory-Container-App-Percentage" \
  --resource-group $RESOURCE_GROUP \
  --scopes $CONTAINER_APP_ID \
  --condition "avg MemoryPercentage > 80" \
  --window-size 1m \
  --evaluation-frequency 1m \
  --action "SRE-Workshop-Alerts" \
  --description "Container App memory usage above 80%"
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

### Step 7: Test Alert by Generating CPU Load

Now you'll trigger the CPU alert by using the Chaos Dashboard to simulate high CPU usage.

**Enable CPU Spike:**

1. Open the Chaos Dashboard in your browser (from Part 2, Step 4)
2. Find the ** CPU Spike** fault card
3. Set the intensity slider to **90** (this will cause the container to use ~90 CPU)
4. Click **Enable** to activate the CPU spike

**Monitor the Alert:**

Wait 3-5 minutes for the alert to trigger. 

The alert will fire when the average CPU usage exceeds 80% over a 1-minute window. The alert is evaluated every minute. It should trigger within 2-5 minutes of sustained high CPU.

**Expected Result:** You should receive an email notification when the alert fires (if you configured an email in Step 1).

### Step 8: Clear Alert by Stopping CPU Load

Once you've verified the alert fired, disable the chaos fault to clear the alert.

**Disable CPU Spike:**

1. In the Chaos Dashboard, find the **CPU Spike** card
2. Click **Disable** to stop the CPU spike

**Check Alert Status:**

```bash
# View alert history
az monitor metrics alert show \
  --name "High-CPU-Container-App" \
  --resource-group $RESOURCE_GROUP \
  --query "{name:name, enabled:enabled, description:description, condition:criteria}" \
  --output json | jq
```

---

## Exercise 2: Create an Incident Response Plan

### Scenario

In Exercise 1, you created alerts that send email notifications. However, in production SRE environments, you need automated incident response workflows that can diagnose issues, suggest remediation, and even take corrective actions. In this exercise, you'll configure an **Incident Response Plan** in Azure SRE Agent that automatically handles incidents triggered by your High-CPU alert.

### What is an Incident Response Plan?

An incident response plan in Azure SRE Agent defines:
- **Which incidents** should be handled (filters)
- **How autonomous** the agent should be (review vs. autonomous mode)
- **Custom instructions** for how the agent should diagnose and resolve issues
- **What tools** the agent can use during incident response

When an Azure Monitor alert fires, the SRE Agent can automatically:
1. Detect the incident and create a new investigation thread
2. Gather diagnostic data from affected resources
3. Perform root cause analysis
4. Suggest remediation steps
5. Execute fixes (if configured in autonomous mode)

### Step 1: Access Incident Management Settings

Navigate to the SRE Agent incident management configuration.

**Note:** Azure SRE Agent is managed through the Azure Portal. There are no Azure CLI commands for SRE Agent at this time.

**In the Azure Portal:**

1. Search for and select **Azure SRE Agent**
2. Select your agent (created in Part 2, should be in resource group `${BASE_NAME}-sre-agent-rg`)
3. Select the **Incident management** tab


### Step 2: Review Default Incident Response Plan

Azure SRE Agent automatically includes a default incident response plan that:
- Connects to Azure Monitor alerts (already configured)
- Processes all low-priority incidents
- Runs in **Review mode** (requires human approval before taking actions)

**View the default plan:**

In the portal, you should see:
- **Incident platform**: Azure Monitor alerts
- **Default response plan**: Enabled
- **Autonomy level**: Review mode
- **Filters**: All impacted services, Low priority

### Step 3: Create a Custom Response Plan for High-CPU Incidents

Create a specialized incident response plan specifically for CPU-related issues.

**In the Azure Portal:**

1. In the **Incident management** tab, select **Create response plan**
2. Configure the plan with the following settings:

**Plan Details:**
- **Incident response plan name**: `High-CPU-Response-Plan`

**Choose filter parameters** (Step 1 of wizard):
- **Severity**: Sev2
- **Title contains**: `CPU` (to match your "High-CPU-Container-App" alert)

**Agent autonomy level**
- **Review (default**)


```

Click **Create response plan** to save your configuration.

### Step 7: Trigger a Real Incident

Generate a real high-CPU incident to see your response plan in action:

**Enable CPU Spike:**

1. Open the Chaos Dashboard
2. Find the **CPU Spike** fault
3. Set intensity to **90%**
4. Click **Enable**

**Wait for the alert to fire** (3-5 minutes based on your alert configuration)

### Step 8: Monitor SRE Agent's Automated Response

Once the alert fires, Azure SRE Agent will automatically process the incident:

**In the Azure Portal:**

1. Go to your SRE Agent
2. Select the **Chat** tab
3. Look for a new conversation thread created automatically

The agent should:
- Display the incident details (Alert: High-CPU-Container-App)
- Show its diagnostic analysis
- Provide CPU metrics and trends
- Identify the chaos fault as the root cause
- Suggest disabling the CPU Spike fault as remediation

**Review the agent's analysis:**

The agent will present its findings and wait for your approval (since you're in Review mode). Review the proposed actions before approving.

### Step 9: Approve Remediation (Optional)

If you want the agent to take action:

1. Review the agent's recommended remediation steps
2. If you approve, click **Approve** or respond with "yes, please proceed"
3. The agent will execute the approved actions (e.g., suggest disabling the chaos fault)

**Alternatively, manually remediate:**

Go to the Chaos Dashboard and click **Disable** on the CPU Spike fault.

### Step 10: Review Incident Summary

After the incident is resolved, the agent provides a summary:

**In the Incident Management dashboard:**

1. Select the **Incident management** tab
2. Review the incident metrics:
   - Incidents reviewed by agent
   - Incidents mitigated
   - Incidents requiring human action

**Check the incident thread:**

In the chat interface, review:
- Complete diagnostic timeline
- Root cause analysis
- Actions taken or recommended
- Incident resolution confirmation

### Key Learnings

- **Incident Response Plans** automate the detection and handling of specific incident types
- **Filters** ensure the right plan handles the right incidents
- **Custom instructions** guide the agent's diagnostic and remediation approach
- **Review mode** provides safety by requiring human approval for actions
- **Autonomous mode** enables full automation for well-understood incident patterns
- **Testing** allows you to validate response plans before deploying to production

### Best Practices for Production

1. **Start with Review Mode**: Gain confidence in agent recommendations before enabling autonomous actions
2. **Create Specialized Plans**: Different plans for different incident types (CPU, memory, errors, etc.)
3. **Include Runbook Knowledge**: Add your team's tribal knowledge to custom instructions
4. **Test Regularly**: Use historical incidents to validate and refine response plans
5. **Monitor Agent Actions**: Review incident dashboard regularly to identify improvement opportunities
6. **Iterate**: Update custom instructions based on incident outcomes and team feedback

---

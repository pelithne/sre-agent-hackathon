# Part 1: Setup and Deployment

## Overview

In this exercise, you'll deploy the complete workshop infrastructure to Azure, including:
- API Management (Consumption tier)
- Container Apps with a FastAPI application
- PostgreSQL Flexible Server
- Application Insights for monitoring
- Virtual Network with proper segmentation

**Estimated Time:** 30-45 minutes (including ~15 minutes deployment time)

## Prerequisites

Before starting, ensure you have:

1. **Azure Subscription** with appropriate permissions to create resources
2. **Azure CLI** installed and configured ([Install guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
3. **Git** installed
4. **jq** installed for JSON parsing (optional, for testing)

> **Note:** Docker is NOT required. Container images are built using Azure Container Registry build tasks.

## Learning Objectives

By the end of this exercise, you will:
- Deploy cloud infrastructure using Azure Bicep
- Configure API Management with backend services
- Set up Container Apps with managed identity for ACR access
- Test API endpoints through APIM gateway
- Understand the workshop architecture

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/pelithne/sre-agent-hack.git
cd sre-agent-hack
```

---

## Step 2: Login to Azure

```bash
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription <your-subscription-id>

# Verify your subscription
az account show
```

---

## Step 3: Setup Workshop Environment Helper

Load the workshop environment helper that will automatically persist variables across shell sessions:

```bash
# Source the workshop environment helper
source scripts/workshop-env.sh

# This will:
# - Load any existing workshop variables from ~/.workshop-env
# - Provide functions for setting persistent variables
# - Ensure variables survive shell timeouts and new sessions
```

If you see "No workshop environment file found", that's normal for first-time setup.

---

## Step 4: Create Resource Group

Choose a unique base name (3-15 characters, lowercase) that will be used for all resources:

```bash
# Set and persist variables using the workshop helper - customize with your initials
set_var "BASE_NAME" "sre<your-initials>"  # Must be 3-15 characters, lowercase
set_var "LOCATION" "swedencentral"        # Or your preferred region
set_var "RESOURCE_GROUP" "${BASE_NAME}-workshop"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

**Example:**
```bash
set_var "BASE_NAME" "srepk"
set_var "LOCATION" "swedencentral"
set_var "RESOURCE_GROUP" "${BASE_NAME}-workshop"
```

> **Alternative: Traditional Environment Variables**
> 
> If you prefer to work with traditional environment variables instead of the workshop helper:
> ```bash
> export BASE_NAME="srepk"
> export LOCATION="swedencentral"
> export RESOURCE_GROUP="${BASE_NAME}-workshop"
> ```
> 
> **Note:** With traditional variables, you'll need to manually re-set them if your shell session times out.

> **Note:** The `BASE_NAME` will be used to generate names for all Azure resources (ACR, Container App, APIM, etc.) to ensure they are unique and consistently named. The `set_var` function automatically persists variables to `~/.workshop-env` so they survive shell timeouts.

---

## Step 5: Two-Phase Deployment Approach

> **Important**: You MUST complete Phase 1 before attempting Phase 2 or 3. The phases have dependencies and cannot be skipped.

### Phase 1: Infrastructure Deployment (Without Container Apps)

First, deploy the core infrastructure:

```bash
az deployment group create \
  --name infrastructure-deployment-$(date +%Y%m%d-%H%M%S) \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/infrastructure.bicep \
  --parameters baseName=$BASE_NAME \
  --parameters postgresAdminPassword='YourSecurePassword123'
```

**Deployment time: ~8-12 minutes** 

> **What this deploys:**
> - Azure Container Registry (ACR) with managed identity integration
> - Virtual Network with proper segmentation
> - Log Analytics and Application Insights for monitoring
> - PostgreSQL Flexible Server with private networking
> - API Management service (infrastructure only)
> - Managed Identity with ACR access permissions

**Verify Phase 1 Success:**
```bash
# Check that ACR was created
az acr list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv

# If this returns empty, Phase 1 failed - check deployment status
az deployment group show \
  --name $(az deployment group list --resource-group $RESOURCE_GROUP --query "[?starts_with(name, 'infrastructure-deployment-')].name | [-1]" -o tsv) \
  --resource-group $RESOURCE_GROUP \
  --query "properties.provisioningState"
```

### Phase 2: Build Container Image

Once infrastructure deployment completes, build your container image:

```bash
# Get ACR name directly from the resource group (much simpler!)
ACR_NAME=$(az acr list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)

# Save ACR name for later use
set_var "ACR_NAME" "$ACR_NAME"

echo "ACR Name: $ACR_NAME"

# Build and push the image using ACR build tasks
az acr build \
  --registry $ACR_NAME \
  --image workshop-api:v1.0.0 \
  --file src/api/Dockerfile \
  src/api
```

### Phase 3: Deploy Container Apps

Now deploy the Container Apps with the actual built image:

```bash
# Get ACR login server
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)

# Persist the variable
set_var "ACR_NAME" "$ACR_LOGIN_SERVER"

echo "ACR Name: $ACR_LOGIN_SERVER"


# Deploy Container Apps and APIM
az deployment group create \
  --name apps-deployment-$(date +%Y%m%d-%H%M%S) \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/apps.bicep \
  --parameters baseName=$BASE_NAME \
  --parameters containerImageRegistry=$ACR_LOGIN_SERVER \
  --parameters containerImageName='workshop-api:v1.0.0' \
  --parameters postgresAdminPassword='YourSecurePassword123'
```

**Deployment time: ~8-12 minutes** (Container Apps + APIM Consumption tier)

**Monitor Long-Running Deployment:**

If the deployment is taking longer than expected, use these commands to monitor progress:

```bash
# Get the current deployment name
CURRENT_DEPLOYMENT=$(az deployment group list --resource-group $RESOURCE_GROUP --query "[?starts_with(name, 'apps-deployment-')].name | [-1]" -o tsv)
echo "Monitoring deployment: $CURRENT_DEPLOYMENT"

# Check overall deployment status
az deployment group show \
  --name $CURRENT_DEPLOYMENT \
  --resource-group $RESOURCE_GROUP \
  --query "{State: properties.provisioningState, Duration: properties.duration, Timestamp: properties.timestamp}"

# See which resources are still deploying
az deployment operation group list \
  --name $CURRENT_DEPLOYMENT \
  --resource-group $RESOURCE_GROUP \
  --query "[?properties.provisioningState=='Running'].{Resource: properties.targetResource.resourceName, Type: properties.targetResource.resourceType, Status: properties.provisioningState}" \
  -o table

# Check for any failed operations
az deployment operation group list \
  --name $CURRENT_DEPLOYMENT \
  --resource-group $RESOURCE_GROUP \
  --query "[?properties.provisioningState=='Failed'].{Resource: properties.targetResource.resourceName, Error: properties.statusMessage.error.message}" \
  -o table

# Monitor Container Apps Environment creation (usually the longest step)
az containerapp env list \
  --resource-group $RESOURCE_GROUP \
  --query "[].{Name: name, ProvisioningState: properties.provisioningState, Location: location}" \
  -o table
```

**Expected timeline for Phase 3:**
- Container Apps Environment: ~8-10 minutes (usually the longest step)
- Container App: ~2-3 minutes  
- APIM API Configuration: ~1-2 minutes

---

## Step 6: Monitor Deployment and Update Progress

Check that the infrastructure deployed successfully and monitor the Container App update:

While deployment is running, you can monitor progress.

First, get your deployment name (it was generated with a timestamp in Step 6):

```bash
# List recent deployments to find your deployment name
az deployment group list \
  --resource-group $RESOURCE_GROUP \
  --query "[?starts_with(name, 'workshop-deployment-')].{Name: name, State: properties.provisioningState, Timestamp: properties.timestamp}" \
  -o table

# Save your deployment name to a variable (use the most recent one from the list above)
set_var "DEPLOYMENT_NAME" "workshop-deployment-20251106-123456"  # Replace with your actual deployment name

# Check overall status
az deployment group show \
  --name $DEPLOYMENT_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "{State: properties.provisioningState, Duration: properties.duration}"

# Check which resources are deploying
az deployment operation group list \
  --name $DEPLOYMENT_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "[?properties.provisioningState=='Running'].{Resource: properties.targetResource.resourceName, Type: properties.targetResource.resourceType}" \
  -o table
```

**Expected deployment time:**
- Virtual Network: ~1 minute
- Log Analytics & App Insights: ~1 minute
- API Management (Consumption): ~10-11 minutes
- Container Apps Environment: ~8-10 minutes
- PostgreSQL Flexible Server: ~5-8 minutes
- Container App: ~2-3 minutes

---

## Step 7: Verify Deployment

Once deployment completes, verify all resources were created successfully:

```bash
# Check deployment status
az deployment group show \
  --name $DEPLOYMENT_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "properties.provisioningState"

# List all resources in the resource group
az resource list \
  --resource-group $RESOURCE_GROUP \
  --output table

# Verify APIM API and operations were created
APIM_NAME=$(az apim list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)

az apim api list \
  --resource-group $RESOURCE_GROUP \
  --service-name $APIM_NAME \
  --output table
```

**Expected output:** You should see 1 API named "workshop-api"

---

## Step 8: Get Container App URL and Test API

```bash
# Get Container App URL from apps deployment
API_URL=$(az deployment group show \
  --resource-group $RESOURCE_GROUP \
  --name $(az deployment group list --resource-group $RESOURCE_GROUP --query "[?starts_with(name, 'apps-deployment-')].name | [-1]" -o tsv) \
  --query "properties.outputs.apiContainerAppUrl.value" -o tsv)

echo "API URL: $API_URL"
set_var "API_URL" "$API_URL"

# Verify all required variables are set and persisted
echo ""
verify_vars
```

> **Note:** We're now connecting directly to the Container App, not through APIM. This simplifies the setup and eliminates the need for subscription keys.

---

## Step 9: Test the API

### 9.1: Test Health Endpoint

```bash
curl -s "$API_URL/health" | jq .
```

**Expected output:**
```json
{
  "status": "healthy",
  "timestamp": "2025-11-06T12:34:56.789"
}
```

### 9.2: Test Root Endpoint

```bash
curl -s "$API_URL/" | jq .
```

**Expected output:**
```json
{
  "message": "Welcome to Workshop API",
  "version": "1.0.0",
  "endpoints": {
    "health": "/health",
    "items": "/items",
    "docs": "/docs"
  }
}
```

### 9.3: Test CRUD Operations

#### Create an Item
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Item",
    "description": "My first item",
    "price": 29.99,
    "quantity": 5
  }' \
  "$API_URL/items" | jq .
```

**Expected output:**
```json
{
  "name": "Test Item",
  "description": "My first item",
  "price": 29.99,
  "quantity": 5,
  "id": 1,
  "created_at": "2025-11-06T12:34:56.789",
  "updated_at": "2025-11-06T12:34:56.789"
}
```

#### List All Items
```bash
curl -s "$API_URL/items" | jq .
```

#### Get Specific Item
```bash
curl -s "$API_URL/items/1" | jq .
```

#### Update an Item
```bash
curl -X PUT \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Item",
    "description": "Updated description",
    "price": 39.99,
    "quantity": 10
  }' \
  "$API_URL/items/1" | jq .
```

#### Delete an Item
```bash
curl -X DELETE "$API_URL/items/1"
```

---

## Step 10: Explore the Azure Portal

1. Navigate to the Azure Portal: https://portal.azure.com
2. Open your resource group: `$RESOURCE_GROUP`
3. Explore the deployed resources:

### Container App
- Open the Container App instance
- Check **Metrics** for request counts and response times
- View **Log stream** for real-time logs
- Check **Revisions** to see deployment history

### Application Insights
- Open Application Insights instance
- Navigate to **Application Map** to see service dependencies
- Check **Live Metrics** for real-time monitoring
- Explore **Logs** for query-based analysis

### PostgreSQL Database
- Open PostgreSQL Flexible Server
- Check **Networking** settings (private endpoint)
- View **Monitoring** metrics

---

## Step 11: Verify Integration

### Check Application Insights Integration

```bash
APP_INSIGHTS_ID=$(az resource show \
  --ids $(az resource list \
    --resource-group $RESOURCE_GROUP \
    --resource-type "microsoft.insights/components" \
    --query "[0].id" -o tsv) \
  --query "properties.AppId" -o tsv)

# Query recent requests
az monitor app-insights query \
  --app $APP_INSIGHTS_ID \
  --analytics-query "requests | where timestamp > ago(10m) | order by timestamp desc | take 10" \
  --output table
```

### Check Container App Logs

```bash
az containerapp logs show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --follow
```

Press `Ctrl+C` to stop following logs.

---

## Troubleshooting Common Issues

### Issue 1: "ResourceNotFound" Errors During Apps Deployment

**Symptom:** Phase 3 (apps deployment) fails with errors like:
```
The Resource 'Microsoft.ContainerRegistry/registries/xyz' under resource group 'xyz' was not found
```

**Root Cause:** You skipped Phase 1 (infrastructure deployment) or it failed.

**Solution:** 
1. First, check if Phase 1 was completed:
   ```bash
   # Check if infrastructure resources exist
   az resource list --resource-group $RESOURCE_GROUP -o table
   ```
2. If no resources exist, run Phase 1:
   ```bash
   az deployment group create \
     --name infrastructure-deployment-$(date +%Y%m%d-%H%M%S) \
     --resource-group $RESOURCE_GROUP \
     --template-file infra/infrastructure.bicep \
     --parameters baseName=$BASE_NAME \
     --parameters postgresAdminPassword='YourSecurePassword123'
   ```
3. Wait for Phase 1 to complete, then proceed with Phase 2 and 3.

### Issue 2: Long Deployment Times (Phase 3)

**Symptom:** Container Apps deployment is taking longer than 15 minutes

**Diagnosis:** Use the monitoring commands from Phase 3 to identify bottlenecks:

```bash
# Get current deployment name and monitor progress
CURRENT_DEPLOYMENT=$(az deployment group list --resource-group $RESOURCE_GROUP --query "[?starts_with(name, 'apps-deployment-')].name | [-1]" -o tsv)

# Check which step is taking longest
az deployment operation group list \
  --name $CURRENT_DEPLOYMENT \
  --resource-group $RESOURCE_GROUP \
  --query "[].{Resource: properties.targetResource.resourceName, Type: properties.targetResource.resourceType, Status: properties.provisioningState, Duration: properties.duration}" \
  -o table
```

**Common causes and solutions:**

1. **Container Apps Environment taking >15 minutes:**
   - This is usually normal in busy regions
   - If >20 minutes, consider canceling and retrying in a different region
   
2. **Container App stuck on "Running" status:**
   - Check if the container image exists and can be pulled:
   ```bash
   # Verify image exists in ACR
   az acr repository show-tags --name $ACR_NAME --repository workshop-api
   
   # Check Container App status
   az containerapp show --name ${BASE_NAME}-dev-api --resource-group $RESOURCE_GROUP --query "properties.provisioningState"
   ```

3. **Network-related delays:**
   - VNet integration can be slow in some regions
   - Check if subnets have enough available IPs

**If deployment exceeds 25 minutes:**
```bash
# Cancel the deployment
az deployment group cancel --name $CURRENT_DEPLOYMENT --resource-group $RESOURCE_GROUP

# Try deploying in a different region or retry later
```

### Issue 3: Deployment Fails at APIM

**Symptom:** Deployment fails with "Unable to activate API service"

**Solution:** This is a temporary regional issue. Wait a few minutes and retry the deployment.

### Issue 4: Container App Can't Pull from ACR

**Symptom:** Container app shows "ImagePullBackOff" error

**Solution:**
1. Verify ACR credentials or managed identity permissions:
   ```bash
   az role assignment list \
     --assignee $IDENTITY_PRINCIPAL_ID \
     --scope $(az acr show --name $ACR_NAME --query id -o tsv)
   ```
2. If missing, re-run the grant command from Step 4.4

### Issue 5: API Returns 500 Error

**Symptom:** API calls return 500 Internal Server Error

**Solution:** Check database connection:
```bash
# Check container app logs
az containerapp logs show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --tail 50
```

### Issue 6: APIM Gateway Returns 401 Unauthorized

**Symptom:** API calls return 401 Unauthorized

**Solution:** Verify you're using the correct subscription key in the header:
```bash
echo "Subscription Key: $SUBSCRIPTION_KEY"
```

### Issue 7: No APIs in APIM

**Symptom:** APIM is deployed but no APIs are visible

**Solution:** This happens when Container App deployment fails. Check:
```bash
az deployment operation group list \
  --name $DEPLOYMENT_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "[?properties.provisioningState=='Failed']"
```

The API depends on the Container App FQDN. If Container App failed, the API won't be created.

---

## Cleanup (Optional)

If you want to start over or remove all resources:

```bash
# Delete the resource group (removes all resources)
az group delete --name $RESOURCE_GROUP --yes --no-wait

# If you created ACR in a different resource group
az acr delete --name $ACR_NAME --yes
```

---

## Architecture Verification Checklist

Before moving to Part 2, verify:

- [ ] Container App is deployed and running
- [ ] Health check endpoint returns 200 OK
- [ ] At least one CRUD operation works (create or list items)
- [ ] Application Insights shows recent requests
- [ ] Container App is healthy in the Azure portal
- [ ] PostgreSQL database is accessible from Container App
- [ ] API URL is saved and accessible

---

## What's Next?

Now that your infrastructure is deployed and tested, you're ready for:

**[Part 2: SRE Agent Troubleshooting](./part2-troubleshooting.md)** - Learn how to diagnose and fix common issues using Azure SRE Agent.

---

## Quick Reference

### Environment Variables

**Recommended:** Variables are automatically saved when using the workshop helper script.
```bash
# All variables persist automatically with:
source scripts/workshop-env.sh
```

**Alternative:** If using traditional environment variables, save these for later exercises:
```bash
export BASE_NAME="sre<your-initials>"
export RESOURCE_GROUP="${BASE_NAME}-workshop"
export APIM_URL="<your-apim-gateway-url>"
export SUBSCRIPTION_KEY="<your-subscription-key>"
export ACR_NAME="<your-acr-name>"
```

### Useful Commands

```bash
# Check deployment status
az deployment group show --name $DEPLOYMENT_NAME --resource-group $RESOURCE_GROUP

# List all resources
az resource list --resource-group $RESOURCE_GROUP -o table

# View container app logs
az containerapp logs show --name ${BASE_NAME}-dev-api --resource-group $RESOURCE_GROUP

# Restart container app
az containerapp restart --name ${BASE_NAME}-dev-api --resource-group $RESOURCE_GROUP

# Query Application Insights
az monitor app-insights query --app $APP_INSIGHTS_NAME --analytics-query "requests | summarize count() by bin(timestamp, 5m)"
```

---

## Resources

- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [API Management Documentation](https://docs.microsoft.com/en-us/azure/api-management/)
- [Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)
- [PostgreSQL Flexible Server Documentation](https://docs.microsoft.com/en-us/azure/postgresql/flexible-server/)
- [Application Insights Documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)

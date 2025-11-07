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

## Step 5: Create Azure Container Registry

Create an Azure Container Registry to store the workshop API container image:

```bash
# Generate a unique ACR name and persist it
set_var "ACR_NAME" "${BASE_NAME}acr$RANDOM"

az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic
```

> **Alternative: Traditional Environment Variables**
> ```bash
> export ACR_NAME="${BASE_NAME}acr$RANDOM"
> ```

> **Note:** This ACR will use managed identity authentication. Admin credentials are not needed since the Container App will authenticate using its managed identity (configured in Step 8).

---

## Step 5: Build and Push API Image

Build the FastAPI application container image using Azure Container Registry build tasks:

```bash
# Build and push the image using ACR build tasks
az acr build \
  --registry $ACR_NAME \
  --image workshop-api:v1.0.0 \
  --file src/api/Dockerfile \
  src/api
```

> **Note:** ACR build tasks build the container image in the cloud, so you don't need Docker installed locally. The build process typically takes 1-2 minutes. You can watch the build logs in real-time as ACR builds and pushes the image.

---

## Step 6: Deploy Infrastructure

Deploy the complete workshop infrastructure:

```bash
az deployment group create \
  --name workshop-deployment-$(date +%Y%m%d-%H%M%S) \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/main.bicep \
  --parameters baseName=$BASE_NAME \
  --parameters containerImage=$ACR_NAME.azurecr.io/workshop-api:v1.0.0 \
  --parameters acrName=$ACR_NAME \
  --parameters postgresAdminPassword='YourSecurePassword123'
```

⏱️ **Deployment time: ~10-12 minutes** (APIM is the slowest resource)

> **Note:** The deployment automatically grants the Container App's managed identity permission to pull images from ACR. No manual role assignment needed!

---

## Step 7: Monitor Deployment Progress

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
- API Management (Consumption): ~10-11 minutes ⏰
- Container Apps Environment: ~8-10 minutes
- PostgreSQL Flexible Server: ~5-8 minutes
- Container App: ~2-3 minutes

---

## Step 8: Verify Deployment

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

## Step 9: Get APIM Gateway URL and Subscription Key

```bash
# Get APIM gateway URL and save it
APIM_URL=$(az apim show \
  --resource-group $RESOURCE_GROUP \
  --name $APIM_NAME \
  --query "gatewayUrl" -o tsv)

echo "APIM Gateway URL: $APIM_URL"
set_var "APIM_URL" "$APIM_URL"

# Get subscription key and save it  
SUBSCRIPTION_KEY=$(az rest \
  --method post \
  --url "$(az apim show --resource-group $RESOURCE_GROUP --name $APIM_NAME --query id -o tsv)/subscriptions/master/listSecrets?api-version=2023-05-01-preview" \
  --query "primaryKey" -o tsv)

echo "Subscription Key: $SUBSCRIPTION_KEY"
set_var "SUBSCRIPTION_KEY" "$SUBSCRIPTION_KEY"

# Save deployment name as well
set_var "DEPLOYMENT_NAME" "$DEPLOYMENT_NAME"

# Verify all required variables are set and persisted
echo ""
verify_vars
```

> **Alternative: Traditional Environment Variables**
> 
> If you're using traditional environment variables instead of the workshop helper:
> ```bash
> export APIM_URL="<your-apim-gateway-url>"
> export SUBSCRIPTION_KEY="<your-subscription-key>"
> export DEPLOYMENT_NAME="<your-deployment-name>"
> ```

---

## Step 10: Test the API

### 10.1: Test Health Endpoint

```bash
curl -s -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/api/health" | jq .
```

**Expected output:**
```json
{
  "status": "healthy",
  "timestamp": "2025-11-06T12:34:56.789"
}
```

### 10.2: Test Root Endpoint

```bash
curl -s -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/api/" | jq .
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

### 10.3: Test CRUD Operations

#### Create an Item
```bash
curl -X POST \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Item",
    "description": "My first item",
    "price": 29.99,
    "quantity": 5
  }' \
  "$APIM_URL/api/items" | jq .
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
curl -s -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/api/items" | jq .
```

#### Get Specific Item
```bash
curl -s -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/api/items/1" | jq .
```

#### Update an Item
```bash
curl -X PUT \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Updated Item",
    "description": "Updated description",
    "price": 39.99,
    "quantity": 10
  }' \
  "$APIM_URL/api/items/1" | jq .
```

#### Delete an Item
```bash
curl -X DELETE \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/api/items/1"
```

---

## Step 12: Explore the Azure Portal

1. Navigate to the Azure Portal: https://portal.azure.com
2. Open your resource group: `$RESOURCE_GROUP`
3. Explore the deployed resources:

### API Management
- Open APIM instance
- Navigate to **APIs** → **workshop-api**
- View the 7 operations: health-check, get-root, list-items, create-item, get-item, update-item, delete-item
- Test operations using the built-in test console

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

## Step 13: Verify Integration

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

### Issue 1: Deployment Fails at APIM

**Symptom:** Deployment fails with "Unable to activate API service"

**Solution:** This is a temporary regional issue. Wait a few minutes and retry the deployment.

### Issue 2: Container App Can't Pull from ACR

**Symptom:** Container app shows "ImagePullBackOff" error

**Solution:**
1. Verify ACR credentials or managed identity permissions:
   ```bash
   az role assignment list \
     --assignee $IDENTITY_PRINCIPAL_ID \
     --scope $(az acr show --name $ACR_NAME --query id -o tsv)
   ```
2. If missing, re-run the grant command from Step 4.4

### Issue 3: API Returns 500 Error

**Symptom:** API calls return 500 Internal Server Error

**Solution:** Check database connection:
```bash
# Check container app logs
az containerapp logs show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --tail 50
```

### Issue 4: APIM Gateway Returns 401 Unauthorized

**Symptom:** API calls return 401 Unauthorized

**Solution:** Verify you're using the correct subscription key in the header:
```bash
echo "Subscription Key: $SUBSCRIPTION_KEY"
```

### Issue 5: No APIs in APIM

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

- [ ] All 7 APIM operations are visible in the portal
- [ ] Health check endpoint returns 200 OK
- [ ] At least one CRUD operation works (create or list items)
- [ ] Application Insights shows recent requests
- [ ] Container App is running and healthy
- [ ] PostgreSQL database is accessible from Container App
- [ ] APIM gateway URL and subscription key are saved

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

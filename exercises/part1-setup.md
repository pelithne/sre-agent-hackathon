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
4. **Docker** installed (optional, for building custom images)
5. **jq** installed for JSON parsing (optional, for testing)

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

## Step 3: Create Resource Group

Choose a unique name for your resource group and create it in your preferred region:

```bash
# Set variables
RESOURCE_GROUP="sre-workshop-<your-initials>"
LOCATION="swedencentral"  # Or your preferred region
BASE_NAME="sre<your-initials>"  # Must be 3-15 characters, lowercase

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```

**Example:**
```bash
RESOURCE_GROUP="sre-workshop-pk"
BASE_NAME="srepk"
```

---

## Step 4: Deploy Infrastructure

You have two deployment options:

### Option A: Deploy with Placeholder Image (Faster)

This deploys with a simple hello-world container that doesn't require ACR:

```bash
az deployment group create \
  --name workshop-deployment-$(date +%Y%m%d-%H%M%S) \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/main.bicep \
  --parameters baseName=$BASE_NAME \
  --parameters postgresAdminPassword='YourSecurePassword123'
```

⏱️ **Deployment time: ~10-12 minutes** (APIM is the slowest resource)

### Option B: Deploy with Custom API (Full Workshop)

This deploys the complete FastAPI application with PostgreSQL integration:

#### 4.1: Create Azure Container Registry (if not exists)

```bash
ACR_NAME="${BASE_NAME}acr$RANDOM"

az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true
```

#### 4.2: Build and Push API Image

```bash
# Login to ACR
az acr login --name $ACR_NAME

# Build and push the image
cd src/api
docker build -t $ACR_NAME.azurecr.io/workshop-api:v1.0.0 .
docker push $ACR_NAME.azurecr.io/workshop-api:v1.0.0
cd ../..
```

Or use the provided script:
```bash
./scripts/build-and-push-api.sh $ACR_NAME v1.0.0
```

#### 4.3: Deploy with Custom Image

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

#### 4.4: Grant ACR Pull Permissions

After deployment completes, grant the managed identity permission to pull from ACR:

```bash
# Get managed identity principal ID
IDENTITY_PRINCIPAL_ID=$(az identity show \
  --name ${BASE_NAME}-dev-identity \
  --resource-group $RESOURCE_GROUP \
  --query principalId -o tsv)

# Grant AcrPull role
az role assignment create \
  --assignee $IDENTITY_PRINCIPAL_ID \
  --role AcrPull \
  --scope $(az acr show --name $ACR_NAME --query id -o tsv)

# Restart the container app to pick up the permissions
az containerapp restart \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP
```

---

## Step 5: Monitor Deployment Progress

While deployment is running, you can monitor progress:

```bash
DEPLOYMENT_NAME="workshop-deployment-20251106-123456"  # Use your actual deployment name

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

## Step 6: Verify Deployment

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

## Step 7: Get APIM Gateway URL and Subscription Key

```bash
# Get APIM gateway URL
APIM_URL=$(az apim show \
  --resource-group $RESOURCE_GROUP \
  --name $APIM_NAME \
  --query "gatewayUrl" -o tsv)

echo "APIM Gateway URL: $APIM_URL"

# Get subscription key
SUBSCRIPTION_KEY=$(az rest \
  --method post \
  --url "$(az apim show --resource-group $RESOURCE_GROUP --name $APIM_NAME --query id -o tsv)/subscriptions/master/listSecrets?api-version=2023-05-01-preview" \
  --query "primaryKey" -o tsv)

echo "Subscription Key: $SUBSCRIPTION_KEY"

# Save for later use
echo "export APIM_URL=$APIM_URL" >> ~/.workshop-env
echo "export SUBSCRIPTION_KEY=$SUBSCRIPTION_KEY" >> ~/.workshop-env
```

---

## Step 8: Test the API

### 8.1: Test Health Endpoint

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

### 8.2: Test Root Endpoint

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

### 8.3: Test CRUD Operations (Custom API only)

If you deployed with the custom API image:

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

## Step 9: Explore the Azure Portal

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

## Step 10: Verify Integration

### Check Application Insights Integration

```bash
APP_INSIGHTS_NAME=$(az monitor app-insights component list \
  --resource-group $RESOURCE_GROUP \
  --query "[0].name" -o tsv)

# Query recent requests
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
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
- [ ] At least one CRUD operation works (if using custom API)
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

Save these for use in later exercises:

```bash
export RESOURCE_GROUP="sre-workshop-<your-initials>"
export BASE_NAME="sre<your-initials>"
export APIM_URL="<your-apim-gateway-url>"
export SUBSCRIPTION_KEY="<your-subscription-key>"
export ACR_NAME="<your-acr-name>"  # If using custom API
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

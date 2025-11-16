# Part 1: Setup and Deployment

## Overview

In this exercise, you'll deploy the complete workshop infrastructure to Azure, including:
- API Management (Consumption tier)
- Container Apps with a FastAPI application
- PostgreSQL Flexible Server
- Application Insights for monitoring
- Virtual Network with proper segmentation

**Estimated Time:** 60 minutes

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

Load the workshop environment helper that will automatically persist variables across shell sessions. This can be really helpful in environments like **Azure Cloud Shell** where sessions time out, and you may loose environment variables.

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
# Set and persist variables using the workshop helper. 
set_var "BASE_NAME" "sre<your-initials>"  # Must be 3-15 characters, lowercase
set_var "LOCATION" "swedencentral"        # Or your preferred region
set_var "RESOURCE_GROUP" "${BASE_NAME}-workshop"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION
```


> **Alternative: Traditional Environment Variables**
> 
> If you prefer to work with traditional environment variables instead of the workshop helper:
> ```bash
> export BASE_NAME="srepkpl"
> export LOCATION="swedencentral"
> export RESOURCE_GROUP="${BASE_NAME}-workshop"
> ```
> 
> **Note:** With traditional variables, you'll need to manually re-set them if your shell session times out.

> **Note:** The `BASE_NAME` will be used to generate names for all Azure resources (ACR, Container App, APIM, etc.) to ensure they are unique and consistently named. The `set_var` function automatically persists variables to `~/.workshop-env` so they survive shell timeouts och changing from one shell to another.

---

## Step 5: Two-Phase Deployment 

> **Important**: You MUST complete Phase 1 before attempting Phase 2. The phases have dependencies and cannot be skipped.

### Phase 1: Infrastructure Deployment

First, deploy the core infrastructure. This deployment is using infrastructure as code with a bicep template located in ````infra/infrastructure.bicep````

```bash
az deployment group create \
  --name infrastructure-deployment-$(date +%Y%m%d-%H%M%S) \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/infrastructure.bicep \
  --parameters baseName=$BASE_NAME \
  --parameters postgresAdminPassword='YourSecurePassword123'
```

**Deployment time: ~10-15 minutes** 

> **What this deploys:**
> - Azure Container Registry (ACR) with managed identity integration
> - Virtual Network with proper segmentation
> - Log Analytics and Application Insights for monitoring
> - PostgreSQL Flexible Server with private networking
> - API Management service
> - Managed Identity with ACR access permissions


### Phase 2: Build Container Image and deploy Container App.

Once infrastructure deployment completes, build your container image:

```bash
# Get ACR name directly from the resource group
ACR_NAME=$(az acr list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)

# Save ACR name for later use. Make sure that the echo command outputs the name of the registry
set_var "ACR_NAME" "$ACR_NAME"
echo "ACR Name: $ACR_NAME"

# Build and push the image using ACR build tasks
az acr build \
  --registry $ACR_NAME \
  --image workshop-api:v1.0.0 \
  --file src/api/Dockerfile \
  src/api
```



Now deploy the Container Apps with the built image. This deployment is using the bicep template ````apps.bicep````

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

**Deployment time: ~10-15 minutes** (Container Apps + APIM Consumption tier)

---

## Step 7: Verify Deployment

Once deployment completes, verify all resources were created successfully:

```bash
# List all resources in the resource group
az resource list \
  --resource-group $RESOURCE_GROUP \
  --output table

```

## Step 8: Get APIM Gateway URL and Subscription Key

```bash
# Get APIM name
APIM_NAME=$(az apim list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)

# Get APIM gateway URL
APIM_GATEWAY_URL=$(az apim show \
  --name $APIM_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "gatewayUrl" -o tsv)

# Construct the API URL (APIM gateway + API path)
API_URL="${APIM_GATEWAY_URL}/api"

echo "APIM Gateway URL: $APIM_GATEWAY_URL"
echo "API URL: $API_URL"
set_var "APIM_GATEWAY_URL" "$APIM_GATEWAY_URL"
set_var "API_URL" "$API_URL"

# Get subscription key for APIM
SUBSCRIPTION_KEY=$(az rest \
  --method post \
  --url "https://management.azure.com/subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ApiManagement/service/$APIM_NAME/subscriptions/master/listSecrets?api-version=2021-08-01" \
  --query "primaryKey" -o tsv)

echo "Subscription Key: $SUBSCRIPTION_KEY"
set_var "SUBSCRIPTION_KEY" "$SUBSCRIPTION_KEY"

# Verify all required variables are set and persisted
echo ""
verify_vars
```

> **Note:** We're testing through APIM which provides API gateway features like rate limiting, authentication, and monitoring. All requests require the `Ocp-Apim-Subscription-Key` header.

---

## Step 9: Test the API Through APIM

### 9.1: Test Health Endpoint

```bash
curl -s -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" "$API_URL/health" | jq .
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
curl -s -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" "$API_URL/" | jq .
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
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
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
curl -s -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" "$API_URL/items" | jq .
```

#### Get Specific Item
```bash
curl -s -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" "$API_URL/items/1" | jq .
```

#### Update an Item
```bash
curl -X PUT \
  -H "Content-Type: application/json" \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
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
curl -X DELETE -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" "$API_URL/items/1"
```

---

## Step 10: Explore the Azure Portal

1. Navigate to the Azure Portal: https://portal.azure.com
2. Open your resource group: `$RESOURCE_GROUP`
3. Explore the deployed resources:

### Container App
1. In your resource group, find and click on the Container App resource (name: `${BASE_NAME}-dev-api`)
2. **View Metrics**:
   - In the left menu, scroll down to **Monitoring** section
   - Click on **Metrics**
   - Click **+ Add metric**
   - Select metrics like "Requests", "CPU Usage", "Memory Working Set Bytes"
   - Observe request counts and response times
3. **View Log Stream**:
   - In the left menu under **Monitoring**, click **Log stream**
   - Wait a few seconds for logs to appear
   - You should see real-time application logs from your FastAPI service
   - Make an API request (using curl) and watch the logs appear in real-time
4. **Check Revisions**:
   - In the left menu under **Application**, click **Revisions and replicas**
   - You'll see your current revision and deployment history
   - Each deployment creates a new revision for rollback capability

### Application Insights
1. In your resource group, find and click on the Application Insights resource (name: `${BASE_NAME}-insights`)
2. **Live Metrics**:
   - In the left menu under **Investigate**, click **Live Metrics**
   - Make some API requests using curl
   - Watch real-time telemetry: incoming requests, outgoing requests, overall health
3. **Logs (KQL Queries)**:
   - In the left menu under **Monitoring**, click **Logs**
   - Close the "Queries" dialog if it appears
   - Try querying recent requests or traces

### PostgreSQL Database
1. In your resource group, find and click on the PostgreSQL Flexible Server (name: `${BASE_NAME}-db`)
2. **Networking Settings**:
   - In the left menu under **Settings**, click **Networking**
   - Verify that public access is disabled (more secure)
   - Check the virtual network integration for private connectivity
3. **Monitoring Metrics**:
   - In the left menu under **Monitoring**, click **Metrics**
   - View database performance metrics like CPU, memory, connections, and storage

---

## Step 11: Verify Integration

### Check Application Insights Integration

```bash
# Get Application Insights name
APP_INSIGHTS_NAME=$(az resource list \
  --resource-group $RESOURCE_GROUP \
  --resource-type "microsoft.insights/components" \
  --query "[0].name" -o tsv)

# Get Application Insights App ID
APP_INSIGHTS_ID=$(az monitor app-insights component show \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --query "appId" -o tsv)

echo "Application Insights App ID: $APP_INSIGHTS_ID"

# Query recent requests (allow more time for telemetry ingestion)
az monitor app-insights query \
  --app $APP_INSIGHTS_ID \
  --analytics-query "requests | where timestamp > ago(1h) | order by timestamp desc | take 10" \
  --output table
```

> **Note**: If the query returns empty results:
> 1. Make sure you've made some API requests in Step 9
> 2. Wait 2-3 minutes for telemetry to be ingested
> 3. Telemetry ingestion can have delays; try the query in the Azure Portal (Application Insights → Logs) instead

### Check Container App Logs

```bash
az containerapp logs show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --follow
```

Press `Ctrl+C` to stop following logs.

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
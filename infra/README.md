# Infrastructure - Bicep Templates

This directory contains the Bicep Infrastructure as Code (IaC) templates for the Azure SRE Agent Hackathon workshop.

## Overview

The infrastructure deploys a complete cloud-native application stack on Azure with the following components:

### Core Services
- **Azure API Management** (Consumption tier) - API gateway and management
- **Azure Container Apps** - Serverless container hosting
- **Azure Database for PostgreSQL** (Flexible Server) - Managed database
- **Azure Virtual Network** - Network isolation and security
- **Azure Monitor & Application Insights** - Observability and monitoring
- **Azure Log Analytics** - Centralized logging
- **Managed Identity** - Secure service-to-service authentication

### Network Architecture
- Virtual Network with three subnets:
  - Container Apps subnet (10.0.0.0/23)
  - PostgreSQL subnet (10.0.2.0/24) - with delegation
  - API Management subnet (10.0.3.0/24)
- Private DNS zone for PostgreSQL private endpoint
- Network integration for Container Apps

## Files

- **main.bicep** - Main infrastructure template
- **main.bicepparam** - Parameters file with default values
- **../scripts/deploy-infrastructure.sh** - Deployment automation script

## Prerequisites

Before deploying, ensure you have:

1. **Azure CLI** (version 2.50.0 or later)
   ```bash
   az --version
   ```

2. **Azure subscription** with contributor access
   ```bash
   az login
   az account show
   ```

3. **Bicep CLI** (optional, Azure CLI includes it)
   ```bash
   az bicep version
   ```

## Deployment

### Option 1: Using the Deployment Script (Recommended)

The easiest way to deploy the infrastructure:

```bash
# From the repository root
cd scripts
./deploy-infrastructure.sh
```

You'll be prompted for:
- PostgreSQL admin password (min 12 characters with uppercase, lowercase, and numbers)

The script will:
- Validate prerequisites
- Create the resource group
- Deploy all infrastructure
- Save outputs to `.deployment-outputs.env`

### Option 2: Manual Deployment with Azure CLI

If you prefer manual control:

```bash
# Set variables
RESOURCE_GROUP="sre-agent-workshop-rg"
LOCATION="eastus"
POSTGRES_PASSWORD="YourSecurePassword123!"

# Create resource group
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# Deploy infrastructure
az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam \
  --parameters postgresAdminPassword="$POSTGRES_PASSWORD"
```

### Option 3: Using Bicep CLI Directly

```bash
# Validate template
az bicep build --file infra/main.bicep

# What-if analysis (preview changes)
az deployment group what-if \
  --resource-group sre-agent-workshop-rg \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam \
  --parameters postgresAdminPassword="YourPassword123!"

# Deploy
az deployment group create \
  --resource-group sre-agent-workshop-rg \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam \
  --parameters postgresAdminPassword="YourPassword123!"
```

## Parameters

### Required Parameters
- **postgresAdminPassword** - Password for PostgreSQL admin user
  - Minimum 12 characters
  - Must contain uppercase, lowercase, and numbers
  - **Important**: Use a strong password and store it securely (e.g., Azure Key Vault)

### Optional Parameters (with defaults)
- **location** - Azure region (default: resource group location)
- **environmentName** - Environment identifier (default: 'dev')
- **baseName** - Base name for resources (default: 'sreagent')
- **postgresAdminUsername** - PostgreSQL admin username (default: 'workshopadmin')
- **tags** - Resource tags (default: see main.bicepparam)

## Deployment Time

Expected deployment time: **10-15 minutes**

The longest operations are:
- PostgreSQL Flexible Server provisioning (~10 minutes)
- Container Apps environment setup (~3-5 minutes)
- API Management Consumption tier (~1-2 minutes)

## Outputs

After successful deployment, the following outputs are available:

```bash
# View outputs
az deployment group show \
  --name <deployment-name> \
  --resource-group sre-agent-workshop-rg \
  --query properties.outputs
```

Key outputs:
- `apimGatewayUrl` - API Management gateway URL
- `containerAppFqdn` - Container App fully qualified domain name
- `postgresServerFqdn` - PostgreSQL server hostname
- `appInsightsName` - Application Insights instance name
- `appInsightsConnectionString` - App Insights connection string (sensitive)
- `managedIdentityClientId` - Managed identity client ID

## Resource Naming Convention

Resources follow this naming pattern:
```
{baseName}-{environmentName}-{resourceType}-{uniqueSuffix}
```

Example:
- Resource Group: `sre-agent-workshop-rg`
- API Management: `sreagent-dev-apim-abc123xyz`
- Container App: `sreagent-dev-api`
- PostgreSQL: `sreagent-dev-psql-abc123xyz`

## Cost Estimation

Approximate monthly costs (East US region):
- API Management (Consumption): ~$0-5/month (pay-per-use: $0.035/10K calls + $0.06/GB)
- Container Apps: ~$15-30/month (depends on usage)
- PostgreSQL (Burstable B1ms): ~$15-20/month
- Application Insights: ~$5-10/month (depends on data volume)
- Log Analytics: ~$5-10/month (depends on data volume)

**Total: ~$40-70/month**

For workshop purposes (a few hours), costs will be minimal (< $2).

**Note:** Consumption tier APIM is significantly more cost-effective for workshops and development scenarios.

## Security Considerations

### Implemented Security Features
1. **Managed Identity** - Container App uses managed identity (no passwords)
2. **Private Networking** - PostgreSQL uses VNet integration
3. **Secrets Management** - Connection strings stored as Container App secrets
4. **TLS/SSL** - PostgreSQL requires SSL connections
5. **Azure Monitor** - Comprehensive logging and monitoring

### Additional Recommendations for Production
1. **Azure Key Vault** - Store all secrets and credentials
2. **Azure Private Link** - Private endpoints for all services
3. **Network Security Groups** - Fine-grained network access control
4. **Azure AD Authentication** - Replace SQL authentication with Azure AD
5. **API Management Policies** - Rate limiting, IP filtering, JWT validation
6. **Azure Policy** - Enforce organizational standards
7. **Azure Defender** - Enable advanced threat protection

## Troubleshooting

### Common Issues

**Issue: Deployment fails with "Subnet is in use"**
```bash
# Solution: Delete the resource group and retry
az group delete --name sre-agent-workshop-rg --yes
```

**Issue: PostgreSQL deployment fails**
```bash
# Check if the subnet delegation is correct
az network vnet subnet show \
  --resource-group sre-agent-workshop-rg \
  --vnet-name sreagent-dev-vnet \
  --name postgres-subnet \
  --query delegations
```

**Issue: Container App deployment fails**
```bash
# Check Container Apps environment status
az containerapp env show \
  --name <env-name> \
  --resource-group sre-agent-workshop-rg \
  --query properties.provisioningState
```

**Issue: API Management takes too long**
```bash
# This is normal - APIM provisioning takes 8-15 minutes
# Check status:
az apim show \
  --name <apim-name> \
  --resource-group sre-agent-workshop-rg \
  --query provisioningState
```

### Validation

Verify deployment:

```bash
# List all resources
az resource list \
  --resource-group sre-agent-workshop-rg \
  --output table

# Check Container App status
az containerapp show \
  --name <app-name> \
  --resource-group sre-agent-workshop-rg \
  --query properties.runningStatus

# Test PostgreSQL connectivity
psql "host=<postgres-fqdn> port=5432 dbname=workshopdb user=workshopadmin sslmode=require"
```

## Cleanup

To remove all resources:

```bash
# Delete the resource group (this deletes everything)
az group delete \
  --name sre-agent-workshop-rg \
  --yes \
  --no-wait

# Or use the cleanup script
cd scripts
./cleanup.sh
```

## Customization

### Changing PostgreSQL SKU
Edit `infra/main.bicep`:
```bicep
sku: {
  name: 'Standard_D2s_v3'  // Change to desired SKU
  tier: 'GeneralPurpose'
}
```

### Enabling High Availability
Edit `infra/main.bicep`:
```bicep
highAvailability: {
  mode: 'ZoneRedundant'  // or 'SameZone'
  standbyAvailabilityZone: '2'
}
```

### Adding More Container Apps
Add additional container app resources or create a module for reusability.

## Next Steps

After infrastructure deployment:

1. ✅ Infrastructure deployed
2. ⏭️ Deploy the sample API application ([Module 3](../docs/03-application.md))
3. ⏭️ Configure API Management
4. ⏭️ Start troubleshooting exercises

## References

- [Azure Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/)
- [Azure API Management](https://learn.microsoft.com/azure/api-management/)
- [Azure Database for PostgreSQL](https://learn.microsoft.com/azure/postgresql/)
- [Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/)

---

**Questions or issues?** Check the [troubleshooting guide](../docs/troubleshooting.md) or create an issue.

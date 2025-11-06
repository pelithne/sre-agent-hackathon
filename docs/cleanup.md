# Cleanup Guide

## Overview

This guide helps you clean up Azure resources created during the workshop to avoid unnecessary charges.

⚠️ **Important:** Resource deletion is irreversible. Make sure you've saved any data or configurations you want to keep.

---

## Quick Cleanup (Recommended)

The fastest way to clean up is to delete the entire resource group:

```bash
# Set your resource group name
export RESOURCE_GROUP="your-resource-group-name"

# Delete everything (CAUTION: This is irreversible!)
az group delete \
  --name $RESOURCE_GROUP \
  --yes \
  --no-wait
```

This command:
- Deletes ALL resources in the resource group
- Runs asynchronously (`--no-wait`)
- Takes 5-10 minutes to complete
- No confirmation prompt (`--yes`)

### Verify Deletion

```bash
# Check deletion status
az group show --name $RESOURCE_GROUP

# If deleted, you'll see an error:
# ResourceGroupNotFound: Resource group 'your-rg' could not be found.
```

---

## Selective Cleanup

If you want to keep some resources and delete others:

### Delete Container Apps

```bash
# Delete Container App
az containerapp delete \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --yes

# Delete Container Apps Environment
az containerapp env delete \
  --name ${BASE_NAME}-dev-env \
  --resource-group $RESOURCE_GROUP \
  --yes
```

### Delete API Management

```bash
# Get APIM name
APIM_NAME=$(az apim list \
  --resource-group $RESOURCE_GROUP \
  --query "[0].name" -o tsv)

# Delete APIM (takes 5-10 minutes)
az apim delete \
  --name $APIM_NAME \
  --resource-group $RESOURCE_GROUP \
  --yes \
  --no-wait
```

### Delete PostgreSQL Database

```bash
# Get PostgreSQL server name
POSTGRES_NAME=$(az postgres flexible-server list \
  --resource-group $RESOURCE_GROUP \
  --query "[0].name" -o tsv)

# Delete PostgreSQL server
az postgres flexible-server delete \
  --resource-group $RESOURCE_GROUP \
  --name $POSTGRES_NAME \
  --yes
```

### Delete Virtual Network

```bash
# Delete VNet
az network vnet delete \
  --name ${BASE_NAME}-dev-vnet \
  --resource-group $RESOURCE_GROUP
```

### Delete Application Insights

```bash
# Get Application Insights name
APP_INSIGHTS_NAME=$(az monitor app-insights component list \
  --resource-group $RESOURCE_GROUP \
  --query "[0].name" -o tsv)

# Delete Application Insights
az monitor app-insights component delete \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP
```

### Delete Log Analytics Workspace

```bash
# Get workspace name
WORKSPACE_NAME=$(az monitor log-analytics workspace list \
  --resource-group $RESOURCE_GROUP \
  --query "[0].name" -o tsv)

# Delete workspace
az monitor log-analytics workspace delete \
  --workspace-name $WORKSPACE_NAME \
  --resource-group $RESOURCE_GROUP \
  --yes
```

### Delete Container Registry (if created)

```bash
# Only if you created ACR during workshop
az acr delete \
  --name $ACR_NAME \
  --resource-group $RESOURCE_GROUP \
  --yes
```

---

## Cleanup Automation Script

Save this script as `cleanup.sh`:

```bash
#!/bin/bash

# Cleanup script for SRE Workshop
# Usage: ./cleanup.sh <resource-group-name> [--full|--selective]

set -e

RESOURCE_GROUP=$1
MODE=${2:-"--full"}

if [ -z "$RESOURCE_GROUP" ]; then
  echo "Usage: ./cleanup.sh <resource-group-name> [--full|--selective]"
  exit 1
fi

echo "=========================================="
echo "SRE Workshop Cleanup Script"
echo "=========================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Mode: $MODE"
echo ""

# Check if resource group exists
if ! az group show --name $RESOURCE_GROUP &> /dev/null; then
  echo "❌ Resource group '$RESOURCE_GROUP' not found"
  exit 1
fi

if [ "$MODE" == "--full" ]; then
  echo "⚠️  WARNING: This will DELETE the entire resource group and ALL resources!"
  echo "This action is IRREVERSIBLE."
  echo ""
  read -p "Are you sure you want to continue? (type 'yes' to confirm): " CONFIRM
  
  if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
  fi
  
  echo ""
  echo "🗑️  Deleting resource group: $RESOURCE_GROUP"
  az group delete --name $RESOURCE_GROUP --yes --no-wait
  
  echo "✅ Deletion initiated. This will take 5-10 minutes."
  echo "   Check status with: az group show --name $RESOURCE_GROUP"
  
elif [ "$MODE" == "--selective" ]; then
  echo "🔍 Selective cleanup - choose what to delete:"
  echo ""
  
  # List resources
  echo "Resources in $RESOURCE_GROUP:"
  az resource list --resource-group $RESOURCE_GROUP --output table
  echo ""
  
  # Container Apps
  read -p "Delete Container Apps? (y/n): " DELETE_APPS
  if [ "$DELETE_APPS" == "y" ]; then
    echo "Deleting Container Apps..."
    for app in $(az containerapp list -g $RESOURCE_GROUP --query "[].name" -o tsv); do
      az containerapp delete --name $app --resource-group $RESOURCE_GROUP --yes
    done
    
    for env in $(az containerapp env list -g $RESOURCE_GROUP --query "[].name" -o tsv); do
      az containerapp env delete --name $env --resource-group $RESOURCE_GROUP --yes
    done
  fi
  
  # APIM
  read -p "Delete API Management? (y/n): " DELETE_APIM
  if [ "$DELETE_APIM" == "y" ]; then
    echo "Deleting APIM (this takes 5-10 minutes)..."
    for apim in $(az apim list -g $RESOURCE_GROUP --query "[].name" -o tsv); do
      az apim delete --name $apim --resource-group $RESOURCE_GROUP --yes --no-wait
    done
  fi
  
  # PostgreSQL
  read -p "Delete PostgreSQL Database? (y/n): " DELETE_DB
  if [ "$DELETE_DB" == "y" ]; then
    echo "Deleting PostgreSQL..."
    for db in $(az postgres flexible-server list -g $RESOURCE_GROUP --query "[].name" -o tsv); do
      az postgres flexible-server delete --name $db --resource-group $RESOURCE_GROUP --yes
    done
  fi
  
  # Application Insights
  read -p "Delete Application Insights? (y/n): " DELETE_APPINS
  if [ "$DELETE_APPINS" == "y" ]; then
    echo "Deleting Application Insights..."
    for ai in $(az monitor app-insights component list -g $RESOURCE_GROUP --query "[].name" -o tsv); do
      az monitor app-insights component delete --app $ai --resource-group $RESOURCE_GROUP
    done
  fi
  
  # VNet
  read -p "Delete Virtual Network? (y/n): " DELETE_VNET
  if [ "$DELETE_VNET" == "y" ]; then
    echo "Deleting VNet..."
    for vnet in $(az network vnet list -g $RESOURCE_GROUP --query "[].name" -o tsv); do
      az network vnet delete --name $vnet --resource-group $RESOURCE_GROUP
    done
  fi
  
  echo "✅ Selective cleanup completed"
  echo ""
  echo "Remaining resources:"
  az resource list --resource-group $RESOURCE_GROUP --output table
  
else
  echo "❌ Invalid mode. Use --full or --selective"
  exit 1
fi

echo ""
echo "=========================================="
echo "Cleanup Summary"
echo "=========================================="
echo "Start time: $(date)"
echo "Resource Group: $RESOURCE_GROUP"
echo "Mode: $MODE"
echo ""
echo "💡 Tip: Always verify deletion to avoid unexpected charges!"
echo "   Check Azure Portal or run: az group show --name $RESOURCE_GROUP"
echo "=========================================="
```

Make it executable:

```bash
chmod +x cleanup.sh
```

Usage:

```bash
# Full cleanup (deletes everything)
./cleanup.sh sre-agent-workshop-rg --full

# Selective cleanup (choose what to delete)
./cleanup.sh sre-agent-workshop-rg --selective
```

---

## Cleanup Checklist

Use this checklist to ensure complete cleanup:

### Before Deletion
- [ ] Export any data you want to keep
- [ ] Save Application Insights queries and dashboards
- [ ] Document learnings and RCA reports
- [ ] Take screenshots if needed for documentation
- [ ] Back up any custom code or configurations

### Resource Deletion
- [ ] Container Apps deleted
- [ ] Container Apps Environment deleted
- [ ] API Management deleted
- [ ] PostgreSQL Flexible Server deleted
- [ ] Virtual Network deleted
- [ ] Application Insights deleted
- [ ] Log Analytics Workspace deleted
- [ ] Container Registry deleted (if created)
- [ ] Managed Identities deleted (usually automatic)

### Verification
- [ ] Resource group is empty or deleted
- [ ] No resources showing in Azure Portal
- [ ] Verify with: `az resource list -g $RESOURCE_GROUP`
- [ ] Check Azure Cost Management for zero charges

### Post-Cleanup
- [ ] Wait 24-48 hours to see final charges
- [ ] Review Azure billing to ensure no ongoing costs
- [ ] Delete local environment variables
- [ ] Clean up local Docker images (if any)

---

## Cost Considerations

### What Gets Charged After Deletion?

Even after deleting resources, you may see charges for:

1. **Log Retention:** Application Insights and Log Analytics retain data based on retention policy (default 90 days)
2. **Backup Storage:** PostgreSQL backups retained for 7 days
3. **Soft-Deleted Resources:** Some services (Key Vault) have soft-delete period
4. **Network Egress:** Data transfer charges may appear later
5. **Storage Transactions:** Final cleanup operations

### How to Minimize Post-Deletion Costs

```bash
# Reduce Log Analytics retention before deletion
az monitor log-analytics workspace update \
  --workspace-name $WORKSPACE_NAME \
  --resource-group $RESOURCE_GROUP \
  --retention-time 30

# Reduce Application Insights retention
az monitor app-insights component update \
  --app $APP_INSIGHTS_NAME \
  --resource-group $RESOURCE_GROUP \
  --retention-time 30
```

### Expected Final Costs

After cleanup, expect minimal charges:
- **Day 0-1:** Pro-rated charges for resources deleted
- **Day 2-7:** Backup storage (~$0.10-0.50)
- **Day 8-30:** Log retention (~$0.50-2.00)
- **Day 30+:** Should be $0

---

## Troubleshooting Deletion

### "Cannot delete resource because it has child resources"

Delete child resources first:

```bash
# Example: Delete subnet before VNet
az network vnet subnet delete \
  --vnet-name ${BASE_NAME}-dev-vnet \
  --name default \
  --resource-group $RESOURCE_GROUP

# Then delete VNet
az network vnet delete \
  --name ${BASE_NAME}-dev-vnet \
  --resource-group $RESOURCE_GROUP
```

### "Resource is locked"

Remove lock before deletion:

```bash
# List locks
az lock list --resource-group $RESOURCE_GROUP

# Delete lock
az lock delete \
  --name <LOCK_NAME> \
  --resource-group $RESOURCE_GROUP
```

### "Deletion is taking too long"

APIM Consumption tier takes 5-10 minutes. Check status:

```bash
# Check deletion status
az group deployment operation list \
  --resource-group $RESOURCE_GROUP \
  --name <DEPLOYMENT_NAME>

# Or check in Portal: Resource Group > Deployments
```

### "Resource not found but still being charged"

Check for:

```bash
# Soft-deleted resources
az keyvault list-deleted

# Resources in other regions
az resource list --query "[?resourceGroup=='$RESOURCE_GROUP']" -o table

# Activity log for recent operations
az monitor activity-log list \
  --resource-group $RESOURCE_GROUP \
  --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%SZ)
```

---

## Alternative: Pause Instead of Delete

If you want to pause the workshop and resume later:

### Container Apps
```bash
# Scale to 0 replicas (minimal cost)
az containerapp update \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --min-replicas 0 \
  --max-replicas 0
```

### PostgreSQL
```bash
# Stop server (still charged for storage)
az postgres flexible-server stop \
  --name $POSTGRES_NAME \
  --resource-group $RESOURCE_GROUP
```

### APIM
- Consumption tier: Minimal cost when idle (pay-per-call)
- No "stop" option needed

### Cost While Paused

Approximate daily cost:
- Container Apps (0 replicas): ~$0.10/day (environment cost)
- PostgreSQL (stopped): ~$0.15/day (storage only)
- APIM (idle): ~$0.05/day (minimal usage)
- Application Insights: ~$0.10/day (minimal ingestion)

**Total: ~$0.40/day** while paused

---

## Cleanup Best Practices

✅ **Do This:**
- Delete resources immediately after workshop
- Use resource group deletion for complete cleanup
- Verify deletion in Azure Portal
- Monitor billing for 48 hours after deletion
- Document what you learned before deleting

❌ **Avoid This:**
- Leaving resources running indefinitely
- Deleting resource group without checking contents
- Forgetting about soft-deleted resources
- Ignoring post-deletion charges
- Deleting production resources accidentally

---

## Multiple Workshop Instances

If you ran the workshop multiple times:

```bash
# List all workshop resource groups
az group list --query "[?starts_with(name, 'sre-agent') || starts_with(name, 'sre-workshop')].name" -o table

# Delete all workshop resource groups
for rg in $(az group list --query "[?starts_with(name, 'sre-agent')].name" -o tsv); do
  echo "Deleting $rg..."
  az group delete --name $rg --yes --no-wait
done
```

---

## Getting Help

If you encounter issues during cleanup:

1. **Check Azure Activity Log:**
```bash
az monitor activity-log list \
  --resource-group $RESOURCE_GROUP \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --query "[?contains(operationName.value, 'delete')]" \
  --output table
```

2. **Ask SRE Agent:**
```
"I'm trying to delete resource group but getting error: [paste error]. How do I resolve this?"
```

3. **Azure Support:** For persistent issues, contact Azure support

---

## Final Reminder

🚨 **Always verify deletion to avoid unexpected charges!**

Check your Azure billing:
- **Portal:** Home > Cost Management + Billing > Cost Analysis
- **CLI:** `az consumption usage list`

**Questions?** See [FAQ.md](./FAQ.md) for common cleanup issues.

---

**Last Updated:** November 6, 2025

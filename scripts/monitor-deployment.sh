#!/bin/bash
# ============================================================================
# Monitor Deployment Progress
# ============================================================================

DEPLOYMENT_NAME="${1:-}"
RESOURCE_GROUP="${2:-sre-agent-test-rg}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

if [ -z "$DEPLOYMENT_NAME" ]; then
    echo "Finding latest deployment..."
    DEPLOYMENT_NAME=$(az deployment group list \
        --resource-group "$RESOURCE_GROUP" \
        --query "[0].name" -o tsv)
fi

if [ -z "$DEPLOYMENT_NAME" ]; then
    echo -e "${RED}No deployments found in resource group: $RESOURCE_GROUP${NC}"
    exit 1
fi

echo -e "${BLUE}Monitoring deployment: ${DEPLOYMENT_NAME}${NC}"
echo "Resource Group: $RESOURCE_GROUP"
echo ""

while true; do
    STATE=$(az deployment group show \
        --name "$DEPLOYMENT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query "properties.provisioningState" -o tsv 2>/dev/null)
    
    if [ -z "$STATE" ]; then
        echo -e "${RED}Deployment not found${NC}"
        exit 1
    fi
    
    TIMESTAMP=$(date +"%H:%M:%S")
    
    case "$STATE" in
        "Succeeded")
            echo -e "${GREEN}[$TIMESTAMP] ✓ Deployment completed successfully!${NC}"
            echo ""
            echo "Getting deployment outputs..."
            az deployment group show \
                --name "$DEPLOYMENT_NAME" \
                --resource-group "$RESOURCE_GROUP" \
                --query "properties.outputs" -o json | jq
            exit 0
            ;;
        "Failed")
            echo -e "${RED}[$TIMESTAMP] ✗ Deployment failed${NC}"
            echo ""
            echo "Error details:"
            az deployment group show \
                --name "$DEPLOYMENT_NAME" \
                --resource-group "$RESOURCE_GROUP" \
                --query "properties.error" -o json | jq
            exit 1
            ;;
        "Running")
            # Get deployment operations to show progress
            OPERATIONS=$(az deployment operation group list \
                --name "$DEPLOYMENT_NAME" \
                --resource-group "$RESOURCE_GROUP" \
                --query "length([?properties.provisioningState=='Succeeded'])" -o tsv)
            
            TOTAL=$(az deployment operation group list \
                --name "$DEPLOYMENT_NAME" \
                --resource-group "$RESOURCE_GROUP" \
                --query "length([])" -o tsv)
            
            echo -ne "${YELLOW}[$TIMESTAMP] Deployment in progress... ($OPERATIONS/$TOTAL resources deployed)\r${NC}"
            ;;
        *)
            echo -e "${YELLOW}[$TIMESTAMP] Status: $STATE${NC}"
            ;;
    esac
    
    sleep 10
done

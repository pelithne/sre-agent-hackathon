#!/bin/bash
# ============================================================================
# Test Deployment Script for Bicep Templates
# ============================================================================

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE} Azure SRE Agent Hackathon - Test Deployment${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""

# Configuration
TEST_RG="sre-agent-test-v2-rg"
LOCATION="swedencentral"
POSTGRES_PASSWORD="SecureTestPass123!"
DEPLOYMENT_NAME="test-deployment-$(date +%Y%m%d-%H%M%S)"

echo "Configuration:"
echo "  Resource Group: $TEST_RG"
echo "  Location: $LOCATION"
echo "  Deployment: $DEPLOYMENT_NAME"
echo ""

# Check if already logged in
if ! az account show &> /dev/null; then
    echo -e "${RED}Not logged in to Azure. Please run 'az login'${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Logged in to Azure${NC}"
SUBSCRIPTION=$(az account show --query name -o tsv)
echo "  Subscription: $SUBSCRIPTION"
echo ""

# Create or verify resource group
echo -e "${YELLOW}Creating resource group...${NC}"
az group create --name "$TEST_RG" --location "$LOCATION" --output none
echo -e "${GREEN}✓ Resource group ready${NC}"
echo ""

# Deploy infrastructure
echo -e "${YELLOW}Deploying infrastructure (this will take 15-20 minutes)...${NC}"
echo ""

START_TIME=$(date +%s)

# Deploy without parameters file to allow password override
az deployment group create \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$TEST_RG" \
  --template-file infra/main.bicep \
  --parameters postgresAdminPassword="$POSTGRES_PASSWORD" \
  --parameters environmentName=test \
  --parameters baseName=sretest \
  --verbose

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

echo ""
echo -e "${GREEN}============================================================================${NC}"
echo -e "${GREEN} Deployment Completed Successfully!${NC}"
echo -e "${GREEN}============================================================================${NC}"
echo ""
echo "Duration: ${MINUTES}m ${SECONDS}s"
echo ""

# Get outputs
echo -e "${BLUE}Deployment Outputs:${NC}"
echo ""

OUTPUTS=$(az deployment group show \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$TEST_RG" \
  --query properties.outputs \
  -o json)

echo "$OUTPUTS" | jq -r 'to_entries[] | "  \(.key): \(.value.value)"'

echo ""
echo -e "${YELLOW}To clean up:${NC}"
echo "  az group delete --name $TEST_RG --yes --no-wait"
echo ""
echo -e "${GREEN}✓ Test deployment complete!${NC}"

#!/bin/bash

# Helper script to get Azure APIM credentials for load testing
# This script retrieves the APIM URL and subscription key from Azure

set -e

RESOURCE_GROUP=${RESOURCE_GROUP:-"srepeter11-workshop"}

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}[INFO]${NC} Retrieving APIM credentials from Azure..."
echo ""

# Get APIM name
APIM_NAME=$(az apim list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null)

if [ -z "$APIM_NAME" ]; then
    echo -e "${YELLOW}[ERROR]${NC} No APIM found in resource group: $RESOURCE_GROUP"
    exit 1
fi

echo -e "${GREEN}[INFO]${NC} Found APIM: $APIM_NAME"

# Get APIM gateway URL
APIM_URL=$(az apim show --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" --query "gatewayUrl" -o tsv 2>/dev/null)
echo -e "${GREEN}[INFO]${NC} APIM URL: $APIM_URL"

# Get APIM resource ID
APIM_ID=$(az apim show --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv 2>/dev/null)

# Get APIM subscription key
APIM_KEY=$(az rest --method post \
  --url "${APIM_ID}/subscriptions/master/listSecrets?api-version=2023-05-01-preview" \
  --query primaryKey -o tsv 2>/dev/null)

echo -e "${GREEN}[INFO]${NC} Subscription key retrieved"
echo ""
echo "=================================================="
echo "Export these variables to use with load testing:"
echo "=================================================="
echo ""
echo "export APIM_URL=\"$APIM_URL\""
echo "export APIM_KEY=\"$APIM_KEY\""
echo ""
echo "Or run load test directly:"
echo ""
echo "APIM_URL=\"$APIM_URL\" APIM_KEY=\"$APIM_KEY\" ./load-test-apim.sh"
echo ""

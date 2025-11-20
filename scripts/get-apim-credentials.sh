#!/bin/bash

# Helper script to get Azure APIM credentials for load testing
# This script retrieves the APIM URL and subscription key from Azure

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if RESOURCE_GROUP is provided
if [ -n "$RESOURCE_GROUP" ]; then
    print_info "RESOURCE_GROUP environment variable set to: $RESOURCE_GROUP"
    
    # Verify the resource group exists
    if ! az group show --name "$RESOURCE_GROUP" &>/dev/null; then
        print_warn "Resource group '$RESOURCE_GROUP' does not exist or is not accessible"
        print_info "Ignoring RESOURCE_GROUP variable and searching for APIM instances..."
        unset RESOURCE_GROUP
    fi
fi

if [ -z "$RESOURCE_GROUP" ]; then
    print_info "Searching for APIM instances in subscription..."
    
    # Try to find any APIM in the subscription
    APIM_LIST=$(az apim list --query "[].{name:name, resourceGroup:resourceGroup}" -o json 2>/dev/null)
    
    if [ -z "$APIM_LIST" ] || [ "$APIM_LIST" = "[]" ]; then
        print_error "No APIM instances found in the current subscription"
        print_info "Please ensure you have APIM deployed and are logged into the correct Azure subscription"
        print_info "Available resource groups:"
        az group list --query "[].name" -o tsv 2>/dev/null | sed 's/^/  - /'
        exit 1
    fi
    
    # Get the first APIM instance
    APIM_NAME=$(echo "$APIM_LIST" | jq -r '.[0].name')
    RESOURCE_GROUP=$(echo "$APIM_LIST" | jq -r '.[0].resourceGroup')
    
    print_info "Found APIM: $APIM_NAME in resource group: $RESOURCE_GROUP"
else
    # Get APIM name from the specified resource group
    APIM_NAME=$(az apim list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv 2>/dev/null)
    
    if [ -z "$APIM_NAME" ]; then
        print_error "No APIM found in resource group: $RESOURCE_GROUP"
        print_info "Available APIM instances:"
        az apim list --query "[].{name:name, resourceGroup:resourceGroup}" -o table 2>/dev/null
        exit 1
    fi
    
    print_info "Found APIM: $APIM_NAME in resource group: $RESOURCE_GROUP"
fi

echo ""

# Get APIM gateway URL
print_info "Retrieving APIM gateway URL..."
APIM_URL=$(az apim show --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" --query "gatewayUrl" -o tsv 2>/dev/null)

if [ -z "$APIM_URL" ]; then
    print_error "Failed to retrieve APIM gateway URL"
    exit 1
fi

print_info "APIM URL: $APIM_URL"

# Get APIM resource ID
print_info "Retrieving APIM resource ID..."
APIM_ID=$(az apim show --name "$APIM_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv 2>/dev/null)

if [ -z "$APIM_ID" ]; then
    print_error "Failed to retrieve APIM resource ID"
    exit 1
fi

# Get APIM subscription key
print_info "Retrieving APIM subscription key..."
APIM_KEY=$(az rest --method post \
  --url "${APIM_ID}/subscriptions/master/listSecrets?api-version=2023-05-01-preview" \
  --query primaryKey -o tsv 2>/dev/null)

if [ -z "$APIM_KEY" ]; then
    print_error "Failed to retrieve APIM subscription key"
    exit 1
fi

if [ -z "$APIM_KEY" ]; then
    print_error "Failed to retrieve APIM subscription key"
    exit 1
fi

print_info "Successfully retrieved all credentials"
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
echo "APIM_URL=\"$APIM_URL\" APIM_KEY=\"$APIM_KEY\" ./scripts/load-test-apim.sh"
echo ""

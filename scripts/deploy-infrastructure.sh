#!/bin/bash
# ============================================================================
# Azure SRE Agent Hackathon - Deployment Script
# ============================================================================
# This script deploys the complete infrastructure for the workshop
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${BLUE}ℹ ${1}${NC}"
}

print_success() {
    echo -e "${GREEN}✓ ${1}${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${1}${NC}"
}

print_error() {
    echo -e "${RED}✗ ${1}${NC}"
}

print_header() {
    echo ""
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE} ${1}${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo ""
}

# ============================================================================
# Configuration
# ============================================================================

# Default values
RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:-sre-agent-workshop-rg}"
LOCATION="${LOCATION:-eastus}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
DEPLOYMENT_NAME="sre-agent-workshop-$(date +%Y%m%d-%H%M%S)"

# ============================================================================
# Validation
# ============================================================================

print_header "Azure SRE Agent Hackathon - Infrastructure Deployment"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it first."
    echo "Visit: https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi

print_success "Azure CLI is installed"

# Check if logged in
print_info "Checking Azure login status..."
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
print_success "Logged in to Azure"
print_info "Subscription: ${SUBSCRIPTION_NAME} (${SUBSCRIPTION_ID})"

# Check for PostgreSQL password
if [ -z "$POSTGRES_PASSWORD" ]; then
    print_warning "PostgreSQL password not set in environment variable"
    echo ""
    read -s -p "Enter PostgreSQL admin password (min 12 characters): " POSTGRES_PASSWORD
    echo ""
    
    if [ ${#POSTGRES_PASSWORD} -lt 12 ]; then
        print_error "Password must be at least 12 characters long"
        exit 1
    fi
fi

# Validate password complexity
if ! [[ "$POSTGRES_PASSWORD" =~ [A-Z] ]] || ! [[ "$POSTGRES_PASSWORD" =~ [a-z] ]] || ! [[ "$POSTGRES_PASSWORD" =~ [0-9] ]]; then
    print_error "Password must contain uppercase, lowercase, and numbers"
    exit 1
fi

print_success "PostgreSQL password validated"

# ============================================================================
# Resource Group
# ============================================================================

print_header "Creating Resource Group"

if az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    print_warning "Resource group '$RESOURCE_GROUP_NAME' already exists"
else
    print_info "Creating resource group '$RESOURCE_GROUP_NAME' in '$LOCATION'..."
    az group create \
        --name "$RESOURCE_GROUP_NAME" \
        --location "$LOCATION" \
        --output none
    print_success "Resource group created"
fi

# ============================================================================
# Deployment
# ============================================================================

print_header "Deploying Infrastructure"

print_info "Deployment name: ${DEPLOYMENT_NAME}"
print_info "This will take approximately 10-15 minutes..."
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BICEP_FILE="$SCRIPT_DIR/../infra/main.bicep"
PARAMS_FILE="$SCRIPT_DIR/../infra/main.bicepparam"

if [ ! -f "$BICEP_FILE" ]; then
    print_error "Bicep file not found at: $BICEP_FILE"
    exit 1
fi

# Deploy using parameters file if it exists, otherwise use inline parameters
if [ -f "$PARAMS_FILE" ]; then
    print_info "Using parameters file: $PARAMS_FILE"
    az deployment group create \
        --name "$DEPLOYMENT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file "$BICEP_FILE" \
        --parameters "$PARAMS_FILE" \
        --parameters postgresAdminPassword="$POSTGRES_PASSWORD" \
        --output none
else
    print_info "Using inline parameters"
    az deployment group create \
        --name "$DEPLOYMENT_NAME" \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file "$BICEP_FILE" \
        --parameters postgresAdminPassword="$POSTGRES_PASSWORD" \
        --output none
fi

print_success "Infrastructure deployment completed!"

# ============================================================================
# Output Information
# ============================================================================

print_header "Deployment Outputs"

# Get deployment outputs
print_info "Retrieving deployment outputs..."

APIM_GATEWAY_URL=$(az deployment group show \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query properties.outputs.apimGatewayUrl.value \
    -o tsv)

CONTAINER_APP_FQDN=$(az deployment group show \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query properties.outputs.containerAppFqdn.value \
    -o tsv)

POSTGRES_FQDN=$(az deployment group show \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query properties.outputs.postgresServerFqdn.value \
    -o tsv)

APP_INSIGHTS_NAME=$(az deployment group show \
    --name "$DEPLOYMENT_NAME" \
    --resource-group "$RESOURCE_GROUP_NAME" \
    --query properties.outputs.appInsightsName.value \
    -o tsv)

echo ""
echo "Resource Group:         ${RESOURCE_GROUP_NAME}"
echo "Location:               ${LOCATION}"
echo "API Management URL:     ${APIM_GATEWAY_URL}"
echo "Container App FQDN:     ${CONTAINER_APP_FQDN}"
echo "PostgreSQL Server:      ${POSTGRES_FQDN}"
echo "Application Insights:   ${APP_INSIGHTS_NAME}"
echo ""

# Save outputs to file
OUTPUT_FILE="$SCRIPT_DIR/../.deployment-outputs.env"
cat > "$OUTPUT_FILE" << EOF
# Azure SRE Agent Hackathon - Deployment Outputs
# Generated: $(date)
export RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME}"
export LOCATION="${LOCATION}"
export APIM_GATEWAY_URL="${APIM_GATEWAY_URL}"
export CONTAINER_APP_FQDN="${CONTAINER_APP_FQDN}"
export POSTGRES_FQDN="${POSTGRES_FQDN}"
export APP_INSIGHTS_NAME="${APP_INSIGHTS_NAME}"
export DEPLOYMENT_NAME="${DEPLOYMENT_NAME}"
EOF

print_success "Deployment outputs saved to: ${OUTPUT_FILE}"
print_info "Source this file to use these values: source ${OUTPUT_FILE}"

# ============================================================================
# Next Steps
# ============================================================================

print_header "Next Steps"

echo "1. Review the deployed resources in the Azure Portal"
echo "2. Deploy the sample API application to Container Apps"
echo "3. Configure API Management to expose the API"
echo "4. Test the end-to-end flow"
echo ""
echo "For detailed instructions, see: docs/03-application.md"
echo ""

print_success "Deployment script completed successfully!"

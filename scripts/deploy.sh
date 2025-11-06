#!/bin/bash

# SRE Workshop - Quick Deployment Script
# This script automates the deployment process from Part 1

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found. Please install: https://docs.microsoft.com/cli/azure/install-azure-cli"
        exit 1
    fi
    print_success "Azure CLI found"
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        print_warning "jq not found. Install for better JSON handling (optional)"
    else
        print_success "jq found"
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Run: az login"
        exit 1
    fi
    print_success "Logged in to Azure"
    
    # Show current subscription
    CURRENT_SUB=$(az account show --query name -o tsv)
    print_info "Current subscription: $CURRENT_SUB"
}

# Get user input
get_deployment_config() {
    print_header "Deployment Configuration"
    
    # Base name
    read -p "Enter base name (e.g., sreagent): " BASE_NAME
    if [ -z "$BASE_NAME" ]; then
        print_error "Base name cannot be empty"
        exit 1
    fi
    
    # Resource group
    read -p "Enter resource group name (default: sre-agent-workshop-${BASE_NAME}): " RESOURCE_GROUP
    RESOURCE_GROUP=${RESOURCE_GROUP:-"sre-agent-workshop-${BASE_NAME}"}
    
    # Location
    read -p "Enter Azure region (default: swedencentral): " LOCATION
    LOCATION=${LOCATION:-"swedencentral"}
    
    # Deployment option
    echo ""
    echo "Deployment options:"
    echo "1) Placeholder image (fastest - no build required)"
    echo "2) Custom API from existing ACR"
    read -p "Choose option (1 or 2): " DEPLOY_OPTION
    
    if [ "$DEPLOY_OPTION" == "2" ]; then
        read -p "Enter ACR name: " ACR_NAME
        read -p "Enter image name with tag (e.g., workshop-api:v1.0.1): " IMAGE_NAME
        CONTAINER_IMAGE="${ACR_NAME}.azurecr.io/${IMAGE_NAME}"
    else
        CONTAINER_IMAGE="mcr.microsoft.com/k8se/quickstart:latest"
    fi
    
    # Summary
    echo ""
    print_header "Deployment Summary"
    echo "Base Name:        $BASE_NAME"
    echo "Resource Group:   $RESOURCE_GROUP"
    echo "Location:         $LOCATION"
    echo "Container Image:  $CONTAINER_IMAGE"
    echo ""
    
    read -p "Proceed with deployment? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        print_info "Deployment cancelled"
        exit 0
    fi
}

# Create resource group
create_resource_group() {
    print_header "Creating Resource Group"
    
    if az group show --name $RESOURCE_GROUP &> /dev/null; then
        print_warning "Resource group already exists: $RESOURCE_GROUP"
    else
        az group create --name $RESOURCE_GROUP --location $LOCATION
        print_success "Resource group created: $RESOURCE_GROUP"
    fi
}

# Deploy infrastructure
deploy_infrastructure() {
    print_header "Deploying Infrastructure"
    print_info "This will take approximately 10-12 minutes (APIM is slow)..."
    
    DEPLOYMENT_NAME="workshop-deployment-$(date +%Y%m%d-%H%M%S)"
    
    # Build deployment command
    DEPLOY_CMD="az deployment group create \
        --name $DEPLOYMENT_NAME \
        --resource-group $RESOURCE_GROUP \
        --template-file infra/main.bicep \
        --parameters infra/main.bicepparam \
        --parameters baseName=$BASE_NAME \
        --parameters location=$LOCATION \
        --parameters containerImage=$CONTAINER_IMAGE"
    
    # Execute deployment
    if $DEPLOY_CMD; then
        print_success "Deployment completed successfully!"
    else
        print_error "Deployment failed. Check logs above for details."
        
        # Show failed operations
        print_info "Failed operations:"
        az deployment operation group list \
            --name $DEPLOYMENT_NAME \
            --resource-group $RESOURCE_GROUP \
            --query "[?properties.provisioningState=='Failed'].{Resource: properties.targetResource.resourceName, Error: properties.statusMessage.error.message}" \
            -o table
        
        exit 1
    fi
}

# Configure managed identity for ACR
configure_acr_access() {
    if [ "$DEPLOY_OPTION" == "2" ]; then
        print_header "Configuring ACR Access"
        
        # Get managed identity principal ID
        PRINCIPAL_ID=$(az containerapp show \
            --name ${BASE_NAME}-dev-api \
            --resource-group $RESOURCE_GROUP \
            --query identity.principalId -o tsv)
        
        if [ -z "$PRINCIPAL_ID" ]; then
            print_error "Failed to get managed identity principal ID"
            return 1
        fi
        
        print_info "Managed Identity Principal ID: $PRINCIPAL_ID"
        
        # Get ACR resource ID
        ACR_ID=$(az acr show --name $ACR_NAME --query id -o tsv)
        
        # Grant AcrPull role
        print_info "Granting AcrPull role..."
        az role assignment create \
            --assignee $PRINCIPAL_ID \
            --role AcrPull \
            --scope $ACR_ID
        
        print_success "ACR access configured"
        
        # Restart container app
        print_info "Restarting Container App to pull image..."
        sleep 10  # Wait for role assignment to propagate
        
        REVISION_NAME=$(az containerapp revision list \
            --name ${BASE_NAME}-dev-api \
            --resource-group $RESOURCE_GROUP \
            --query "[0].name" -o tsv)
        
        az containerapp revision restart \
            --name ${BASE_NAME}-dev-api \
            --resource-group $RESOURCE_GROUP \
            --revision $REVISION_NAME
        
        print_success "Container App restarted"
    fi
}

# Get deployment outputs
get_outputs() {
    print_header "Deployment Outputs"
    
    # Get APIM URL
    APIM_NAME=$(az apim list --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)
    if [ -n "$APIM_NAME" ]; then
        APIM_URL=$(az apim show --name $APIM_NAME --resource-group $RESOURCE_GROUP --query gatewayUrl -o tsv)
        print_success "APIM Gateway URL: $APIM_URL"
        
        # Get subscription key
        SUBSCRIPTION_KEY=$(az apim subscription list \
            --resource-group $RESOURCE_GROUP \
            --service-name $APIM_NAME \
            --query "[0].primaryKey" -o tsv)
        print_success "Subscription Key: $SUBSCRIPTION_KEY"
    else
        print_warning "APIM not found"
    fi
    
    # Get Container App URL
    CONTAINER_APP_URL=$(az containerapp show \
        --name ${BASE_NAME}-dev-api \
        --resource-group $RESOURCE_GROUP \
        --query properties.configuration.ingress.fqdn -o tsv)
    if [ -n "$CONTAINER_APP_URL" ]; then
        print_success "Container App URL: https://$CONTAINER_APP_URL"
    fi
    
    # Get PostgreSQL details
    POSTGRES_NAME=$(az postgres flexible-server list \
        --resource-group $RESOURCE_GROUP \
        --query "[0].name" -o tsv)
    if [ -n "$POSTGRES_NAME" ]; then
        POSTGRES_HOST=$(az postgres flexible-server show \
            --resource-group $RESOURCE_GROUP \
            --name $POSTGRES_NAME \
            --query fullyQualifiedDomainName -o tsv)
        print_success "PostgreSQL Host: $POSTGRES_HOST"
    fi
    
    # Application Insights
    APP_INSIGHTS_NAME=$(az monitor app-insights component list \
        --resource-group $RESOURCE_GROUP \
        --query "[0].name" -o tsv)
    if [ -n "$APP_INSIGHTS_NAME" ]; then
        print_success "Application Insights: $APP_INSIGHTS_NAME"
    fi
}

# Test deployment
test_deployment() {
    print_header "Testing Deployment"
    
    if [ -z "$APIM_URL" ] || [ -z "$SUBSCRIPTION_KEY" ]; then
        print_warning "Cannot test - APIM URL or subscription key not found"
        return
    fi
    
    print_info "Testing health endpoint..."
    HEALTH_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
        "$APIM_URL/api/health")
    
    if [ "$HEALTH_RESPONSE" == "200" ]; then
        print_success "Health check passed (HTTP 200)"
    else
        print_warning "Health check returned HTTP $HEALTH_RESPONSE"
    fi
    
    print_info "Testing root endpoint..."
    ROOT_RESPONSE=$(curl -s \
        -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
        "$APIM_URL/api/")
    
    echo "$ROOT_RESPONSE" | head -c 100
    echo ""
}

# Save environment variables
save_env_vars() {
    print_header "Saving Environment Variables"
    
    ENV_FILE=".env.${BASE_NAME}"
    
    cat > $ENV_FILE << EOF
# SRE Workshop Environment Variables
# Generated: $(date)

export RESOURCE_GROUP="$RESOURCE_GROUP"
export LOCATION="$LOCATION"
export BASE_NAME="$BASE_NAME"
export APIM_URL="$APIM_URL"
export SUBSCRIPTION_KEY="$SUBSCRIPTION_KEY"
export CONTAINER_APP_URL="https://$CONTAINER_APP_URL"
export POSTGRES_HOST="$POSTGRES_HOST"
export APP_INSIGHTS_NAME="$APP_INSIGHTS_NAME"
export SUBSCRIPTION_ID="$(az account show --query id -o tsv)"

# Usage:
# source $ENV_FILE
EOF
    
    print_success "Environment variables saved to: $ENV_FILE"
    print_info "Load with: source $ENV_FILE"
}

# Print next steps
print_next_steps() {
    print_header "Next Steps"
    
    echo "1. Load environment variables:"
    echo "   source .env.${BASE_NAME}"
    echo ""
    echo "2. Test the API:"
    echo "   curl -H \"Ocp-Apim-Subscription-Key: \$SUBSCRIPTION_KEY\" \"\$APIM_URL/api/health\""
    echo ""
    echo "3. Continue with workshop exercises:"
    echo "   - Part 1: exercises/part1-setup.md"
    echo "   - Part 2: exercises/part2-troubleshooting.md"
    echo "   - Part 3: exercises/part3-monitoring.md"
    echo ""
    echo "4. When done, clean up resources:"
    echo "   az group delete --name $RESOURCE_GROUP --yes"
    echo ""
    
    print_success "Deployment complete! Happy learning! 🚀"
}

# Main execution
main() {
    print_header "SRE Workshop - Quick Deployment"
    
    check_prerequisites
    get_deployment_config
    create_resource_group
    deploy_infrastructure
    configure_acr_access
    get_outputs
    test_deployment
    save_env_vars
    print_next_steps
}

# Run main function
main

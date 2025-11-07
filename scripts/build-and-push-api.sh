#!/bin/bash

#======================================================================================================
# Build and Push Workshop API to Azure Container Registry using ACR Build Tasks
#======================================================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
IMAGE_NAME="workshop-api"
IMAGE_TAG="${1:-latest}"
ACR_NAME="${ACR_NAME:-}"
RESOURCE_GROUP="${RESOURCE_GROUP:-}"

echo "============================================================================"
echo " Workshop API - Build and Push to ACR using ACR Build Tasks"
echo "============================================================================"
echo ""

# Check if ACR_NAME is provided
if [ -z "$ACR_NAME" ]; then
    echo -e "${RED}✗ ACR_NAME environment variable is not set${NC}"
    echo "Usage: ACR_NAME=<your-acr> ./scripts/build-and-push-api.sh [tag]"
    echo "Example: ACR_NAME=myacr ./scripts/build-and-push-api.sh v1.0.0"
    exit 1
fi

# Navigate to repo root
cd "$(dirname "$0")/.."

# Build and push using ACR build tasks
echo "→ Building and pushing image using ACR build tasks..."
ACR_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
az acr build \
  --registry ${ACR_NAME} \
  --image ${ACR_IMAGE} \
  --file src/api/Dockerfile \
  src/api

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ ACR build failed${NC}"
    exit 1
fi

echo ""
echo "============================================================================"
echo -e "${GREEN} Build and Push Complete!${NC}"
echo "============================================================================"
echo ""
echo "Image: ${ACR_NAME}.azurecr.io/${ACR_IMAGE}"
echo ""
echo "Next steps:"
echo "  1. Update infra/main.bicepparam with the new image:"
echo "     containerImage: '${ACR_IMAGE}'"
echo ""
echo "  2. Redeploy the infrastructure:"
echo "     ./scripts/deploy-infrastructure.sh"
echo ""
echo "  3. Verify the deployment:"
echo "     az containerapp show --name <app-name> --resource-group <rg-name>"
echo ""

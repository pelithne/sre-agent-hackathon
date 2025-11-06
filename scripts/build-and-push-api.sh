#!/bin/bash

#======================================================================================================
# Build and Push Workshop API to Azure Container Registry
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
echo " Workshop API - Build and Push to ACR"
echo "============================================================================"
echo ""

# Check if ACR_NAME is provided
if [ -z "$ACR_NAME" ]; then
    echo -e "${RED}✗ ACR_NAME environment variable is not set${NC}"
    echo "Usage: ACR_NAME=<your-acr> ./scripts/build-and-push-api.sh [tag]"
    echo "Example: ACR_NAME=myacr ./scripts/build-and-push-api.sh v1.0.0"
    exit 1
fi

# Navigate to API directory
cd "$(dirname "$0")/../src/api"

echo "→ Building Docker image..."
docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Docker build failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker image built successfully${NC}"
echo ""

# Tag for ACR
ACR_IMAGE="${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}"
echo "→ Tagging image for ACR: ${ACR_IMAGE}"
docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ACR_IMAGE}
echo -e "${GREEN}✓ Image tagged${NC}"
echo ""

# Login to ACR
echo "→ Logging in to Azure Container Registry..."
az acr login --name ${ACR_NAME}
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ ACR login failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Logged in to ACR${NC}"
echo ""

# Push to ACR
echo "→ Pushing image to ACR..."
docker push ${ACR_IMAGE}
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Docker push failed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Image pushed successfully${NC}"
echo ""

echo "============================================================================"
echo -e "${GREEN} Build and Push Complete!${NC}"
echo "============================================================================"
echo ""
echo "Image: ${ACR_IMAGE}"
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

#!/bin/bash
# ============================================================================
# Cleanup Script - Remove Test Resources
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}============================================================================${NC}"
echo -e "${BLUE} Azure SRE Agent Hackathon - Cleanup${NC}"
echo -e "${BLUE}============================================================================${NC}"
echo ""

# Resource group to delete
RG_NAME="${1:-sre-agent-test-rg}"

# Check if resource group exists
if ! az group show --name "$RG_NAME" &> /dev/null; then
    echo -e "${YELLOW}⚠ Resource group '$RG_NAME' does not exist${NC}"
    exit 0
fi

echo -e "${YELLOW}This will delete the resource group: ${RED}$RG_NAME${NC}"
echo ""
echo "Resources to be deleted:"
az resource list --resource-group "$RG_NAME" --query '[].{Name:name, Type:type}' -o table
echo ""

read -p "Are you sure you want to delete all these resources? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${YELLOW}Cleanup cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${YELLOW}Deleting resource group '$RG_NAME'...${NC}"
echo "This may take several minutes..."

az group delete \
  --name "$RG_NAME" \
  --yes \
  --no-wait

echo ""
echo -e "${GREEN}✓ Resource group deletion initiated${NC}"
echo ""
echo "The deletion is running in the background."
echo "To check status:"
echo "  az group show --name $RG_NAME"
echo ""

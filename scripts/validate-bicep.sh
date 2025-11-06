#!/bin/bash
# ============================================================================
# Validate Bicep Templates Script
# ============================================================================

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

ERRORS=0

print_header "Bicep Template Validation"

# 1. Check Azure CLI
print_info "Checking Azure CLI..."
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed"
    ERRORS=$((ERRORS + 1))
else
    AZ_VERSION=$(az version --query '"azure-cli"' -o tsv)
    print_success "Azure CLI installed (version $AZ_VERSION)"
fi

# 2. Check Azure login
print_info "Checking Azure authentication..."
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure"
    ERRORS=$((ERRORS + 1))
else
    SUBSCRIPTION=$(az account show --query name -o tsv)
    print_success "Logged in to Azure (Subscription: $SUBSCRIPTION)"
fi

# 3. Validate Bicep syntax
print_info "Validating Bicep syntax..."
if az bicep build --file infra/main.bicep --stdout > /dev/null 2>&1; then
    print_success "Bicep syntax is valid"
else
    print_error "Bicep syntax validation failed"
    az bicep build --file infra/main.bicep 2>&1 | grep -i error
    ERRORS=$((ERRORS + 1))
fi

# 4. Check Bicep file exists
print_info "Checking required files..."
if [ -f "infra/main.bicep" ]; then
    print_success "main.bicep found"
else
    print_error "main.bicep not found"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "infra/main.bicepparam" ]; then
    print_success "main.bicepparam found"
else
    print_error "main.bicepparam not found"
    ERRORS=$((ERRORS + 1))
fi

# 5. Check deployment script
if [ -f "scripts/deploy-infrastructure.sh" ] && [ -x "scripts/deploy-infrastructure.sh" ]; then
    print_success "deploy-infrastructure.sh is executable"
else
    print_error "deploy-infrastructure.sh not found or not executable"
    ERRORS=$((ERRORS + 1))
fi

# 6. Lint Bicep file
print_info "Running Bicep linter..."
LINT_OUTPUT=$(az bicep build --file infra/main.bicep 2>&1 || true)
if echo "$LINT_OUTPUT" | grep -qi "warning\|error"; then
    echo "$LINT_OUTPUT" | grep -i "warning\|error" || true
else
    print_success "No linting warnings or errors"
fi

# 7. Count resources
print_info "Analyzing template..."
RESOURCE_COUNT=$(grep -c "^resource " infra/main.bicep || echo "0")
MODULE_COUNT=$(grep -c "^module " infra/main.bicep || echo "0")
print_success "Template contains $RESOURCE_COUNT resources and $MODULE_COUNT modules"

# 8. Check for secure parameters
print_info "Checking security practices..."
if grep -q "@secure()" infra/main.bicep; then
    SECURE_PARAMS=$(grep -c "@secure()" infra/main.bicep)
    print_success "Found $SECURE_PARAMS secure parameter(s)"
else
    print_error "No secure parameters found - consider marking sensitive parameters with @secure()"
fi

# 9. Resource types detected
print_info "Resource types in template:"
grep "^resource " infra/main.bicep | awk '{print $3}' | sed "s/'//g" | sort -u | while read -r type; do
    echo "  - $type"
done

print_header "Validation Summary"

if [ $ERRORS -eq 0 ]; then
    print_success "All validation checks passed!"
    echo ""
    echo "Next steps:"
    echo "  1. Run what-if analysis:"
    echo "     ./scripts/validate-deployment.sh --what-if"
    echo ""
    echo "  2. Test deployment:"
    echo "     ./scripts/test-deployment.sh"
    echo ""
    echo "  3. Cleanup test resources:"
    echo "     ./scripts/cleanup.sh"
    exit 0
else
    print_error "Validation failed with $ERRORS error(s)"
    echo ""
    echo "Please fix the errors above before deploying."
    exit 1
fi

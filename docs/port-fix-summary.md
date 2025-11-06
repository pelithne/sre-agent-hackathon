# Container App Port Configuration Fix

## Issue
Container App deployment was failing with the error:
```
Deployment Progress Deadline Exceeded. 0/1 replicas ready. 
The TargetPort 8000 does not match the listening port 80.
```

## Root Cause
The Bicep template was configured with:
- **Target Port**: 8000
- **Container Image**: `mcr.microsoft.com/azuredocs/containerapps-helloworld:latest`
- **PORT environment variable**: "8000"

However, the hello-world placeholder image **always listens on port 80** and ignores the PORT environment variable.

## Solution
Updated the Bicep template (`infra/main.bicep`):

### Changed Configuration
```bicep
configuration: {
  ingress: {
    external: false
    targetPort: 80  // Changed from 8000 to 80
    transport: 'http'
    allowInsecure: false
  }
}

template: {
  containers: [
    {
      name: 'api-container'
      image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
      env: [
        // Removed PORT environment variable (not used by hello-world image)
      ]
    }
  ]
}
```

### Applied Fix
1. Updated Bicep template with correct port (80)
2. Validated template with `./scripts/validate-bicep.sh` ✅
3. Committed and pushed changes (commit: 8cd1db5)
4. Updated Container App ingress: `az containerapp ingress update --target-port 80`

## Verification
After applying the fix:
- ✅ **Container App Status**: Healthy
- ✅ **Replicas Running**: 1/1
- ✅ **Target Port**: 80
- ✅ **Revision Active**: sretest-test-api--8vmyfd8
- ✅ **APIM Gateway**: Succeeded (https://sretest-test-apim-anthsowmeh3v4.azure-api.net)

## Future Considerations
When we replace the placeholder image with the actual workshop API:
1. The API should expose a configurable PORT environment variable
2. Update `targetPort` in Bicep to match the API's listening port (e.g., 8000)
3. Set the PORT environment variable to match
4. Ensure proper health probes are configured

## Command Reference
```bash
# Check Container App status
az containerapp show \
  --name sretest-test-api \
  --resource-group sre-agent-consumption-test-rg \
  --query "{Health: properties.runningStatus, TargetPort: properties.configuration.ingress.targetPort}"

# Check revisions
az containerapp revision list \
  --name sretest-test-api \
  --resource-group sre-agent-consumption-test-rg \
  --query "[].{Revision: name, Active: properties.active, Health: properties.healthState, Replicas: properties.replicas}"

# Update ingress port
az containerapp ingress update \
  --name sretest-test-api \
  --resource-group sre-agent-consumption-test-rg \
  --target-port 80
```

---

*Fixed*: 2025-11-06  
*Commit*: 8cd1db5  
*Status*: ✅ Resolved

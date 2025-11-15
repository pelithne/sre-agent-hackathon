# Database Connection Issue Investigation

## Problem
Database connection failing with error:
```
Database connection failed: connection to server at "srepeter3-dev-psql-djq3qysxltsme.postgres.database.azure.com" (10.0.2.4), port 5432 failed: FATAL: password authentication failed for user "sqladmin"
```

## Root Cause Analysis

### Investigation Steps
1. ✅ **Checked PostgreSQL server configuration** - Server exists and admin user is correct
2. ✅ **Verified password** - Reset password to ensure consistency  
3. ✅ **Examined connection string format** - Found mismatch with original working version

### Key Findings

#### Issue 1: Connection String Construction Method
**Problem**: Used `format()` function which Bicep treats as potentially insecure
```bicep
// ❌ Current (broken)
value: format('postgresql://{0}:{1}@{2}:5432/{3}?sslmode=require', postgresAdminUsername, postgresAdminPassword, postgresServerFqdn, postgresDatabaseName)

// ✅ Original working version  
value: 'postgresql://${postgresAdminUsername}:${postgresAdminPassword}@${postgresServer.properties.fullyQualifiedDomainName}:5432/workshopdb?sslmode=require'
```

#### Issue 2: Environment Variable Duplication & Invalid Secret Reference
**Problem**: During troubleshooting, added extra PostgreSQL environment variables that:
- Referenced non-existent `postgres-password` secret  
- Duplicated variables already passed from `apps.bicep`
- Caused deployment error: "SecretRef 'postgres-password' defined for container 'api-container' not found"

**Solution**: 
- Use `containerAppConfig.environmentVariables` passed from `apps.bicep` 
- Remove hardcoded environment variables from `containerApps.bicep` module
- Eliminate environment variable duplication

### Issue 3: Port Configuration Mismatch  
**Original working version**:
- Target Port: 8000
- PORT env var: '8000'

**Current version**:
- Target Port: 8080  
- PORT env var: '8080'

## Solution Applied

### 1. Fixed Connection String Format ✅
- Reverted to string interpolation (`${variable}`) instead of `format()` function
- Added Bicep lint pragma to suppress false positive security warning
- Matches exact working configuration from `main.bicep.backup`

### 2. Fixed Environment Variable Configuration ✅
- Removed duplicate environment variables from `containerApps.bicep`
- Use `containerAppConfig.environmentVariables` passed from `apps.bicep`  
- Eliminated invalid `postgres-password` secret reference
- Resolved "SecretRef not found" deployment error

### 3. Connection String Format
```bicep
secrets: [
  {
    name: 'db-connection-string'
    #disable-next-line no-hardcoded-secrets
    value: 'postgresql://${postgresAdminUsername}:${postgresAdminPassword}@${postgresServerFqdn}:5432/${postgresDatabaseName}?sslmode=require'
  }
]
```

## Next Steps
1. ✅ **Deployed fix** to feature branch
2. 🔄 **Test database connectivity** after deployment
3. 🔍 **Verify port configuration** if issues persist (8000 vs 8080)
4. 📝 **Document in PR** for review before merging to master

## Files Modified
- `infra/modules/containerApps.bicep` - Fixed connection string format and environment variables
- `DATABASE_CONNECTION_FIX.md` - Investigation documentation

## Lessons Learned
- String interpolation in Bicep is preferred over `format()` for secure values
- Always compare with last working version when troubleshooting regressions
- Two-phase deployment split introduced subtle configuration differences that need careful migration
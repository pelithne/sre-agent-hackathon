// ============================================================================
// Azure SRE Agent Hackathon - Applications Template (Phase 2)
// ============================================================================
// This template deploys applications on top of existing infrastructure:
// - Container Apps Environment with VNET integration
// - Container Apps with the actual built images
// - APIM integration
// ============================================================================

targetScope = 'resourceGroup'

import { ResourceTags } from './modules/types.bicep'

// ============================================================================
// Parameters
// ============================================================================

@description('The primary location for all resources')
param location string = resourceGroup().location

@description('Environment name (e.g., dev, staging, prod)')
@minLength(2)
@maxLength(10)
param environmentName string = 'dev'

@description('Base name for resources (used to generate unique resource names)')
@minLength(3)
@maxLength(15)
param baseName string = 'sreagent'

@description('Container image registry URL')
param containerImageRegistry string

@description('Container image name and tag')
param containerImageName string = 'workshop-api:v1.0.0'

@description('PostgreSQL administrator username')
param postgresAdminUsername string = 'sqladmin'

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('Tags to apply to all resources')
param tags ResourceTags = {
  Environment: environmentName
  ManagedBy: 'Bicep'
  Project: 'SRE-Agent-Hackathon'
}

// ============================================================================
// Variables
// ============================================================================

var uniqueSuffix = uniqueString(resourceGroup().id)
var namingPrefix = '${baseName}-${environmentName}'

// Configuration objects for modules
var namingConfig = {
  baseName: baseName
  environmentName: environmentName
  uniqueSuffix: uniqueSuffix
  namingPrefix: namingPrefix
}

var containerAppConfig = {
  image: '${containerImageRegistry}/${containerImageName}'
  cpu: '0.5'
  memory: '1.0Gi'
  minReplicas: 1
  maxReplicas: 5
  targetPort: 8080
  environmentVariables: [
    {
      name: 'DATABASE_URL'
      secretRef: 'db-connection-string'
    }
    {
      name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
      secretRef: 'appinsights-connection-string'
    }
  ]
}

var databaseConfig = {
  adminUsername: postgresAdminUsername
  adminPassword: postgresAdminPassword
  databaseName: 'workshopdb'
}

var apiManagementConfig = {
  skuName: 'Consumption'
  skuCapacity: 0
  publisherEmail: 'admin@workshop.local'
  publisherName: 'Workshop Admin'
  apiPathPrefix: 'api'
  apiDisplayName: 'Workshop API'
  apiDescription: 'SRE Agent Hackathon Workshop API'
}

// ============================================================================
// Existing Resource References
// ============================================================================

// Reference existing resources from Phase 1
resource existingVnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  name: '${namingPrefix}-vnet'
}

resource existingLogAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: '${namingPrefix}-logs-${uniqueSuffix}'
}

resource existingAppInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${namingPrefix}-ai-${uniqueSuffix}'
}

resource existingManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: '${namingPrefix}-identity'
}

resource existingACR 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: '${baseName}${environmentName}acr${uniqueSuffix}'
}

resource existingApim 'Microsoft.ApiManagement/service@2023-09-01-preview' existing = {
  name: '${namingPrefix}-apim-${uniqueSuffix}'
}

resource existingPostgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' existing = {
  name: '${namingPrefix}-psql-${uniqueSuffix}'
}

// Get subnet references
var containerAppsSubnetId = '${existingVnet.id}/subnets/container-apps-subnet'

// ============================================================================
// Module Deployments
// ============================================================================

// Deploy Container Apps Environment and Apps
module containerApps './modules/containerApps.bicep' = {
  name: 'containerApps-deployment'
  params: {
    location: location
    containerAppConfig: containerAppConfig
    namingConfig: namingConfig
    tags: tags
    containerAppsSubnetId: containerAppsSubnetId
    managedIdentityId: existingManagedIdentity.id
    logAnalyticsCustomerId: existingLogAnalytics.properties.customerId
    logAnalyticsSharedKey: existingLogAnalytics.listKeys().primarySharedKey
    acrName: existingACR.name
    postgresServerFqdn: existingPostgresServer.properties.fullyQualifiedDomainName
    postgresDatabaseName: databaseConfig.databaseName
    postgresAdminUsername: databaseConfig.adminUsername
    postgresAdminPassword: databaseConfig.adminPassword
    appInsightsConnectionString: existingAppInsights.properties.ConnectionString
  }
}

// Configure APIM APIs and backends (APIM service deployed in Phase 1)
module apimConfiguration './modules/apim-configuration.bicep' = {
  name: 'apim-configuration'
  params: {
    containerAppUrl: containerApps.outputs.containerAppUrl
    apimName: existingApim.name
    apiManagementConfig: apiManagementConfig
    appInsightsName: existingAppInsights.name
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Container Apps Environment Name')
output containerAppsEnvironmentName string = containerApps.outputs.containerAppEnvName

@description('API Container App Name')
output apiContainerAppName string = containerApps.outputs.containerAppName

@description('API Container App URL')
output apiContainerAppUrl string = containerApps.outputs.containerAppUrl

@description('APIM Gateway URL')
output apimGatewayUrl string = existingApim.properties.gatewayUrl

@description('APIM API URL (with path prefix)')
output apimApiUrl string = apimConfiguration.outputs.apiUrl

@description('Application deployment summary')
output deploymentInfo object = {
  environment: environmentName
  baseName: baseName
  location: location
  phase: 'applications'
  containerApps: {
    environmentName: containerApps.outputs.containerAppEnvName
    apiUrl: containerApps.outputs.containerAppUrl
  }
  apim: {
    gatewayUrl: existingApim.properties.gatewayUrl
    apiUrl: apimConfiguration.outputs.apiUrl
  }
  nextSteps: [
    '1. Test API directly: curl ${containerApps.outputs.containerAppUrl}/health'
    '2. Test API via APIM: curl -H "Ocp-Apim-Subscription-Key: <SUBSCRIPTION_KEY>" ${apimConfiguration.outputs.apiUrl}/health'
    '3. Get APIM subscription key: az rest --method post --url "$(az apim show --name ${existingApim.name} --query id -o tsv)/subscriptions/master/listSecrets?api-version=2023-05-01-preview" --query primaryKey -o tsv'
  ]
}

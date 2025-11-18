// ============================================================================
// Azure SRE Agent Hackathon - Modular Infrastructure Template
// ============================================================================
// This modular template deploys a complete cloud-native application stack using
// dedicated modules for each service category:
// - Networking: VNet, subnets, private DNS zones
// - Monitoring: Log Analytics, Application Insights
// - Identity: Managed identity with ACR integration
// - Database: PostgreSQL Flexible Server with private networking
// - Container Apps: Environment and Container App with scaling
// - API Management: APIM service with full API configuration
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

@description('Administrator username for PostgreSQL')
@minLength(1)
param postgresAdminUsername string = 'sqladmin'

@description('Administrator password for PostgreSQL')
@secure()
@minLength(12)
param postgresAdminPassword string

@description('Container image for the API (will be built and pushed to ACR)')
param containerImage string = 'workshop-api:latest'

@description('Tags to apply to all resources')
param tags ResourceTags = {
  Environment: environmentName
  Project: 'SRE-Agent-Hackathon'
  ManagedBy: 'Bicep'
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

var networkConfig = {
  vnetAddressPrefix: '10.0.0.0/16'
  containerAppsSubnetPrefix: '10.0.0.0/23'
  postgresSubnetPrefix: '10.0.2.0/24'
  apimSubnetPrefix: '10.0.3.0/24'
}

var databaseConfig = {
  adminUsername: postgresAdminUsername
  adminPassword: postgresAdminPassword
  databaseName: 'workshopdb'
  sku: 'Standard_B1ms'
  storageSizeGB: 32
  backupRetentionDays: 7
  highAvailability: 'Disabled'
}

var containerAppConfig = {
  image: '${acr.outputs.acrLoginServer}/${containerImage}'
  cpu: '0.5'
  memory: '1Gi'
  minReplicas: 1
  maxReplicas: 3
  targetPort: 8000
  environmentVariables: []
}

var apiManagementConfig = {
  skuName: 'Consumption'
  skuCapacity: 0
  publisherName: 'SRE Workshop'
  publisherEmail: 'admin@contoso.com'
  apiPathPrefix: 'api'
  apiDisplayName: 'Workshop API'
  apiDescription: 'RESTful API for SRE Agent Hackathon workshop'
}

var monitoringConfig = {
  logRetentionDays: 30
  applicationType: 'web'
  requestSource: 'rest'
  flowType: 'Bluefield'
  samplingPercentage: 100
}

// ============================================================================
// Module Deployments
// ============================================================================

// Deploy networking infrastructure
module networking './modules/networking.bicep' = {
  name: 'networking-deployment'
  params: {
    location: location
    networkConfig: networkConfig
    namingConfig: namingConfig
    tags: tags
  }
}

// Deploy monitoring infrastructure
module monitoring './modules/monitoring.bicep' = {
  name: 'monitoring-deployment'
  params: {
    location: location
    monitoringConfig: monitoringConfig
    namingConfig: namingConfig
    tags: tags
  }
}

// Deploy identity infrastructure (depends on ACR)
module identity './modules/identity.bicep' = {
  name: 'identity-deployment'
  params: {
    location: location
    namingConfig: namingConfig
    tags: tags
    acrName: acr.outputs.acrName
  }
}

// Deploy Azure Container Registry
module acr './modules/acr.bicep' = {
  name: 'acr-deployment'
  params: {
    location: location
    namingConfig: namingConfig
    tags: tags
  }
}

// Deploy database infrastructure
module database './modules/database.bicep' = {
  name: 'database-deployment'
  params: {
    location: location
    databaseConfig: databaseConfig
    namingConfig: namingConfig
    tags: tags
    postgresSubnetId: networking.outputs.postgresSubnetId
    postgresDnsZoneId: networking.outputs.postgresDnsZoneId
  }
}

// Deploy Container Apps infrastructure  
module containerApps './modules/containerApps.bicep' = {
  name: 'container-apps-deployment'
  params: {
    location: location
    containerAppConfig: containerAppConfig
    namingConfig: namingConfig
    tags: tags
    containerAppsSubnetId: networking.outputs.containerAppsSubnetId
    logAnalyticsCustomerId: monitoring.outputs.logAnalyticsCustomerId
    logAnalyticsSharedKey: monitoring.outputs.logAnalyticsSharedKey
    managedIdentityId: identity.outputs.managedIdentityId
    acrName: acr.outputs.acrName
    postgresServerFqdn: database.outputs.postgresServerFqdn
    postgresDatabaseName: database.outputs.postgresDatabaseName
    postgresAdminUsername: database.outputs.postgresAdminUsername
    postgresAdminPassword: postgresAdminPassword
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
  }
}

// Deploy API Management infrastructure
module apiManagement './modules/apiManagement.bicep' = {
  name: 'api-management-deployment'
  params: {
    location: location
    apiManagementConfig: apiManagementConfig
    namingConfig: namingConfig
    tags: tags
    containerAppUrl: containerApps.outputs.containerAppUrl
    appInsightsId: monitoring.outputs.appInsightsId
    appInsightsName: monitoring.outputs.appInsightsName
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('API Management Gateway URL')
output apimGatewayUrl string = apiManagement.outputs.apimGatewayUrl

@description('API Management service name')
output apimServiceName string = apiManagement.outputs.apimName

@description('Complete API URL for testing')
output apiUrl string = apiManagement.outputs.apiUrl

@description('Container App FQDN')
output containerAppFqdn string = containerApps.outputs.containerAppFqdn

@description('Container App name')
output containerAppName string = containerApps.outputs.containerAppName

@description('PostgreSQL server FQDN')
output postgresServerFqdn string = database.outputs.postgresServerFqdn

@description('PostgreSQL database name')
output postgresDatabaseName string = database.outputs.postgresDatabaseName

@description('Application Insights name')
output appInsightsName string = monitoring.outputs.appInsightsName

@description('Application Insights connection string')
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString

@description('Log Analytics workspace ID')
output logAnalyticsWorkspaceId string = monitoring.outputs.logAnalyticsId

@description('Managed Identity client ID')
output managedIdentityClientId string = identity.outputs.managedIdentityClientId

@description('Managed Identity principal ID')
output managedIdentityPrincipalId string = identity.outputs.managedIdentityPrincipalId

@description('Virtual Network ID')
output vnetId string = networking.outputs.vnetId

@description('ACR Name')
output acrName string = acr.outputs.acrName

@description('ACR Login Server')
output acrLoginServer string = acr.outputs.acrLoginServer

@description('Container App URL')
output containerAppUrl string = containerApps.outputs.containerAppUrl

@description('Deployment summary')
output deploymentInfo object = {
  environment: environmentName
  baseName: baseName
  location: location
  acr: {
    name: acr.outputs.acrName
    loginServer: acr.outputs.acrLoginServer
  }
  modules: {
    networking: networking.outputs.vnetName
    monitoring: monitoring.outputs.logAnalyticsName
    identity: identity.outputs.managedIdentityName
    acr: acr.outputs.acrName
    database: database.outputs.postgresServerName
    containerApps: containerApps.outputs.containerAppName
    apiManagement: apiManagement.outputs.apimName
  }
}

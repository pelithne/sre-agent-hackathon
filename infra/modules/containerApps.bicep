// ============================================================================
// Container Apps Module for SRE Agent Hackathon Infrastructure
// ============================================================================
// This module creates the Container Apps infrastructure including:
// - Container Apps Environment with Log Analytics integration
// - Container App with managed identity and secure secrets
// - Auto-scaling configuration and ingress setup
// - Environment variables and application configuration
// ============================================================================

targetScope = 'resourceGroup'

import { ContainerAppConfig, NamingConfig, ResourceTags } from './types.bicep'

// ============================================================================
// Parameters
// ============================================================================

@description('Resource location')
param location string

@description('Container App configuration settings')
param containerAppConfig ContainerAppConfig

@description('Naming configuration')
param namingConfig NamingConfig

@description('Resource tags')
param tags ResourceTags

@description('Container Apps subnet resource ID')
param containerAppsSubnetId string

@description('Log Analytics workspace customer ID')
param logAnalyticsCustomerId string

@description('Log Analytics workspace shared key')
@secure()
param logAnalyticsSharedKey string

@description('Managed identity resource ID')
param managedIdentityId string

@description('ACR name for registry authentication (optional)')
param acrName string = ''

@description('PostgreSQL server FQDN')
param postgresServerFqdn string

@description('PostgreSQL database name')
param postgresDatabaseName string

@description('PostgreSQL admin username')
param postgresAdminUsername string

@description('PostgreSQL admin password')
@secure()
param postgresAdminPassword string

@description('Application Insights connection string')
@secure()
param appInsightsConnectionString string

// ============================================================================
// Variables
// ============================================================================

var containerAppEnvName = '${namingConfig.namingPrefix}-cae-${namingConfig.uniqueSuffix}'
var containerAppName = '${namingConfig.namingPrefix}-api'

// Determine if we're using the hello-world placeholder or custom API
var isPlaceholderImage = contains(containerAppConfig.image, 'helloworld')
var targetPort = isPlaceholderImage ? 80 : containerAppConfig.targetPort

// ============================================================================
// Resources
// ============================================================================

// Container Apps Environment
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsSharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: containerAppsSubnetId
    }
    zoneRedundant: false // Single zone for cost optimization in workshop
  }
}

// Container App
resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    environmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true // External ingress required for APIM to reach the Container App
        targetPort: targetPort
        transport: 'http'
        allowInsecure: false
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
          allowedHeaders: ['*']
        }
      }
      registries: !empty(acrName) ? [
        {
          server: '${acrName}.azurecr.io'
          identity: managedIdentityId
        }
      ] : []
      secrets: [
        {
          name: 'db-connection-string'
          // String interpolation matches the original working implementation
          #disable-next-line no-hardcoded-secrets
          value: 'postgresql://${postgresAdminUsername}:${postgresAdminPassword}@${postgresServerFqdn}:5432/${postgresDatabaseName}?sslmode=require'
        }
        {
          name: 'appinsights-connection-string'
          value: appInsightsConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'api-container'
          image: containerAppConfig.image
          resources: {
            cpu: json(containerAppConfig.cpu)
            memory: containerAppConfig.memory
          }
          env: concat(
            [
              {
                name: 'DATABASE_URL'
                secretRef: 'db-connection-string'
              }
              {
                name: 'POSTGRES_HOST'
                value: postgresServerFqdn
              }
              {
                name: 'POSTGRES_PORT'
                value: '5432'
              }
              {
                name: 'POSTGRES_DB'
                value: postgresDatabaseName
              }
              {
                name: 'POSTGRES_USER'
                value: postgresAdminUsername
              }
              {
                name: 'POSTGRES_PASSWORD'
                secretRef: 'postgres-password'
              }
              {
                name: 'POSTGRES_SSL'
                value: 'require'
              }
              {
                name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
                secretRef: 'appinsights-connection-string'
              }
            ],
            // Add PORT environment variable only for custom API (not for placeholder)
            isPlaceholderImage ? [] : [
              {
                name: 'PORT'
                value: string(containerAppConfig.targetPort)
              }
            ],
            // Add any additional environment variables
            containerAppConfig.environmentVariables
          )
        }
      ]
      scale: {
        minReplicas: containerAppConfig.minReplicas
        maxReplicas: containerAppConfig.maxReplicas
        rules: [
          {
            name: 'http-scaling'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Container Apps Environment resource ID')
output containerAppEnvId string = containerAppEnv.id

@description('Container Apps Environment name')
output containerAppEnvName string = containerAppEnv.name

@description('Container App resource ID')
output containerAppId string = containerApp.id

@description('Container App name')
output containerAppName string = containerApp.name

@description('Container App FQDN')
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn

@description('Container App URL')
output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'

@description('Container App ingress settings')
output containerAppIngress object = {
  fqdn: containerApp.properties.configuration.ingress.fqdn
  targetPort: containerApp.properties.configuration.ingress.targetPort
  external: containerApp.properties.configuration.ingress.external
}

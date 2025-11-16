// ============================================================================
// API Management Module for SRE Agent Hackathon Infrastructure
// ============================================================================
// This module creates the API Management infrastructure including:
// - API Management service with consumption tier for cost optimization
// - API configuration with operations for CRUD functionality
// - Application Insights integration for monitoring and diagnostics
// - Complete API operation definitions with proper responses
// ============================================================================

targetScope = 'resourceGroup'

import { ApiManagementConfig, NamingConfig, ResourceTags } from './types.bicep'

// ============================================================================
// Parameters
// ============================================================================

@description('Resource location')
param location string

@description('API Management configuration settings')
param apiManagementConfig ApiManagementConfig

@description('Naming configuration')
param namingConfig NamingConfig

@description('Resource tags')
param tags ResourceTags

@description('Container App URL for backend service')
param containerAppUrl string

@description('Application Insights resource ID')
param appInsightsId string

@description('Application Insights name')
param appInsightsName string

@description('Application Insights instrumentation key')
@secure()
param appInsightsInstrumentationKey string

// ============================================================================
// Variables
// ============================================================================

var apimName = '${namingConfig.namingPrefix}-apim-${namingConfig.uniqueSuffix}'

// ============================================================================
// Resources
// ============================================================================

// API Management Service
resource apim 'Microsoft.ApiManagement/service@2023-09-01-preview' = {
  name: apimName
  location: location
  tags: tags
  sku: {
    name: apiManagementConfig.skuName
    capacity: apiManagementConfig.skuCapacity
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publisherEmail: apiManagementConfig.publisherEmail
    publisherName: apiManagementConfig.publisherName
    notificationSenderEmail: apiManagementConfig.publisherEmail
    // Custom properties are only supported in non-Consumption tiers
    customProperties: apiManagementConfig.skuName == 'Consumption' ? {} : {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'False'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'False'
    }
  }
}

// API Management Logger for Application Insights
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2023-09-01-preview' = {
  parent: apim
  name: appInsightsName
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
    isBuffered: true
    resourceId: appInsightsId
  }
}

// API Management Diagnostic Settings
resource apimDiagnostics 'Microsoft.ApiManagement/service/diagnostics@2023-09-01-preview' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    loggerId: apimLogger.id
    alwaysLog: 'allErrors'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: {
        dataMasking: {
          queryParams: [
            {
              value: '*'
              mode: 'Hide'
            }
          ]
        }
      }
      response: {
        dataMasking: {
          queryParams: [
            {
              value: '*'
              mode: 'Hide'
            }
          ]
        }
      }
    }
    backend: {
      request: {
        dataMasking: {
          queryParams: [
            {
              value: '*'
              mode: 'Hide'
            }
          ]
        }
      }
      response: {
        dataMasking: {
          queryParams: [
            {
              value: '*'
              mode: 'Hide'
            }
          ]
        }
      }
    }
  }
}

// API in API Management
resource apimApi 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  parent: apim
  name: 'workshop-api'
  properties: {
    displayName: apiManagementConfig.apiDisplayName
    description: apiManagementConfig.apiDescription
    path: apiManagementConfig.apiPathPrefix
    protocols: [
      'https'
    ]
    serviceUrl: containerAppUrl
    subscriptionRequired: true
  }
}

// API-level diagnostic settings to ensure request telemetry is sent to Application Insights
resource apimApiDiagnostics 'Microsoft.ApiManagement/service/apis/diagnostics@2023-09-01-preview' = {
  parent: apimApi
  name: 'applicationinsights'
  properties: {
    loggerId: apimLogger.id
    alwaysLog: 'allErrors'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    verbosity: 'information'
    logClientIp: true
    httpCorrelationProtocol: 'W3C'
  }
}

// Health check endpoint
resource apimHealthOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'health-check'
  properties: {
    displayName: 'Health Check'
    method: 'GET'
    urlTemplate: '/health'
    description: 'Check if the API is running and healthy'
    responses: [
      {
        statusCode: 200
        description: 'API is healthy'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

// Get root endpoint
resource apimRootOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'get-root'
  properties: {
    displayName: 'Get Root'
    method: 'GET'
    urlTemplate: '/'
    description: 'Get API information and available endpoints'
    responses: [
      {
        statusCode: 200
        description: 'API information'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

// List all items
resource apimListItemsOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'list-items'
  properties: {
    displayName: 'List Items'
    method: 'GET'
    urlTemplate: '/items'
    description: 'Get all items from the database'
    responses: [
      {
        statusCode: 200
        description: 'List of items'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

// Create new item
resource apimCreateItemOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'create-item'
  properties: {
    displayName: 'Create Item'
    method: 'POST'
    urlTemplate: '/items'
    description: 'Create a new item in the database'
    request: {
      representations: [
        {
          contentType: 'application/json'
        }
      ]
    }
    responses: [
      {
        statusCode: 201
        description: 'Item created successfully'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
      {
        statusCode: 400
        description: 'Invalid request'
      }
    ]
  }
}

// Get item by ID
resource apimGetItemOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'get-item'
  properties: {
    displayName: 'Get Item'
    method: 'GET'
    urlTemplate: '/items/{id}'
    description: 'Get a specific item by ID'
    templateParameters: [
      {
        name: 'id'
        type: 'integer'
        required: true
        description: 'Item ID'
      }
    ]
    responses: [
      {
        statusCode: 200
        description: 'Item details'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
      {
        statusCode: 404
        description: 'Item not found'
      }
    ]
  }
}

// Update item by ID
resource apimUpdateItemOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'update-item'
  properties: {
    displayName: 'Update Item'
    method: 'PUT'
    urlTemplate: '/items/{id}'
    description: 'Update an existing item'
    templateParameters: [
      {
        name: 'id'
        type: 'integer'
        required: true
        description: 'Item ID'
      }
    ]
    request: {
      representations: [
        {
          contentType: 'application/json'
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        description: 'Item updated successfully'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
      {
        statusCode: 404
        description: 'Item not found'
      }
    ]
  }
}

// Delete item by ID
resource apimDeleteItemOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'delete-item'
  properties: {
    displayName: 'Delete Item'
    method: 'DELETE'
    urlTemplate: '/items/{id}'
    description: 'Delete an existing item'
    templateParameters: [
      {
        name: 'id'
        type: 'integer'
        required: true
        description: 'Item ID'
      }
    ]
    responses: [
      {
        statusCode: 204
        description: 'Item deleted successfully'
      }
      {
        statusCode: 404
        description: 'Item not found'
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('API Management service resource ID')
output apimId string = apim.id

@description('API Management service name')
output apimName string = apim.name

@description('API Management gateway URL')
output apimGatewayUrl string = apim.properties.gatewayUrl

@description('API Management developer portal URL')
output apimPortalUrl string = apiManagementConfig.skuName == 'Consumption' ? '' : apim.properties.developerPortalUrl

@description('API Management management URL') 
output apimManagementUrl string = apiManagementConfig.skuName == 'Consumption' ? '' : apim.properties.managementApiUrl

@description('API resource ID')
output apiId string = apimApi.id

@description('API name')
output apiName string = apimApi.name

@description('Complete API URL for testing')
output apiUrl string = '${apim.properties.gatewayUrl}/${apiManagementConfig.apiPathPrefix}'

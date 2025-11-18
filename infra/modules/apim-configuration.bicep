// ============================================================================
// API Management Configuration Module (Phase 2)
// ============================================================================
// This module configures APIs and backends on an existing APIM service.
// The APIM service itself is deployed in Phase 1.
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// Parameters
// ============================================================================

@description('Container App URL for backend service')
param containerAppUrl string

@description('Existing APIM service name')
param apimName string

@description('API Management configuration settings')
param apiManagementConfig object

@description('Application Insights name for logger reference')
param appInsightsName string

// ============================================================================
// Resources
// ============================================================================

// Reference existing APIM service
resource apim 'Microsoft.ApiManagement/service@2023-09-01-preview' existing = {
  name: apimName
}

// Reference existing Application Insights logger (created in Phase 1)
resource apimLogger 'Microsoft.ApiManagement/service/loggers@2023-09-01-preview' existing = {
  parent: apim
  name: appInsightsName
}

// API Backend
resource apimBackend 'Microsoft.ApiManagement/service/backends@2023-09-01-preview' = {
  parent: apim
  name: 'workshop-api-backend'
  properties: {
    description: 'Workshop API Container App Backend'
    url: containerAppUrl
    protocol: 'http'
    resourceId: containerAppUrl
  }
}

// API Definition
resource apimApi 'Microsoft.ApiManagement/service/apis@2023-09-01-preview' = {
  parent: apim
  name: 'workshop-api'
  properties: {
    displayName: apiManagementConfig.apiDisplayName
    description: apiManagementConfig.apiDescription
    path: apiManagementConfig.apiPathPrefix
    protocols: ['https']
    serviceUrl: containerAppUrl
    subscriptionRequired: true
  }
}

// API-level diagnostic settings to send request telemetry to Application Insights  
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
    metrics: true
  }
}

// API Policy to set backend
resource apimApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-09-01-preview' = {
  parent: apimApi
  name: 'policy'
  properties: {
    value: '''
<policies>
  <inbound>
    <base />
    <set-backend-service backend-id="workshop-api-backend" />
  </inbound>
  <backend>
    <base />
  </backend>
  <outbound>
    <base />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
'''
  }
}

// Health Check Operation
resource healthOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'health-check'
  properties: {
    displayName: 'Health Check'
    method: 'GET'
    urlTemplate: '/health'
    description: 'Returns the health status of the API'
    responses: [
      {
        statusCode: 200
        description: 'Health check successful'
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
resource rootOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
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
resource listItemsOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'list-items'
  properties: {
    displayName: 'List Items'
    method: 'GET'
    urlTemplate: '/api/items'
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
resource createItemOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'create-item'
  properties: {
    displayName: 'Create Item'
    method: 'POST'
    urlTemplate: '/api/items'
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
resource getItemOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'get-item'
  properties: {
    displayName: 'Get Item'
    method: 'GET'
    urlTemplate: '/api/items/{id}'
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
resource updateItemOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'update-item'
  properties: {
    displayName: 'Update Item'
    method: 'PUT'
    urlTemplate: '/api/items/{id}'
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
resource deleteItemOperation 'Microsoft.ApiManagement/service/apis/operations@2023-09-01-preview' = {
  parent: apimApi
  name: 'delete-item'
  properties: {
    displayName: 'Delete Item'
    method: 'DELETE'
    urlTemplate: '/api/items/{id}'
    description: 'Delete an item by ID'
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

@description('API ID')
output apiId string = apimApi.id

@description('API name')
output apiName string = apimApi.name

@description('API URL')
output apiUrl string = '${apim.properties.gatewayUrl}/${apiManagementConfig.apiPathPrefix}'

@description('Backend ID')
output backendId string = apimBackend.id

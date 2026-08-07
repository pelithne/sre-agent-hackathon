// ============================================================================
// Networking Module for SRE Agent Hackathon Infrastructure
// ============================================================================
// This module creates the virtual network infrastructure including:
// - Virtual Network with multiple subnets
// - Subnet configurations for Container Apps, PostgreSQL, and APIM
// - Private DNS zones for secure database communication
// ============================================================================

targetScope = 'resourceGroup'

import { NetworkConfig, NamingConfig, ResourceTags } from './types.bicep'

// ============================================================================
// Parameters
// ============================================================================

@description('Resource location')
param location string

@description('Network configuration settings')
param networkConfig NetworkConfig

@description('Naming configuration')
param namingConfig NamingConfig

@description('Resource tags')
param tags ResourceTags

// ============================================================================
// Variables
// ============================================================================

var vnetName = '${namingConfig.namingPrefix}-vnet'

// ============================================================================
// Resources
// ============================================================================

// Virtual Network with subnets
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        networkConfig.vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'container-apps-subnet'
        properties: {
          addressPrefix: networkConfig.containerAppsSubnetPrefix
          delegations: [
            {
              name: 'Microsoft.App.environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'postgres-subnet'
        properties: {
          addressPrefix: networkConfig.postgresSubnetPrefix
          delegations: [
            {
              name: 'Microsoft.DBforPostgreSQL.flexibleServers'
              properties: {
                serviceName: 'Microsoft.DBforPostgreSQL/flexibleServers'
              }
            }
          ]
        }
      }
      {
        name: 'apim-subnet'
        properties: {
          addressPrefix: networkConfig.apimSubnetPrefix
        }
      }
    ]
  }
}

// Private DNS zone for PostgreSQL
resource postgresDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: '${namingConfig.baseName}.postgres.database.azure.com'
  location: 'global'
  tags: tags
}

// Link private DNS zone to virtual network
resource postgresDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: postgresDnsZone
  name: '${namingConfig.baseName}-postgres-dns-link'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('Virtual network resource ID')
output vnetId string = vnet.id

@description('Virtual network name')
output vnetName string = vnet.name

@description('Container Apps subnet ID')
output containerAppsSubnetId string = vnet.properties.subnets[0].id

@description('PostgreSQL subnet ID')
output postgresSubnetId string = vnet.properties.subnets[1].id

@description('API Management subnet ID')
output apimSubnetId string = vnet.properties.subnets[2].id

@description('PostgreSQL private DNS zone ID')
output postgresDnsZoneId string = postgresDnsZone.id

@description('PostgreSQL private DNS zone name')
output postgresDnsZoneName string = postgresDnsZone.name

@description('All subnet IDs grouped by purpose')
output subnetIds object = {
  containerApps: vnet.properties.subnets[0].id
  postgres: vnet.properties.subnets[1].id
  apim: vnet.properties.subnets[2].id
}

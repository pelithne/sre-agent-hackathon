// ============================================================================
// Database Module for SRE Agent Hackathon Infrastructure
// ============================================================================
// This module creates the PostgreSQL database infrastructure including:
// - PostgreSQL Flexible Server with secure networking
// - Database creation with proper charset and collation
// - Firewall rules for Azure service access
// - Private DNS integration for secure communication
// ============================================================================

targetScope = 'resourceGroup'

import { DatabaseConfig, NamingConfig, ResourceTags } from './types.bicep'

// ============================================================================
// Parameters
// ============================================================================

@description('Resource location')
param location string

@description('Database configuration settings')
param databaseConfig DatabaseConfig

@description('Naming configuration')
param namingConfig NamingConfig

@description('Resource tags')
param tags ResourceTags

@description('PostgreSQL subnet resource ID')
param postgresSubnetId string

@description('PostgreSQL private DNS zone resource ID')
param postgresDnsZoneId string

// ============================================================================
// Variables
// ============================================================================

var postgresServerName = '${namingConfig.namingPrefix}-psql-${namingConfig.uniqueSuffix}'

// ============================================================================
// Resources
// ============================================================================

// PostgreSQL Flexible Server
resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2022-12-01' = {
  name: postgresServerName
  location: location
  tags: tags
  sku: {
    name: databaseConfig.sku
    tier: 'Burstable'
  }
  properties: {
    administratorLogin: databaseConfig.adminUsername
    administratorLoginPassword: databaseConfig.adminPassword
    version: '16'
    storage: {
      storageSizeGB: databaseConfig.storageSizeGB
    }
    backup: {
      backupRetentionDays: databaseConfig.backupRetentionDays
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: databaseConfig.highAvailability
    }
    network: {
      delegatedSubnetResourceId: postgresSubnetId
      privateDnsZoneArmResourceId: postgresDnsZoneId
    }
    authConfig: {
      activeDirectoryAuth: 'Disabled'
      passwordAuth: 'Enabled'
    }
  }
}

// PostgreSQL Database
resource postgresDatabase 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2022-12-01' = {
  parent: postgresServer
  name: databaseConfig.databaseName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

// PostgreSQL Firewall Rule to allow Azure services
resource postgresFirewallRule 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2022-12-01' = {
  parent: postgresServer
  name: 'AllowAllAzureServicesAndResourcesWithinAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// ============================================================================
// Outputs
// ============================================================================

@description('PostgreSQL server resource ID')
output postgresServerId string = postgresServer.id

@description('PostgreSQL server name')
output postgresServerName string = postgresServer.name

@description('PostgreSQL server FQDN')
output postgresServerFqdn string = postgresServer.properties.fullyQualifiedDomainName

@description('PostgreSQL database name')
output postgresDatabaseName string = postgresDatabase.name

@description('PostgreSQL connection string template (without password)')
output postgresConnectionStringTemplate string = 'postgresql://${databaseConfig.adminUsername}:<password>@${postgresServer.properties.fullyQualifiedDomainName}:5432/${databaseConfig.databaseName}?sslmode=require'

@description('PostgreSQL admin username')
output postgresAdminUsername string = databaseConfig.adminUsername

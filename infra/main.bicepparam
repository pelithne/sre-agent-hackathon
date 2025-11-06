// ============================================================================
// Azure SRE Agent Hackathon - Parameters File
// ============================================================================
// This file contains the parameters for deploying the infrastructure
// ============================================================================

using './main.bicep'

// Environment configuration
param environmentName = 'dev'
param baseName = 'sreagent'

// PostgreSQL configuration
param postgresAdminUsername = 'workshopadmin'

// Container image configuration
// Default: Placeholder hello-world image (listens on port 80)
// To use custom API: '<your-acr>.azurecr.io/workshop-api:latest'
param containerImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// NOTE: In production, use Azure Key Vault to store secrets
// For the workshop, you'll provide this via command line:
// az deployment group create --parameters postgresAdminPassword='YourSecurePassword123!'
// param postgresAdminPassword = readEnvironmentVariable('POSTGRES_PASSWORD')

// Tags
param tags = {
  Environment: 'Development'
  Project: 'SRE-Agent-Hackathon'
  ManagedBy: 'Bicep'
  Workshop: 'true'
}

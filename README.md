# SRE Agent Hackathon Workshop

Welcome to the SRE Agent Hackathon! This hands-on workshop teaches Site Reliability Engineering (SRE) principles by building and deploying a complete cloud-native application on Azure.

## 🎯 What You'll Learn

- Deploy infrastructure using Bicep Infrastructure as Code
- Use Azure SRE Agent to diagnose and resolve application issues
- Set up monitoring and alerting with Azure Monitor
- Perform incident investigations and create RCA reports
- Implement auto-remediation and advanced SRE practices

## 🏗️ Architecture Overview

This workshop deploys a complete application stack including:

- **REST API**: Python FastAPI service for managing items
- **Database**: PostgreSQL Flexible Server with private networking
- **API Gateway**: Azure API Management for security and routing
- **Container Platform**: Azure Container Apps with auto-scaling
- **Monitoring**: Application Insights and Log Analytics
- **Infrastructure**: Virtual networking, managed identity, and secrets

## 🚀 Quick Start

### Prerequisites
- Azure Subscription with contributor access
- Azure CLI (version 2.50.0 or later)
- Git and Visual Studio Code
- Azure SRE Agent access

### Deploy in Two Phases

```bash
# Phase 1: Deploy core infrastructure
cd infra
./deploy-phase1.sh

# Phase 2: Build and deploy applications
cd ..
./build.sh
cd infra
./deploy-phase2.sh
```

## 📁 Repository Structure

```
├── infra/                      # Infrastructure as Code (Bicep templates)
├── src/api/                    # Sample REST API application
├── build.sh                    # Container image build script
└── README.md                   # This file
```

## 📚 Resources

- **Detailed Instructions**: [`infra/README.md`](infra/README.md)
- **Azure SRE Agent**: [Documentation](https://learn.microsoft.com/azure/sre-agent/)
- **SRE Best Practices**: [Microsoft SRE Resources](https://learn.microsoft.com/azure/site-reliability-engineering/)

---

**Ready to start? Check [`infra/README.md`](infra/README.md) for detailed deployment instructions!** 🚀
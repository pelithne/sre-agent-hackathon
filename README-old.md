# SRE Agent Hackathon Workshop# SRE Agent Hackathon Workshop



Welcome to the SRE Agent Hackathon! This repository contains everything you need to build and deploy a production-ready SRE monitoring and alerting system on Azure.Welcome to the SRE Agent Hackathon! This repository contains everything you need to build and deploy a production-ready SRE monitoring and alerting system on Azure.



## 🎯 Workshop Overview## 🎯 Workshop Overview



This hackathon teaches Site Reliability Engineering (SRE) principles by building a complete monitoring solution with:This hackathon teaches Site Reliability Engineering (SRE) principles by building a complete monitoring solution with:

- **API Service**: REST API for managing alerts and metrics

- **Agent Service**: Background monitoring and alerting agent  In this workshop, you'll build a complete cloud-native application on Azure and learn how to use Azure SRE Agent to diagnose issues, investigate incidents, and perform root cause analysis. You'll gain practical experience with modern Site Reliability Engineering practices in Azure.

- **Infrastructure**: Production-ready Azure deployment

- **Observability**: Comprehensive monitoring and logging## Prerequisites



## 🚀 Quick StartBefore starting the workshop, ensure you have:



### Option 1: Automated Deployment (Recommended)### Required

- **Azure Subscription** with contributor access

```bash- **Azure CLI** (version 2.50.0 or later) - [Install](https://docs.microsoft.com/cli/azure/install-azure-cli)

# 1. Deploy infrastructure- **Git** - [Install](https://git-scm.com/downloads)

cd infra/- **Visual Studio Code** (recommended) - [Install](https://code.visualstudio.com/)

./deploy-phase1.sh- **Azure SRE Agent** access - [Setup Guide](https://learn.microsoft.com/azure/sre-agent/)



# 2. Build your container image> **Note:** Docker is NOT required. Container images are built using Azure Container Registry build tasks.

cd ../

./build.sh### Recommended

- **Bicep CLI** - [Install](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install)

# 3. Deploy applications  - Basic understanding of:

cd infra/  - REST APIs

./deploy-phase2.sh  - Containers and containerization concepts

```  - Azure fundamentals

  - SQL/PostgreSQL

### Option 2: Manual Steps

### Azure Services Knowledge

See detailed instructions in [`infra/README.md`](infra/README.md)Familiarity with these Azure services is helpful but not required:

- Azure API Management

## 📁 Repository Structure- Azure Container Apps

- Azure Database for PostgreSQL

```- Azure Monitor and Application Insights

├── README.md                    # This file - project overview

├── build.sh                     # Container build script (Phase 1.5)## Architecture

├── infra/                       # Infrastructure as Code

│   ├── README.md                # Detailed deployment guide```

│   ├── deploy-phase1.sh         # Infrastructure deployment script┌─────────────────────────────────────────────────────────────┐

│   ├── deploy-phase2.sh         # Application deployment script  │                         Internet                            │

│   ├── infrastructure.bicep     # Phase 1: Core infrastructure└────────────────────────┬────────────────────────────────────┘ 

│   ├── apps.bicep               # Phase 2: Container Apps                         │

│   ├── apim.bicep               # Optional: API Management                         ▼

│   └── modules/                 # Reusable Bicep modules              ┌──────────────────────┐

│       ├── types.bicep          # Shared type definitions              │   API Management     │

│       ├── networking.bicep     # Virtual Network & subnets              │  (Consumption Tier)  │

│       ├── monitoring.bicep     # Log Analytics & App Insights              └──────────┬───────────┘

│       ├── acr.bicep            # Container Registry                         │

│       ├── identity.bicep       # Managed Identity & RBAC                         ▼

│       ├── database.bicep       # PostgreSQL Flexible Server              ┌──────────────────────┐

│       └── containerApps.bicep  # Container Apps Environment              │   Container Apps     │

└── src/                         # Your application code goes here              │   Environment        │             ┌──────────────────────┐

    ├── api/                     # API service source code              │  ┌────────────────┐  │             │ Azure Monitor        │

    │   ├── Dockerfile           # Container build instructions              │  │  API Container │  │             │ Application Insights │

    │   └── ...                  # Your API application files              │  │  (Python/Node) │  │             │ Log Analytics        │  

    └── agent/                   # Agent service source code                │  └────────┬───────┘  │             └──────────────────────┘

        ├── Dockerfile           # Container build instructions              └───────────┼──────────┘             

        └── ...                  # Your agent application files                          │                        

```                          ▼

              ┌──────────────────────┐

## 🏗️ Architecture Overview              │   PostgreSQL         │

              │   Flexible Server    │

```mermaid              └──────────────────────┘

graph TB                         

    subgraph "Azure Subscription"    

        subgraph "Virtual Network (10.0.0.0/16)" ```

            subgraph "Container Apps Subnet (10.0.0.0/23)"

                CAE[Container Apps Environment]### Architecture Highlights

                API[API Container App]

                AGENT[Agent Container App]- **API Gateway Pattern**: API Management provides security, rate limiting, and API versioning

            end- **Container Orchestration**: Container Apps handles scaling, deployment, and lifecycle management

            - **Managed Database**: PostgreSQL Flexible Server provides automated backups and high availability

            subgraph "Database Subnet (10.0.2.0/24)"- **Observability**: Integrated monitoring with Application Insights and Azure Monitor

                PG[(PostgreSQL Flexible Server)]- **Security**: Managed identities for secure service-to-service authentication

            end

        end## Important: Environment Variable Management

        

        ACR[Azure Container Registry]This workshop includes a **persistent environment variable system** designed to handle shell timeouts and session interruptions common in cloud development environments.

        LAW[Log Analytics Workspace]

        AI[Application Insights]### Key Features

        MI[Managed Identity]- **Automatic persistence** of variables to `~/.workshop-env`

        - **Shell timeout resilience** (Azure Cloud Shell, Codespaces, SSH sessions)

        API --> PG- **Multi-session support** - resume work in new terminals

        AGENT --> PG- **Built-in verification** to ensure required variables are set

        API --> AI

        AGENT --> AI### Quick Start

        CAE --> LAW```bash

        MI --> ACR# Always start by loading the workshop environment

    endsource scripts/workshop-env.sh

    

    USER[Workshop Participants] --> API# Set variables with automatic persistence

    USER --> AGENTset_var "BASE_NAME" "srepk"

```

# Verify all required variables

## 🛠️ Two-Phase Deployment Strategyverify_vars

```

This workshop uses a **two-phase deployment** to solve the chicken-and-egg problem where Container Apps need images that can only be built after the Container Registry exists:

📖 **See [Environment Variables Guide](./docs/environment-variables.md) for complete documentation**

### ✅ Phase 1: Infrastructure

- Azure Container Registry (ACR)## Workshop Structure

- Virtual Network & subnets

- PostgreSQL Flexible Server  The workshop is divided into progressive parts:

- Log Analytics & Application Insights

- Managed Identity & RBAC### [Part 1: Setup & Deployment](./exercises/part1-setup.md) (60-90 minutes)

- Set up your development environment

### ✅ Phase 2: Applications  - Understand the Bicep templates

- Build & push container images to ACR- Deploy Azure infrastructure (APIM, Container Apps, PostgreSQL)

- Container Apps Environment- Test all API endpoints through APIM

- API & Agent Container Apps- Verify deployment and troubleshoot common issues

- Configuration & secrets

### [Part 2: SRE Agent Troubleshooting](./exercises/part2-troubleshooting.md) (60-90 minutes)

## 📊 What You'll Build- **Exercise 1**: API 500 errors - Database connectivity and VNet troubleshooting

- **Exercise 2**: High response times - Performance analysis and optimization

### API Service- **Exercise 3**: Container not starting - ACR pull issues and managed identity

- **Health checks**: `/health` endpoint for monitoring- **Exercise 4**: APIM timeout - Policy configuration and backend settings

- **Metrics API**: Expose application and business metrics- **Exercise 5**: Connection pool exhaustion - Load testing and pooling configuration

- **Alerts API**: Manage alert rules and notifications- **Exercise 6**: Missing environment variables - Secret management and configuration

- **Dashboard data**: Provide data for monitoring dashboards- **Exercise 7**: Regional outage - Resilience planning and service health

- **Advanced Challenge**: Multi-service failure requiring systematic diagnosis

### Agent Service

- **Metric collection**: Gather metrics from various sourcesEach exercise includes:

- **Alert evaluation**: Check thresholds and trigger alerts- Realistic failure scenario

- **Notification delivery**: Send alerts via email, SMS, webhooks- Step-by-step investigation with SRE Agent

- **Health monitoring**: Monitor API service and dependencies- Root cause identification

- Fix implementation and verification

### Infrastructure Features- Best practices and prevention strategies

- **High Availability**: Multi-zone deployment with auto-scaling

- **Security**: Private networking, managed identity, secrets management### [Part 3: Monitoring & Alerts](./exercises/part3-monitoring.md) (60-90 minutes)

- **Observability**: Comprehensive logging, metrics, and tracing- **Exercise 1**: Basic metric alerts - CPU, memory, storage thresholds

- **Cost Optimization**: Serverless Container Apps with consumption-based pricing- **Exercise 2**: Log-based alerts - Error rate and performance anomalies

- **Exercise 3**: Availability tests - Synthetic monitoring from multiple regions

## 🎓 Learning Objectives- **Exercise 4**: Monitoring dashboards - KQL queries and custom visualizations

- **Exercise 5**: Incident investigation - Using SRE Agent for alert triage

By the end of this workshop, you'll understand:- **Exercise 6**: RCA reports - Documenting incidents with SRE Agent assistance

- **Exercise 7**: SLO monitoring - Error budgets and burn rate tracking

1. **SRE Fundamentals**- **Exercise 8**: Alert fatigue management - Optimizing alert rules and runbooks

   - Service Level Objectives (SLOs)

   - Error budgets and reliability targets**Learning Objectives:**

   - Monitoring and alerting strategies- Configure comprehensive monitoring and alerting

- Use SRE Agent for incident investigation

2. **Cloud-Native Architecture**- Write effective RCA reports

   - Containerized microservices- Implement SLO-based monitoring

   - Serverless compute with Container Apps

   - Infrastructure as Code with Bicep### [Advanced Exercises](./exercises/advanced-exercises.md) (2-4 hours, optional)

- **Exercise 1**: Auto-remediation - Azure Automation runbooks and webhooks

3. **Azure DevOps Practices**- **Exercise 2**: Chaos engineering - Testing resilience with failure injection

   - Two-phase deployment strategy- **Exercise 3**: Multi-region resilience - DR planning and failover testing

   - Container registry automation- **Exercise 4**: Performance optimization - Caching, indexing, and profiling

   - Monitoring and observability- **Exercise 5**: Security incident investigation - Forensic analysis with SRE Agent

- **Exercise 6**: Cost optimization - Resource right-sizing and efficiency analysis

4. **Production Readiness**- **Exercise 7**: Custom metrics - Business KPIs and stakeholder dashboards

   - Security best practices

   - Network isolation**Learning Objectives:**

   - Secrets management- Implement production-grade SRE practices

   - High availability patterns- Build automated remediation workflows

- Validate system resilience through testing

## 🔧 Prerequisites- Optimize for performance and cost



- **Azure Subscription** with contributor access### [Cleanup](./docs/cleanup.md)

- **Azure CLI** installed and configured (`az login`)- Quick cleanup (delete resource group)

- **Docker** or container build tools- Selective cleanup (keep specific resources)

- **Your favorite IDE** for application development- Automated cleanup script

- **Basic knowledge** of REST APIs and containers- Cost considerations and verification



## 🧪 Testing Your Deployment## Additional Resources



After deployment, you can test your services:### Workshop Materials

- [Quick Deployment Script](./scripts/deploy.sh) - Automated deployment with validation

```bash- [Cleanup Guide](./docs/cleanup.md) - Resource cleanup automation and best practices

# Get API URL from deployment output- [FAQ](./docs/FAQ.md) - 40+ frequently asked questions and answers

API_URL=$(cat infra/deployment-info.json | jq -r '.apiUrl')- [Infrastructure Templates](./infra/) - Bicep templates and parameters



# Test health endpoint### Azure SRE Agent

curl $API_URL/health- [Azure SRE Agent Documentation](https://learn.microsoft.com/azure/sre-agent/)



# Test metrics endpoint (customize based on your API)### Azure Services

curl $API_URL/api/metrics- [Azure API Management](https://learn.microsoft.com/azure/api-management/)

- [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/)

# View logs in Azure- [Azure Database for PostgreSQL](https://learn.microsoft.com/azure/postgresql/)

az containerapp logs show \- [Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/)

  --name <CONTAINER_APP_NAME> \- [Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)

  --resource-group rg-sre-agent-hackathon

```### SRE Principles

- [Microsoft SRE Resources](https://learn.microsoft.com/azure/site-reliability-engineering/)

## 📚 Additional Resources- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)



- [Azure Container Apps Documentation](https://docs.microsoft.com/en-us/azure/container-apps/)

- [SRE Best Practices](https://sre.google/sre-book/table-of-contents/)## Learning Objectives

- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

- [PostgreSQL on Azure](https://docs.microsoft.com/en-us/azure/postgresql/)By the end of this workshop, you will be able to:



## 🤝 Need Help?✅ Deploy infrastructure using Bicep IaC  

✅ Use Azure SRE Agent to diagnose and resolve application issues  

- Check [`infra/README.md`](infra/README.md) for detailed deployment instructions✅ Set up monitoring and alerting with Azure Monitor  

- Review troubleshooting guides in the documentation✅ Perform incident investigations and create RCA reports  

- Ask questions during the workshop sessions✅ Implement auto-remediation and advanced SRE practices  

- Submit issues for bugs or improvements✅ Apply chaos engineering principles to improve resilience  



---

## Contributing

**Happy coding and have fun building your SRE monitoring system! 🎉**
Found an issue or want to improve the workshop? Contributions are welcome!

- Report bugs or issues via GitHub Issues
- Submit improvements via Pull Requests
- Share feedback and suggestions
- Add your own advanced exercises

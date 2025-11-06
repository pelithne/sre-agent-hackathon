# Azure SRE Agent Hackathon Workshop

Welcome to the Azure SRE Agent Hackathon! This hands-on workshop will teach you how to leverage Azure's SRE Agent to troubleshoot, monitor, and maintain cloud applications like a pro.

## 🎯 Workshop Overview

In this workshop, you'll build a complete cloud-native application on Azure and learn how to use Azure SRE Agent to diagnose issues, investigate incidents, and perform root cause analysis. You'll gain practical experience with modern Site Reliability Engineering practices in Azure.

### What You'll Build

A production-like architecture consisting of:
- **Azure API Management** (Consumption tier) - API gateway and management layer
- **Azure Container Apps** - Hosting a RESTful API application
- **Azure Database for PostgreSQL** - Data persistence layer
- **Azure Monitor** - Observability and alerting
- **Application Insights** - Application performance monitoring

### What You'll Learn

1. **Infrastructure as Code** - Deploy Azure resources using Bicep templates
2. **Application Deployment** - Containerize and deploy APIs to Azure Container Apps
3. **SRE Agent Troubleshooting** - Use AI-powered diagnostics to identify and resolve issues
4. **Incident Management** - Set up alerts, investigate incidents, and create RCA reports
5. **Advanced SRE Practices** - Auto-remediation, performance optimization, and chaos engineering

## 📋 Prerequisites

Before starting the workshop, ensure you have:

### Required
- **Azure Subscription** with contributor access
- **Azure CLI** (version 2.50.0 or later) - [Install](https://docs.microsoft.com/cli/azure/install-azure-cli)
- **Git** - [Install](https://git-scm.com/downloads)
- **Docker** - [Install](https://docs.docker.com/get-docker/)
- **Visual Studio Code** (recommended) - [Install](https://code.visualstudio.com/)
- **Azure SRE Agent** access - [Setup Guide](https://learn.microsoft.com/azure/sre-agent/)

### Recommended
- **Bicep CLI** - [Install](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install)
- Basic understanding of:
  - REST APIs
  - Containers and Docker
  - Azure fundamentals
  - SQL/PostgreSQL

### Azure Services Knowledge
Familiarity with these Azure services is helpful but not required:
- Azure API Management
- Azure Container Apps
- Azure Database for PostgreSQL
- Azure Monitor and Application Insights

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         Internet                             │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │   API Management     │
              │  (Developer Tier)    │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │   Container Apps     │
              │   Environment        │
              │  ┌────────────────┐  │
              │  │  API Container │  │
              │  │  (Python/Node) │  │
              │  └────────┬───────┘  │
              └───────────┼──────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │   PostgreSQL         │
              │   Flexible Server    │
              └──────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  Azure Monitor       │
              │  Application Insights│
              │  Log Analytics       │
              └──────────────────────┘
```

### Architecture Highlights

- **API Gateway Pattern**: API Management provides security, rate limiting, and API versioning
- **Container Orchestration**: Container Apps handles scaling, deployment, and lifecycle management
- **Managed Database**: PostgreSQL Flexible Server provides automated backups and high availability
- **Observability**: Integrated monitoring with Application Insights and Azure Monitor
- **Security**: Managed identities for secure service-to-service authentication

## 🚀 Workshop Structure

The workshop is divided into progressive parts:

### [Part 1: Setup & Deployment](./exercises/part1-setup.md) (60-90 minutes)
- Set up your development environment
- Understand the Bicep templates
- Deploy Azure infrastructure (APIM, Container Apps, PostgreSQL)
- Configure managed identity for ACR access
- Test all API endpoints through APIM
- Verify deployment and troubleshoot common issues

**Learning Objectives:**
- Deploy production-ready infrastructure using Bicep
- Configure Azure services for containerized applications
- Test end-to-end API functionality
- Understand Azure architecture patterns

### [Part 2: SRE Agent Troubleshooting](./exercises/part2-troubleshooting.md) (60-90 minutes)
- **Exercise 1**: API 500 errors - Database connectivity and VNet troubleshooting
- **Exercise 2**: High response times - Performance analysis and optimization
- **Exercise 3**: Container not starting - ACR pull issues and managed identity
- **Exercise 4**: APIM timeout - Policy configuration and backend settings
- **Exercise 5**: Connection pool exhaustion - Load testing and pooling configuration
- **Exercise 6**: Missing environment variables - Secret management and configuration
- **Exercise 7**: Regional outage - Resilience planning and service health
- **Advanced Challenge**: Multi-service failure requiring systematic diagnosis

Each exercise includes:
- Realistic failure scenario
- Step-by-step investigation with SRE Agent
- Root cause identification
- Fix implementation and verification
- Best practices and prevention strategies

### [Part 3: Monitoring & Alerts](./exercises/part3-monitoring.md) (60-90 minutes)
- **Exercise 1**: Basic metric alerts - CPU, memory, storage thresholds
- **Exercise 2**: Log-based alerts - Error rate and performance anomalies
- **Exercise 3**: Availability tests - Synthetic monitoring from multiple regions
- **Exercise 4**: Monitoring dashboards - KQL queries and custom visualizations
- **Exercise 5**: Incident investigation - Using SRE Agent for alert triage
- **Exercise 6**: RCA reports - Documenting incidents with SRE Agent assistance
- **Exercise 7**: SLO monitoring - Error budgets and burn rate tracking
- **Exercise 8**: Alert fatigue management - Optimizing alert rules and runbooks

**Learning Objectives:**
- Configure comprehensive monitoring and alerting
- Use SRE Agent for incident investigation
- Write effective RCA reports
- Implement SLO-based monitoring

### [Advanced Exercises](./exercises/advanced-exercises.md) (2-4 hours, optional)
- **Exercise 1**: Auto-remediation - Azure Automation runbooks and webhooks
- **Exercise 2**: Chaos engineering - Testing resilience with failure injection
- **Exercise 3**: Multi-region resilience - DR planning and failover testing
- **Exercise 4**: Performance optimization - Caching, indexing, and profiling
- **Exercise 5**: Security incident investigation - Forensic analysis with SRE Agent
- **Exercise 6**: Cost optimization - Resource right-sizing and efficiency analysis
- **Exercise 7**: Custom metrics - Business KPIs and stakeholder dashboards

**Learning Objectives:**
- Implement production-grade SRE practices
- Build automated remediation workflows
- Validate system resilience through testing
- Optimize for performance and cost

### [Cleanup](./docs/cleanup.md)
- Quick cleanup (delete resource group)
- Selective cleanup (keep specific resources)
- Automated cleanup script
- Cost considerations and verification

## 📚 Additional Resources

### Workshop Materials
- [Quick Deployment Script](./scripts/deploy.sh) - Automated deployment with validation
- [Cleanup Guide](./docs/cleanup.md) - Resource cleanup automation and best practices
- [FAQ](./docs/FAQ.md) - 40+ frequently asked questions and answers
- [Infrastructure Templates](./infra/) - Bicep templates and parameters

### Azure SRE Agent
- [Azure SRE Agent Documentation](https://learn.microsoft.com/azure/sre-agent/)

### Azure Services
- [Azure API Management](https://learn.microsoft.com/azure/api-management/)
- [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/)
- [Azure Database for PostgreSQL](https://learn.microsoft.com/azure/postgresql/)
- [Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/)
- [Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)

### SRE Principles
- [Google SRE Book](https://sre.google/books/)
- [Microsoft SRE Resources](https://learn.microsoft.com/azure/site-reliability-engineering/)
- [Azure Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)

## ⏱️ Estimated Time

- **Part 1** (Setup & Deployment): 60-90 minutes
- **Part 2** (SRE Agent Troubleshooting): 60-90 minutes
- **Part 3** (Monitoring & Alerts): 60-90 minutes
- **Advanced Exercises** (Optional): 120-240 minutes
- **Total Core Workshop**: 3-4.5 hours
- **Total with Advanced**: 5-8 hours

The workshop can be completed in one session or split across multiple sessions.

## 🎓 Learning Objectives

By the end of this workshop, you will be able to:

✅ Deploy production-ready infrastructure using Bicep IaC  
✅ Containerize and deploy applications to Azure Container Apps  
✅ Configure API Management to expose and secure APIs  
✅ Use Azure SRE Agent to diagnose and resolve application issues  
✅ Set up comprehensive monitoring and alerting with Azure Monitor  
✅ Perform incident investigations and create RCA reports  
✅ Implement auto-remediation and advanced SRE practices  
✅ Apply chaos engineering principles to improve resilience  

## 💡 Tips for Success

1. **Follow the parts in order** - Each builds on the previous
2. **Take your time with exercises** - Understanding is more important than speed
3. **Use SRE Agent actively** - Practice asking good questions
4. **Experiment freely** - The workshop environment is yours to explore
5. **Document your learnings** - Keep notes of insights and solutions
6. **Clean up resources** - Use the cleanup guide to avoid unexpected costs
7. **Share your experience** - Contribute improvements via pull requests

## 📞 Support

If you encounter issues during the workshop:

1. Check the [FAQ](./docs/FAQ.md) - 40+ common questions answered
2. Review the [Cleanup Guide](./docs/cleanup.md) - For resource cleanup issues
3. Check exercise troubleshooting sections - Each part includes common issues
4. Create an issue in this repository
5. Use Azure SRE Agent - Ask it for help with Azure-specific issues

## 🤝 Contributing

Found an issue or want to improve the workshop? Contributions are welcome!

- Report bugs or issues via GitHub Issues
- Submit improvements via Pull Requests
- Share feedback and suggestions
- Add your own advanced exercises

---

**Ready to become an Azure SRE expert? Let's get started with [Part 1: Setup & Deployment](./exercises/part1-setup.md)!** 🚀

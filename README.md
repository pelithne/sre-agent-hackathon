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
- **GitHub Copilot** for enhanced coding experience
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

The workshop is divided into progressive modules:

### [Module 1: Environment Setup](./docs/01-setup.md)
- Set up your development environment
- Clone the workshop repository
- Authenticate with Azure
- Verify prerequisites

### [Module 2: Infrastructure Deployment](./docs/02-infrastructure.md)
- Understand the Bicep templates
- Deploy Azure resources
- Configure networking and security
- Verify deployment

### [Module 3: Application Deployment](./docs/03-application.md)
- Build the sample API
- Create container images
- Deploy to Container Apps
- Configure API Management
- Test the end-to-end flow

### [Module 4: SRE Agent Basics](./docs/04-sre-agent-basics.md)
- Introduction to Azure SRE Agent
- Configure SRE Agent access
- Basic troubleshooting workflows
- Understanding SRE Agent capabilities

### [Module 5: Troubleshooting with SRE Agent](./docs/05-troubleshooting.md)
- **Exercise 5.1**: Database connectivity issues
- **Exercise 5.2**: Performance degradation
- **Exercise 5.3**: Configuration errors
- **Exercise 5.4**: API Management policy problems
- **Exercise 5.5**: Container app failures

Each exercise includes:
- Problem scenario
- How to introduce the issue
- Symptoms to observe
- Using SRE Agent for diagnosis
- Resolution steps

### [Module 6: Monitoring & Incident Management](./docs/06-monitoring.md)
- Configure Azure Monitor alerts
- Set up action groups and notifications
- Connect SRE Agent to alert pipeline
- Perform incident investigation
- Create Root Cause Analysis (RCA) reports
- Implement post-incident reviews

### [Module 7: Advanced Topics](./docs/07-advanced.md)
- **Exercise 7.1**: Auto-remediation scenarios
- **Exercise 7.2**: Multi-service debugging
- **Exercise 7.3**: Performance optimization
- **Exercise 7.4**: Security incident investigation
- **Exercise 7.5**: Chaos engineering with SRE Agent
- **Exercise 7.6**: Cost optimization recommendations
- **Exercise 7.7**: Implementing SRE best practices

### [Module 8: Cleanup](./docs/08-cleanup.md)
- Remove workshop resources
- Prevent unexpected costs
- Optional: preserve learnings

## 📚 Additional Resources

- [Workshop Scripts](./scripts/) - Helper scripts for deployment and testing
- [Troubleshooting Guide](./docs/troubleshooting.md) - Common issues and solutions
- [FAQ](./docs/faq.md) - Frequently asked questions
- [Additional Exercises](./docs/bonus-exercises.md) - Optional challenges

## 🤝 Contributing

Found an issue or want to improve the workshop? Contributions are welcome!
Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for details.

## 📖 Learning Resources

### Azure SRE Agent
- [Azure SRE Agent Documentation](https://learn.microsoft.com/azure/sre-agent/)
- [SRE Agent Best Practices](https://learn.microsoft.com/azure/sre-agent/best-practices)
- [Incident Response with SRE Agent](https://learn.microsoft.com/azure/sre-agent/incident-response)

### Azure Services
- [Azure API Management](https://learn.microsoft.com/azure/api-management/)
- [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/)
- [Azure Database for PostgreSQL](https://learn.microsoft.com/azure/postgresql/)
- [Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/)

### SRE Principles
- [Google SRE Book](https://sre.google/books/)
- [Microsoft SRE Resources](https://learn.microsoft.com/azure/site-reliability-engineering/)

## ⏱️ Estimated Time

- **Module 1-3** (Setup & Deployment): 60-90 minutes
- **Module 4** (SRE Agent Basics): 30 minutes
- **Module 5** (Troubleshooting): 90-120 minutes
- **Module 6** (Monitoring): 60 minutes
- **Module 7** (Advanced): 60-120 minutes (optional)
- **Total**: 4-7 hours (can be split across multiple sessions)

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

1. **Follow the modules in order** - Each builds on the previous
2. **Take your time with exercises** - Understanding is more important than speed
3. **Experiment freely** - The workshop environment is yours to explore
4. **Ask questions** - Use GitHub issues or discussions
5. **Document your learnings** - Keep notes of insights and solutions
6. **Clean up resources** - Don't forget Module 8 to avoid unexpected costs

## 📞 Support

If you encounter issues during the workshop:

1. Check the [Troubleshooting Guide](./docs/troubleshooting.md)
2. Review the [FAQ](./docs/faq.md)
3. Create an issue in this repository
4. Reach out to workshop facilitators

## 📄 License

This workshop is provided under the MIT License. See [LICENSE](./LICENSE) for details.

---

**Ready to become an Azure SRE expert? Let's get started with [Module 1: Environment Setup](./docs/01-setup.md)!** 🚀

# SRE Agent Hackathon Workshop

Master the Azure SRE Agent through hands-on incident response and troubleshooting! This workshop provides a realistic cloud environment where you'll learn to diagnose issues, handle alerts, and implement SRE best practices using Microsoft's intelligent SRE Agent.

## What You'll Learn

**Primary Focus - SRE Agent Mastery:**
- **Incident Detection**: Use SRE Agent to identify and triage application issues
- **Root Cause Analysis**: Leverage AI-powered diagnostics to find problem sources
- **Alert Management**: Configure intelligent alerting and response workflows
- **Automated Remediation**: Implement self-healing systems with SRE Agent automation
- **Performance Investigation**: Analyze application bottlenecks and reliability patterns
- **RCA Documentation**: Generate comprehensive incident reports and learnings

**Supporting Skills:**
- Deploy a realistic multi-tier application as your troubleshooting playground
- Set up comprehensive monitoring and observability with Azure Monitor

## Workshop Environment

The SRE Agent needs a realistic application to troubleshoot! We provide a complete cloud-native stack that serves as your **troubleshooting playground**:

- **REST API**: Python FastAPI service (your primary troubleshooting target)
- **Database**: PostgreSQL with potential connection and performance issues
- **API Gateway**: Azure API Management for security and routing complexity
- **Container Platform**: Azure Container Apps with scaling and resource challenges
- **Monitoring Stack**: Application Insights and Log Analytics for SRE Agent data sources

*The application is intentionally complex enough to generate realistic incidents for SRE Agent practice.*

## Quick Start

### Prerequisites
- Azure Subscription with contributor access
- **Azure SRE Agent access** (primary workshop tool)
- Azure CLI (version 2.50.0 or later)
- Git and Visual Studio Code

### 1. Deploy Your Troubleshooting Environment

```bash
# Deploy the application stack for SRE Agent practice
cd infra
./deploy-phase1.sh

# Build and deploy the application components
cd ..
./build.sh
cd infra
./deploy-phase2.sh
```

### 2. Start Your SRE Journey
Once deployed, you'll use the **Azure SRE Agent** to:
- Investigate pre-configured scenarios and intentional issues
- Practice incident response workflows
- Learn automated diagnostics and remediation
- Master alert management and escalation

## Repository Structure

```
├── infra/                      # Infrastructure as Code (Bicep templates)
├── src/api/                    # Sample REST API application
├── build.sh                    # Container image build script
└── README.md                   # This file
```

## Resources

- **Workshop Guide**: [`infra/README.md`](infra/README.md) - Environment setup instructions
- **Azure SRE Agent**: [Official Documentation](https://learn.microsoft.com/azure/sre-agent/)
- **SRE Fundamentals**: [Microsoft SRE Resources](https://learn.microsoft.com/azure/site-reliability-engineering/)
- **Incident Response**: [SRE Agent Best Practices](https://learn.microsoft.com/azure/sre-agent/)

---

**Ready to become an SRE Agent expert? Deploy your environment and start troubleshooting!**
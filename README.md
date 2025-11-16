# SRE Agent Hackathon Workshop

Master the Azure SRE Agent through hands-on incident response and troubleshooting. This workshop provides a realistic cloud environment where you'll learn to diagnose issues, handle alerts, and implement SRE best practices using Microsoft's intelligent SRE Agent.

## What You'll Learn

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

The SRE Agent needs a realistic application to troubleshoot. We provide a complete cloud-native stack that serves as your **troubleshooting playground**:

- **REST API**: Python FastAPI service (your primary troubleshooting target)
- **Database**: PostgreSQL with potential connection and performance issues
- **API Gateway**: Azure API Management for security and routing complexity
- **Container Platform**: Azure Container Apps with scaling and resource challenges
- **Monitoring Stack**: Application Insights and Log Analytics for SRE Agent data sources

*The application is intentionally complex enough to generate realistic incidents for SRE Agent practice.*

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                               │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │   API Management     │
                  │  (APIM Gateway)      │
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │   Container App      │
                  │   (FastAPI)          │
                  └──────────┬───────────┘
                             │
                             ▼
                  ┌──────────────────────┐
                  │  PostgreSQL          │
                  │  Flexible Server     │
                  └──────────────────────┘

         ┌─────────────────────────────────────┐
         │   Application Insights              │
         │   (Telemetry & Monitoring)          │
         │                                     │
         │   • APIM Request Logs               │
         │   • Container App Traces            │
         │   • Database Dependencies           │
         └─────────────────────────────────────┘
```

## Getting Started

Ready to master the Azure SRE Agent? Follow the workshop exercises in order:

1. **[Part 1: Setup](exercises/part1-setup.md)** - Deploy your troubleshooting environment
2. **[Part 2: Troubleshooting](exercises/part2-troubleshooting.md)** - Learn SRE Agent basics
3. **[Part 3: Monitoring](exercises/part3-monitoring.md)** - Advanced SRE practices

Each exercise builds on the previous one and includes hands-on scenarios for practicing real-world SRE skills.

## Repository Structure

```
├── exercises/                  # Workshop exercises and setup guides
├── infra/                      # Infrastructure as Code (Bicep templates)
├── src/api/                    # Sample REST API application
├── build.sh                    # Container image build script
└── README.md                   # This file
```
# Workshop FAQ

## Frequently Asked Questions

### General Questions

**Q: How long does this workshop take to complete?**

A: The workshop is designed to be flexible:
- **Core Workshop** (Parts 1-3): 3-4 hours
- **Advanced Exercises**: Additional 2-4 hours
- **Full Workshop**: 5-8 hours total

You can complete sections at your own pace.

---

**Q: What are the prerequisites?**

A: You need:
- Azure subscription with contributor access
- Azure CLI installed and configured
- Docker installed (if building custom images)
- Basic understanding of REST APIs and cloud concepts
- GitHub Copilot for Azure (SRE Agent) access

---

**Q: What Azure services are used?**

A:
- Azure Container Apps
- Azure API Management (Consumption tier)
- PostgreSQL Flexible Server
- Virtual Network (VNet)
- Application Insights
- Azure Container Registry (optional)
- Log Analytics Workspace

---

**Q: How much does this workshop cost?**

A: Estimated daily costs:
- Container Apps: ~$1-3/day (depending on usage)
- APIM Consumption: ~$0.50-2/day (pay-per-call)
- PostgreSQL Flexible Server (B1ms): ~$0.50/day
- Application Insights: ~$0.50-2/day
- VNet/Networking: ~$0.10/day

**Total: ~$3-8/day** depending on usage.

**Important:** Remember to clean up resources after the workshop!

---

### Deployment Questions

**Q: The deployment is taking a long time. Is this normal?**

A: Yes! Full deployment typically takes 10-12 minutes. This is primarily due to:
- APIM Consumption tier: ~8-10 minutes
- Container Apps environment: ~2-3 minutes
- PostgreSQL: ~1-2 minutes
- Other resources: <1 minute

APIM Consumption tier deployment is the main bottleneck but offers cost savings.

---

**Q: Deployment failed with "ACR image pull error". What should I do?**

A: This usually means the managed identity doesn't have permission to pull from ACR. Follow these steps:

1. Get the managed identity principal ID:
```bash
az containerapp show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --query identity.principalId -o tsv
```

2. Grant AcrPull role:
```bash
az role assignment create \
  --assignee <PRINCIPAL_ID> \
  --role AcrPull \
  --scope <ACR_RESOURCE_ID>
```

3. Restart the Container App:
```bash
az containerapp revision restart \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --revision <LATEST_REVISION_NAME>
```

---

**Q: How do I verify all resources deployed successfully?**

A:
```bash
# List all resources
az resource list \
  --resource-group $RESOURCE_GROUP \
  --output table

# Check specific resource health
az containerapp show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --query properties.runningStatus

# Test the API
curl "$APIM_URL/api/health"
```

---

**Q: Can I use an existing ACR instead of creating a new one?**

A: Yes! Just provide your existing ACR name and image when deploying:
```bash
--parameters \
  acrName=your-existing-acr \
  containerImage=your-existing-acr.azurecr.io/your-image:tag
```

Make sure the managed identity has AcrPull role on your existing ACR.

---

### API and Testing Questions

**Q: The API returns 401 Unauthorized. What's wrong?**

A: You need to include the APIM subscription key in your requests:

```bash
# Get the subscription key
az apim subscription show \
  --resource-group $RESOURCE_GROUP \
  --service-name <APIM_NAME> \
  --subscription-id <SUBSCRIPTION_ID> \
  --query primaryKey -o tsv

# Use in requests
curl -H "Ocp-Apim-Subscription-Key: YOUR_KEY" \
  "$APIM_URL/api/health"
```

---

**Q: The API returns 500 errors. How do I troubleshoot?**

A: Follow this troubleshooting sequence:

1. **Check Container App logs:**
```bash
az containerapp logs show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --follow
```

2. **Check Application Insights:**
```bash
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    exceptions
    | where timestamp > ago(30m)
    | project timestamp, type, outerMessage
  "
```

3. **Common causes:**
   - Database connection issues (check connection string)
   - Missing environment variables
   - Network connectivity problems
   - Application code errors

See [Part 2: Troubleshooting](./exercises/part2-troubleshooting.md) for detailed scenarios.

---

**Q: How do I test all CRUD operations?**

A: Use the test script provided in Part 1 or run these commands:

```bash
# Create item
ITEM_ID=$(curl -s -X POST \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Item", "description": "Test"}' \
  "$APIM_URL/api/items" | jq -r '.id')

# Get item
curl -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/api/items/$ITEM_ID"

# Update item
curl -X PUT \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  -H "Content-Type: application/json" \
  -d '{"name": "Updated", "description": "Updated"}' \
  "$APIM_URL/api/items/$ITEM_ID"

# Delete item
curl -X DELETE \
  -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
  "$APIM_URL/api/items/$ITEM_ID"
```

---

### SRE Agent Questions

**Q: What is SRE Agent?**

A: SRE Agent is GitHub Copilot for Azure, an AI assistant specialized in Azure operations, troubleshooting, and SRE practices. It helps you:
- Investigate incidents
- Write KQL queries
- Generate Azure CLI commands
- Create runbooks and documentation
- Provide best practices

---

**Q: How do I get access to SRE Agent?**

A: SRE Agent is available as:
- GitHub Copilot for Azure in VS Code
- Azure Portal integration
- Azure CLI integration (preview)

Check with your organization's GitHub or Azure administrator for access.

---

**Q: What kind of questions should I ask SRE Agent?**

A: Effective questions:
- ✅ "How do I check Container App logs for errors in the last hour?"
- ✅ "Write a KQL query to find slow database queries"
- ✅ "What could cause 500 errors on my API?"
- ✅ "Help me write a runbook for database connection failures"

Less effective:
- ❌ "Fix my app" (too vague)
- ❌ "Why doesn't it work?" (no context)

Always provide context: resource names, error messages, what you've tried.

---

**Q: Can I use SRE Agent without this workshop?**

A: Yes! SRE Agent works with any Azure resources. This workshop provides:
- Structured scenarios to practice with
- Sample infrastructure to experiment on
- Guided exercises to build skills

You can apply these skills to any Azure environment.

---

### Monitoring and Alerts Questions

**Q: Why aren't my alerts firing?**

A: Check these common issues:

1. **Alert not enabled:**
```bash
az monitor metrics alert show \
  --name "Alert-Name" \
  --resource-group $RESOURCE_GROUP \
  --query enabled
```

2. **Threshold not reached:** Verify metrics are actually exceeding thresholds

3. **Evaluation frequency:** Alerts check at defined intervals (1m, 5m, etc.)

4. **Action group not configured:** Ensure alert has action group assigned

---

**Q: How do I reduce alert noise?**

A: Strategies from Exercise 8 in Part 3:

1. **Increase thresholds** for less critical alerts
2. **Lengthen time windows** to avoid transient spikes
3. **Use multi-condition alerts** (AND logic)
4. **Adjust severity levels** appropriately
5. **Regular alert reviews** to identify noisy alerts

See [Part 3, Exercise 8](./exercises/part3-monitoring.md#exercise-8-alert-fatigue-management) for details.

---

**Q: What metrics should I monitor?**

A: Focus on the "Four Golden Signals":

1. **Latency:** Request duration, P95/P99 response times
2. **Traffic:** Request rate, throughput
3. **Errors:** Error rate, 5xx responses, exceptions
4. **Saturation:** CPU, memory, database connections

Plus application-specific metrics:
- Business KPIs (items created, users active)
- Database query performance
- Cache hit rates
- Resource utilization

---

### Cost Questions

**Q: How can I reduce costs?**

A: Cost optimization strategies:

1. **Right-size resources** based on actual usage
2. **Use auto-scaling** to reduce idle capacity
3. **Implement caching** to reduce database load
4. **Clean up unused resources** regularly
5. **Use Azure Reservations** for predictable workloads
6. **Optimize sampling** in Application Insights

See [Advanced Exercise 6](./exercises/advanced-exercises.md#exercise-6-cost-optimization-analysis) for detailed guidance.

---

**Q: What happens if I forget to delete resources?**

A: You'll continue to incur charges. Common costs:
- APIM Consumption: Pay per call (low when idle)
- Container Apps: Charged per vCPU-second and GB-second
- PostgreSQL: Charged per hour regardless of usage
- Application Insights: Charged per GB ingested

**Always delete resource groups after the workshop!**

---

### Database Questions

**Q: How do I connect to the PostgreSQL database?**

A:
```bash
# Get database details
POSTGRES_HOST=$(az postgres flexible-server show \
  --resource-group $RESOURCE_GROUP \
  --name <SERVER_NAME> \
  --query fullyQualifiedDomainName -o tsv)

# Connect with psql
psql "host=$POSTGRES_HOST dbname=workshopdb user=sqladmin password=SecurePassword123 sslmode=require"
```

Note: VNet integration may prevent direct access. Connect from within the VNet or enable public access temporarily.

---

**Q: How do I check database connections?**

A:
```sql
-- Connect to database and run:
SELECT 
    count(*) as connection_count,
    max_connections,
    (count(*) * 100.0 / max_connections) as usage_percent
FROM pg_stat_activity, 
     (SELECT setting::int as max_connections FROM pg_settings WHERE name = 'max_connections') mc
GROUP BY max_connections;
```

---

**Q: The app can't connect to the database. What should I check?**

A: Troubleshooting steps:

1. **Check VNet integration:**
```bash
az containerapp show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.ingress
```

2. **Verify connection string:**
```bash
az containerapp show \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --query properties.template.containers[0].env
```

3. **Check PostgreSQL firewall rules:**
```bash
az postgres flexible-server firewall-rule list \
  --resource-group $RESOURCE_GROUP \
  --name <SERVER_NAME>
```

4. **Test connectivity from Container App:**
```bash
az containerapp exec \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --command "/bin/sh"

# Then in the shell:
nc -zv <POSTGRES_HOST> 5432
```

---

### Performance Questions

**Q: The API is slow. How do I identify bottlenecks?**

A: Follow the performance optimization workflow:

1. **Measure baseline:**
```bash
# Run load test
for i in {1..100}; do
  curl -w "%{time_total}\n" -o /dev/null -s \
    -H "Ocp-Apim-Subscription-Key: $SUBSCRIPTION_KEY" \
    "$APIM_URL/api/items"
done
```

2. **Profile with Application Insights:**
```bash
az monitor app-insights query \
  --app $APP_INSIGHTS_NAME \
  --analytics-query "
    requests
    | where timestamp > ago(1h)
    | summarize avg(duration), percentile(duration, 95) by name
  "
```

3. **Check database performance:**
```sql
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

See [Advanced Exercise 4](./exercises/advanced-exercises.md#exercise-4-performance-optimization-deep-dive) for comprehensive guide.

---

**Q: Should I implement caching?**

A: Consider caching if:
- ✅ You have read-heavy workloads
- ✅ Data doesn't change frequently
- ✅ Same queries run repeatedly
- ✅ Database is a bottleneck

Don't cache if:
- ❌ Data changes frequently
- ❌ Each query is unique
- ❌ Real-time data is critical
- ❌ Cache complexity exceeds benefits

---

### Workshop Content Questions

**Q: Can I customize the workshop for my team?**

A: Absolutely! The workshop is designed to be adaptable:
- Modify the infrastructure (add services, change tiers)
- Adjust difficulty levels
- Add your own scenarios
- Focus on specific areas (monitoring, troubleshooting, etc.)
- Use your own applications instead of the sample API

---

**Q: Can I use this workshop for training?**

A: Yes! This workshop is designed for:
- Team training sessions
- Hackathons
- Learning labs
- Self-paced learning
- Interview practice

Feel free to adapt and extend for your needs.

---

**Q: Where can I get help if I'm stuck?**

A:
1. **Use SRE Agent:** Ask specific questions about your issue
2. **Check logs:** Container Apps, Application Insights, Activity Log
3. **Review exercises:** Part 2 has common troubleshooting scenarios
4. **Azure documentation:** Links provided throughout workshop
5. **Community forums:** Azure community, Stack Overflow

---

### Cleanup Questions

**Q: How do I clean up all resources?**

A: The simplest way:
```bash
# Delete the entire resource group (CAUTION: irreversible!)
az group delete --name $RESOURCE_GROUP --yes --no-wait
```

For selective cleanup, see [Cleanup Guide](./cleanup.md).

---

**Q: I deleted the resource group but still see charges. Why?**

A: Check for:
- **Logs in Log Analytics:** Retained based on retention policy
- **Application Insights data:** Charged separately if in different resource group
- **Soft-deleted resources:** Some Azure resources have soft-delete (Key Vault, etc.)
- **Network egress:** Data transfer charges may appear later

---

**Q: Can I pause resources instead of deleting?**

A:
- **Container Apps:** Scale to 0 replicas (minimal cost)
- **PostgreSQL:** Stop the server (still charged for storage)
- **APIM Consumption:** Pay per call (low cost when idle)
- **Application Insights:** Reduce sampling or set daily cap

Note: Some services don't support "pause" - plan accordingly.

---

### Advanced Questions

**Q: How do I implement CI/CD for this setup?**

A: GitHub Actions workflow example:

```yaml
name: Deploy Workshop API

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Build and push image
        run: |
          az acr build -t workshop-api:${{ github.sha }} \
            -r ${{ secrets.ACR_NAME }} ./api
      
      - name: Update Container App
        run: |
          az containerapp update \
            --name workshop-api \
            --resource-group ${{ secrets.RESOURCE_GROUP }} \
            --image ${{ secrets.ACR_NAME }}.azurecr.io/workshop-api:${{ github.sha }}
```

---

**Q: Can I deploy this in production?**

A: This workshop provides a foundation, but production requires:
- ✅ Enhanced security (Key Vault, private endpoints)
- ✅ Multi-region deployment for HA
- ✅ Backup and disaster recovery
- ✅ Enhanced monitoring and alerting
- ✅ Auto-scaling policies
- ✅ Security scanning and compliance
- ✅ Change management processes

See [Azure Well-Architected Framework](https://docs.microsoft.com/en-us/azure/architecture/framework/) for production guidance.

---

**Q: How do I add authentication to the API?**

A: Options:

1. **APIM Subscription Keys** (already implemented)
2. **Azure AD / Entra ID:**
```bash
az containerapp auth update \
  --name ${BASE_NAME}-dev-api \
  --resource-group $RESOURCE_GROUP \
  --action AllowAnonymous \
  --identity-provider AzureActiveDirectory
```
3. **Custom JWT validation in application code**
4. **APIM JWT validation policy**

---

**Q: What's next after completing the workshop?**

A: Continue your SRE journey:

1. **Apply to real projects:** Use these skills on actual applications
2. **Explore Azure services:** Try other services (Service Bus, Event Grid, etc.)
3. **Advanced topics:** Kubernetes, microservices, service mesh
4. **Certifications:** Azure Administrator, DevOps Engineer, Solutions Architect
5. **SRE practices:** Incident management, on-call rotations, SLO tracking
6. **Community:** Join Azure and SRE communities, share your learnings

---

## Getting More Help

### Resources

- **Azure Documentation:** https://docs.microsoft.com/azure
- **Azure CLI Reference:** https://docs.microsoft.com/cli/azure
- **KQL Reference:** https://docs.microsoft.com/azure/data-explorer/kusto/query/
- **SRE Resources:** https://sre.google/books/

### Community

- **Azure Community:** https://techcommunity.microsoft.com/t5/azure/ct-p/Azure
- **Stack Overflow:** Tag questions with `azure`, `azure-container-apps`, etc.
- **GitHub:** Open issues in this repository for workshop-specific questions

### Support

- **Azure Support:** https://azure.microsoft.com/support
- **SRE Agent Help:** Access help within your IDE or Azure Portal

---

## Contributing to This FAQ

Found an issue or have a question not covered here? Please:
1. Open an issue in the repository
2. Submit a pull request with additions
3. Share your feedback

This FAQ is continuously updated based on workshop participant feedback.

---

**Last Updated:** November 6, 2025

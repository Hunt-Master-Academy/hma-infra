# HMA Compliance Stack - Deployment Quick Reference

## 🚀 Quick Start (5 minutes)

```bash
cd /home/xbyooki/projects/hma-infra/docker

# 1. Set kernel parameter
sudo sysctl -w vm.max_map_count=262144

# 2. Create environment file
cp .env.compliance.example .env.compliance
nano .env.compliance  # Set secure passwords

# 3. Run automated deployment
./scripts/deploy-compliance-stack.sh
```

## 📋 Manual Deployment Steps

### 1. Prerequisites
```bash
# Ensure main HMA stack is running
docker compose ps | grep -E "postgres|redis|minio"

# Set kernel parameter for Wazuh/OpenSearch
sudo sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

### 2. Database Setup
```bash
# Initialize PostgreSQL databases
./scripts/init-compliance-dbs.sh

# Verify database creation
docker exec hma_postgres psql -U hma_admin -d postgres -c "\l" | grep ciso
```

### 3. Storage Setup
```bash
# Create MinIO buckets for evidence
./scripts/init-compliance-storage.sh

# Verify buckets
docker exec hma_minio mc ls local/ | grep hma-compliance
```

### 4. Deploy Services
```bash
# Deploy compliance stack
docker compose -f docker-compose.compliance.yml up -d

# Watch logs during startup
docker compose -f docker-compose.compliance.yml logs -f
```

### 5. Initialize CISO Assistant
```bash
# Run database migrations
docker exec hma_ciso_backend python manage.py migrate

# Create superuser
docker exec -it hma_ciso_backend python manage.py createsuperuser

# Load compliance frameworks
docker exec hma_ciso_backend python manage.py loaddata frameworks
```

### 6. Verify Deployment
```bash
# Check all services are healthy
docker compose -f docker-compose.compliance.yml ps

# Test endpoints
curl -k https://localhost:8443  # CISO Assistant
curl -k https://localhost:8444  # Wazuh Dashboard
```

## 🔗 Access URLs

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| CISO Assistant | https://localhost:8443 | Set in .env.compliance |
| Wazuh Dashboard | https://localhost:8444 | admin / admin |
| Wazuh API | https://localhost:55000 | Set in .env.compliance |
| MinIO Console | http://localhost:9001 | minioadmin / minioadmin |

## 🛠️ Management Commands

### Service Control
```bash
# Start all compliance services
docker compose -f docker-compose.compliance.yml up -d

# Stop all compliance services
docker compose -f docker-compose.compliance.yml down

# Restart specific service
docker compose -f docker-compose.compliance.yml restart hma-ciso-backend

# View logs
docker compose -f docker-compose.compliance.yml logs -f hma-wazuh-manager
```

### CISO Assistant Management
```bash
# Create admin user
docker exec -it hma_ciso_backend python manage.py createsuperuser

# Run migrations
docker exec hma_ciso_backend python manage.py migrate

# Access Django shell
docker exec -it hma_ciso_backend python manage.py shell

# Backup database
docker exec hma_postgres pg_dump -U ciso_admin ciso_assistant > ciso_backup.sql
```

### Wazuh Management
```bash
# Check Wazuh status
docker exec hma_wazuh_manager /var/ossec/bin/wazuh-control status

# View active agents
docker exec hma_wazuh_manager /var/ossec/bin/agent_control -l

# Restart Wazuh Manager
docker compose -f docker-compose.compliance.yml restart hma-wazuh-manager

# View Wazuh logs
docker exec hma_wazuh_manager tail -f /var/ossec/logs/ossec.log
```

## 🔍 Monitoring & Health Checks

### Service Health
```bash
# Check all container health
docker compose -f docker-compose.compliance.yml ps

# Check specific service health
docker inspect hma_wazuh_indexer --format='{{.State.Health.Status}}'

# View resource usage
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

### Database Health
```bash
# Check PostgreSQL connections
docker exec hma_postgres psql -U ciso_admin -d ciso_assistant -c "SELECT count(*) FROM pg_stat_activity;"

# Check database size
docker exec hma_postgres psql -U hma_admin -d postgres -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database;"
```

### Storage Health
```bash
# Check MinIO bucket usage
docker exec hma_minio mc du local/hma-compliance-evidence

# List recent evidence files
docker exec hma_minio mc ls local/hma-compliance-evidence --recursive | tail -20
```

## 🔒 Security Hardening

### Change Default Passwords
```bash
# Generate secure passwords
openssl rand -base64 32

# Update .env.compliance with new passwords
nano .env.compliance

# Restart services to apply
docker compose -f docker-compose.compliance.yml restart
```

### Enable Production TLS
```bash
# Edit Caddyfile for production domain
nano caddy/Caddyfile

# Replace localhost with your domain:
# https://compliance.huntmasteracademy.com {
#     tls your-email@huntmasteracademy.com
#     ...
# }

# Restart Caddy
docker compose -f docker-compose.compliance.yml restart hma-caddy
```

### Configure Firewall
```bash
# Allow only necessary ports
sudo ufw allow 8443/tcp  # CISO Assistant HTTPS
sudo ufw allow 8444/tcp  # Wazuh Dashboard HTTPS
sudo ufw allow 1514/tcp  # Wazuh agent registration
sudo ufw allow 1515/tcp  # Wazuh agent events

# Deny direct access to internal services
sudo ufw deny 5601/tcp   # Wazuh Dashboard (access via Caddy only)
sudo ufw deny 9200/tcp   # Wazuh Indexer (internal only)
```

## 📊 Integration with Existing Stack

### Prometheus Integration
```bash
# Add Wazuh exporter to prometheus.yml
cat >> ../monitoring/prometheus.yml << EOF
  - job_name: 'wazuh'
    static_configs:
      - targets: ['hma-wazuh-exporter:9190']
EOF

# Restart Prometheus
docker compose restart prometheus
```

### Grafana Dashboards
```bash
# Import Wazuh dashboard
# Navigate to: http://localhost:3003
# Import dashboard ID: 14390 (Wazuh Overview)

# Create custom compliance dashboard
# Add panels for:
# - Active security alerts
# - Compliance control status
# - Evidence collection metrics
```

## 🐛 Troubleshooting

### CISO Assistant Won't Start
```bash
# Check database connection
docker exec hma_ciso_backend python manage.py check --database default

# View detailed logs
docker logs hma_ciso_backend --tail 100

# Recreate database (WARNING: destroys data)
docker exec hma_postgres dropdb -U hma_admin ciso_assistant
./scripts/init-compliance-dbs.sh
```

### Wazuh Indexer Issues
```bash
# Check indexer logs
docker logs hma_wazuh_indexer --tail 100

# Verify kernel parameter
sysctl vm.max_map_count  # Should be >= 262144

# Check disk space
df -h /var/lib/docker

# Clear old indices (if needed)
docker exec hma_wazuh_indexer curl -X DELETE "localhost:9200/wazuh-alerts-*"
```

### Connection Timeouts
```bash
# Check network connectivity
docker exec hma_ciso_backend ping -c 3 postgres
docker exec hma_wazuh_dashboard curl -I hma-wazuh-indexer:9200

# Verify DNS resolution
docker exec hma_ciso_backend nslookup postgres

# Restart network
docker network disconnect hma-network hma_ciso_backend
docker network connect hma-network hma_ciso_backend
```

## 📚 Next Steps

1. **Configure Compliance Frameworks**
   - Log into CISO Assistant at https://localhost:8443
   - Import ISO 27001, SOC 2, GDPR, CCPA frameworks
   - Create first risk assessment

2. **Set Up Wazuh Agents**
   - Install Wazuh agent on Docker host
   - Configure file integrity monitoring
   - Set up AWS CloudWatch integration

3. **Create Compliance Workflows**
   - Define policies in CISO Assistant
   - Map controls to technical implementations
   - Set up automated evidence collection

4. **Configure Alerting**
   - Connect Wazuh to Alertmanager
   - Create notification channels (Slack, email)
   - Define escalation policies

5. **Documentation**
   - Document security procedures
   - Create incident response runbooks
   - Train team on compliance workflows

## 📖 Additional Resources

- [COMPLIANCE_STACK_ASSESSMENT.md](COMPLIANCE_STACK_ASSESSMENT.md) - Complete deployment guide
- [Compliance_Security_Development.md](../hma-project/project-management/Compliance_Security_Development.md) - Tool analysis
- [CISO Assistant Docs](https://docs.ciso-assistant.com/)
- [Wazuh Documentation](https://documentation.wazuh.com/)

---

**Need help?** Check the troubleshooting section or review detailed logs with:
```bash
docker compose -f docker-compose.compliance.yml logs -f
```

# HMA Monitoring Stack Integration

**Date**: October 7, 2025  
**Status**: ✅ Complete

## Overview

Successfully integrated Prometheus, Grafana, and Jaeger into the main HMA docker-compose infrastructure with standardized naming conventions.

## Changes Made

### 1. Docker Compose Integration

Added three new services to `/home/xbyooki/projects/hma-infra/docker/docker-compose.yml`:

#### Prometheus (`hma_prometheus`)
- **Image**: `prom/prometheus:v2.37.0`
- **Port**: 9090
- **Configuration**: `/home/xbyooki/projects/hma-infra/monitoring/prometheus.yml`
- **Data Volume**: `prometheus_data`
- **Health Check**: Enabled
- **Purpose**: Metrics collection and time-series database

#### Grafana (`hma_grafana`)
- **Image**: `grafana/grafana:10.2.0`
- **Port**: 3003 (mapped to internal 3000)
- **Admin Password**: `admin` (default, configurable via `GRAFANA_ADMIN_PASSWORD`)
- **Data Volume**: `grafana_data`
- **Dashboards**: Auto-provisioned from `/home/xbyooki/projects/grafana/dashboards/`
- **Datasources**: Auto-provisioned from `/home/xbyooki/projects/grafana/datasources/`
- **Health Check**: Enabled
- **Purpose**: Metrics visualization and dashboarding

#### Jaeger (`hma_jaeger`)
- **Image**: `jaegertracing/all-in-one:1.51`
- **Ports**: 
  - 16686 (UI)
  - 4318 (OTLP HTTP receiver)
  - 6831/udp (Jaeger Thrift compact)
- **OTLP Support**: Enabled
- **Health Check**: Enabled
- **Purpose**: Distributed tracing

### 2. Prometheus Configuration

Updated `/home/xbyooki/projects/hma-infra/monitoring/prometheus.yml` to scrape all HMA services:

**Monitored Services**:
- ✅ Prometheus (self-monitoring)
- ✅ HMA Academy Brain (port 3001)
- ✅ HMA Academy API Gateway (port 3000)
- ✅ HMA Engine Mocks (port 4100)
- ✅ MinIO (port 9000, metrics endpoint)
- 🔧 PostgreSQL exporter (commented out, can be enabled)
- 🔧 Redis exporter (commented out, can be enabled)

**Configuration**:
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'hma-local-dev'
    environment: 'development'
```

### 3. Container Naming Convention

All monitoring containers now follow HMA naming:
- ✅ `hma_prometheus` (was `prometheus`)
- ✅ `hma_grafana` (was `grafana`)
- ✅ `hma_jaeger` (was `jaeger`)

## Complete HMA Infrastructure

### Core Application Services (5)
1. ✅ **hma-academy-brain** (Port 3001) - Main backend
2. ✅ **hma-academy-api** (Port 3000) - API Gateway
3. ✅ **hma-academy-web** (Port 3004) - Frontend
4. ✅ **hma-engine-mocks** (Port 4100) - Mock engines
5. ✅ **hma_postgres** (Port 5432) - Database

### Infrastructure Services (2)
6. ✅ **hma_redis** (Port 6379) - Cache/sessions
7. ✅ **hma_minio** (Ports 9000-9001) - Object storage

### Management Tools (2)
8. ✅ **hma_adminer** (Port 8080) - Database GUI
9. ✅ **hma_redis_commander** (Port 8081) - Redis GUI

### Observability Stack (3)
10. ✅ **hma_prometheus** (Port 9090) - Metrics collection
11. ✅ **hma_grafana** (Port 3003) - Metrics visualization
12. ✅ **hma_jaeger** (Port 16686) - Distributed tracing

**Total**: 12 containers, all healthy ✅

## Access Points

### Application
- **Main App**: http://localhost:3004/
- **Admin Portal**: http://localhost:3004/admin-portal/
- **API Gateway**: http://localhost:3000
- **Backend Service**: http://localhost:3001

### Infrastructure Management
- **MinIO Console**: http://localhost:9001
- **Database Admin (Adminer)**: http://localhost:8080
- **Redis Commander**: http://localhost:8081

### Observability
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3003 (admin/admin)
- **Jaeger UI**: http://localhost:16686

## Usage

### Starting the Full Stack
```bash
cd /home/xbyooki/projects/hma-infra/docker
docker-compose up -d
```

### Starting Only Monitoring
```bash
cd /home/xbyooki/projects/hma-infra/docker
docker-compose up -d prometheus grafana jaeger
```

### Viewing Logs
```bash
docker-compose logs -f prometheus grafana jaeger
```

### Health Check
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

## Configuration Files

### Prometheus
- **Config**: `/home/xbyooki/projects/hma-infra/monitoring/prometheus.yml`
- **Data Volume**: `prometheus_data` (Docker managed)
- **Retention**: Default (15 days)

### Grafana
- **Dashboards**: `/home/xbyooki/projects/grafana/dashboards/`
- **Datasources**: `/home/xbyooki/projects/grafana/datasources/`
- **Data Volume**: `grafana_data` (Docker managed)

### Jaeger
- **Storage**: In-memory (development mode)
- **Sampling**: Default strategies
- **UI**: Auto-configured

## Next Steps

### Recommended Enhancements

1. **Grafana Dashboards**
   - Create HMA-specific dashboards
   - Configure Prometheus datasource
   - Add alerting rules

2. **Application Instrumentation**
   - Add Prometheus metrics endpoints to backend services
   - Implement OpenTelemetry tracing
   - Configure Jaeger exporters

3. **Alerting**
   - Configure Prometheus alerting rules
   - Set up Alertmanager
   - Integrate with notification channels

4. **Exporters** (Optional)
   - Add PostgreSQL exporter for database metrics
   - Add Redis exporter for cache metrics
   - Add Node exporter for host metrics

5. **Production Configuration**
   - Configure persistent storage for Jaeger
   - Set up external authentication for Grafana
   - Configure data retention policies

## Migration Notes

### What Changed
- Old containers (`grafana`, `prometheus`, `jaeger`) removed
- New containers with HMA naming created
- All data preserved in new volumes
- Configuration centralized in HMA infrastructure

### Rollback (if needed)
```bash
# Stop new containers
docker-compose down prometheus grafana jaeger

# Start old containers (if they exist)
docker start grafana prometheus jaeger
```

## Troubleshooting

### Prometheus Can't Scrape Services
- Check that services expose `/metrics` endpoints
- Verify network connectivity: `docker exec hma_prometheus wget -O- http://hma-academy-brain:3001/metrics`
- Review Prometheus targets: http://localhost:9090/targets

### Grafana Dashboards Not Loading
- Check volume mounts: `docker inspect hma_grafana`
- Verify dashboard files exist in `/home/xbyooki/projects/grafana/dashboards/`
- Check Grafana logs: `docker logs hma_grafana`

### Jaeger Not Receiving Traces
- Verify OTLP endpoint is accessible: `curl http://localhost:4318/v1/traces`
- Check application tracing configuration
- Review Jaeger logs: `docker logs hma_jaeger`

## Related Documentation

- [HMA Architecture Verification Report](../../HMA_ARCHITECTURE_VERIFICATION_REPORT.md)
- [System Integration Map](../../SYSTEM_INTEGRATION_MAP.md)
- [Docker Environment Guide](../DOCKER_ENVIRONMENT.md)
- [Admin Portal Guide](../../ADMIN_PORTAL_GUIDE.md)
- [Developer Workspace Guide](../../DEVELOPER_WORKSPACE_GUIDE.md)

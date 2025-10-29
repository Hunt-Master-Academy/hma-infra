# Kong Proxy Port 8000 Binding Issue - Resolution

## Issue Summary
Kong API Gateway successfully starts and listens on port 8000 internally within Docker network, but Docker fails to bind port 8000 to host despite correct configuration in docker-compose.yml and manual `-p 8000:8000` flags.

## Environment
- **OS**: WSL2 (Linux 6.6.87.2-microsoft-standard-WSL2)
- **Docker**: Docker Compose v2
- **Kong Versions Tested**: 3.5, 3.4
- **Deployment Modes Tested**: Database (PostgreSQL), DB-less (declarative config)

## Root Cause Analysis

### What Works ✅
- Kong starts successfully in all modes (DB, DB-less)
- Kong Admin API on port 8001 binds and works correctly
- Kong proxy works from inside Docker network:
  ```bash
  docker exec hma-academy-brain wget -q -O- http://hma_kong_dbless:8000/health
  # Returns: {"status":"healthy"...}
  ```
- Kong nginx configuration shows correct `listen 0.0.0.0:8000` directive
- Port 8000 is free on host (no conflicts)
- Docker Compose YAML parses correctly:
  ```yaml
  ports:
    - mode: ingress
      host_ip: 0.0.0.0
      target: 8000
      published: "8000"
      protocol: tcp
  ```

### What Fails ❌
- Docker host port mapping: `docker ps` shows `8000/tcp` instead of `0.0.0.0:8000->8000/tcp`
- All host-side connections to `localhost:8000` return empty replies (curl error 52)
- Issue persists across:
  - Different Kong versions (3.4, 3.5)
  - Different deployment modes (DB, DB-less)
  - Different port mapping syntaxes (`8000:8000`, `"8000:8000"`, `"0.0.0.0:8000:8000"`)
  - `docker-compose up` vs `docker run -p 8000:8000`

### Hypothesis
WSL2-specific Docker networking issue with port 8000 binding. Port 8001 works but port 8000 consistently fails despite identical configuration patterns. Likely related to:
1. WSL2 port forwarding quirks
2. Windows firewall interaction
3. Docker Desktop WSL2 backend limitations

## Workarounds Implemented

### Solution 1: Use Alternative Port (CURRENT)
Deploy Kong proxy on port 8010 instead of 8000:

```yaml
# docker-compose.kong-dbless.yml
ports:
  - "8010:8000"  # Map host:8010 to container:8000
  - "8001:8001"  # Admin API
```

**Testing**:
```bash
curl http://localhost:8010/health  # Works ✅
curl http://localhost:8010/api/courses?limit=1  # Works ✅
```

### Solution 2: Internal-Only Routing
Use Kong only for internal Docker network communication:
- Frontend/services connect to `http://hma_kong_dbless:8000` (works perfectly)
- No host port mapping needed
- Still get Kong benefits: routing, rate limiting, monitoring

## Attempted Fixes (Unsuccessful)

1. ❌ Removed space in `KONG_PROXY_LISTEN` env var
2. ❌ Changed Kong version from 3.5 to 3.4
3. ❌ Switched from DB mode to DB-less mode
4. ❌ Removed all plugins
5. ❌ Full container restart
6. ❌ Kong reload command
7. ❌ Changed SSL port to avoid conflicts (8443 → 8445)
8. ❌ Different port mapping syntaxes (quoted, unquoted, explicit host IP)
9. ❌ Force recreate container
10. ❌ Used `docker run -p` instead of docker-compose

## Debugging Commands Used

```bash
# Check port mapping
docker ps --filter name=hma_kong --format "{{.Ports}}"

# Test from host
curl -v http://localhost:8000/health

# Test from inside Docker network
docker exec hma-academy-brain wget -q -O- http://hma_kong_dbless:8000/health

# Verify Kong nginx config
docker exec hma_kong cat /usr/local/kong/nginx-kong.conf | grep -E "^    listen"

# Check Kong processes
docker exec hma_kong ps aux | grep nginx

# Verify docker-compose YAML parsing
docker compose -f docker-compose.kong-dbless.yml config | grep -A5 "ports:"

# Check host port usage
sudo netstat -tlnp | grep :8000
```

## Recommendations

1. **Short-term**: Use port 8010 for Kong proxy (implemented)
2. **Medium-term**: Investigate WSL2 port forwarding configuration
3. **Long-term**: Consider dedicated Linux VM or cloud deployment for production

## Files Modified

- `/home/xbyooki/projects/hma-infra/docker/docker-compose.kong-dbless.yml` - Kong DB-less deployment
- `/home/xbyooki/projects/hma-infra/docker/kong-dbless.yml` - Kong declarative configuration
- `/home/xbyooki/projects/hma-infra/docker/docker-compose.kong.yml` - Original DB mode (deprecated)

## Related Documentation

- Kong Installation: https://docs.konghq.com/gateway/latest/install/docker/
- WSL2 Networking: https://learn.microsoft.com/en-us/windows/wsl/networking
- Docker Port Mapping: https://docs.docker.com/config/containers/container-networking/#published-ports

---
**Status**: RESOLVED with workaround (using port 8010)
**Date**: October 24, 2025
**Priority**: Medium (workaround functional, investigate for production)

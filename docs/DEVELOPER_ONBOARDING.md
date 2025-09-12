# Hunt Master Academy - Developer Onboarding Guide

## Welcome to Hunt Master Academy Infrastructure Development

This guide will help you get up and running with the Hunt Master Academy infrastructure in **30 minutes or less**. By the end of this guide, you'll have a fully functional development environment with all services running and tested.

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] **Docker Desktop** (version 20.10+) installed and running
- [ ] **Python 3.12+** installed
- [ ] **Git** for version control
- [ ] **8GB+ RAM** available for containers
- [ ] **10GB+ disk space** for images and data
- [ ] **Terminal/Command Prompt** access

### Quick Verification
```bash
# Verify Docker
docker --version
docker-compose --version

# Verify Python  
python --version  # Should be 3.12+

# Verify available resources
docker system info | grep -E "CPUs|Total Memory"
```

---

## Quick Start (10 minutes)

### Step 1: Clone and Setup (2 minutes)
```bash
# Clone the repository
git clone <repository-url>
cd hma-infra

# Create Python virtual environment
python -m venv test_env

# Activate virtual environment
# Linux/Mac:
source test_env/bin/activate
# Windows:
# test_env\Scripts\activate

# Install Python dependencies
pip install pytest requests psycopg2-binary redis boto3
```

### Step 2: Start Infrastructure (5 minutes)
```bash
# Start all services (this may take a few minutes on first run)
docker-compose up -d

# Watch services start up
docker-compose logs -f
# Press Ctrl+C when you see "healthy" status messages

# Verify all services are running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Expected Output:**
```
NAMES                 STATUS                    PORTS
hma-content-bridge    Up X minutes (healthy)    0.0.0.0:8090->8090/tcp
hma-ml-server         Up X minutes (healthy)    0.0.0.0:8010->8000/tcp
hma_postgres          Up X minutes (healthy)    0.0.0.0:5432->5432/tcp
hma_redis             Up X minutes (healthy)    0.0.0.0:6379->6379/tcp
hma_minio             Up X minutes (healthy)    0.0.0.0:9000-9001->9000-9001/tcp
hma_adminer           Up X minutes              0.0.0.0:8080->8080/tcp
hma_redis_commander   Up X minutes (healthy)    0.0.0.0:8081->8081/tcp
```

### Step 3: Verify Installation (3 minutes)
```bash
# Quick health checks
curl http://localhost:8090  # Content Bridge API
curl http://localhost:8010  # ML Server API

# Run the full test suite
python -m pytest tests/test_service_integration.py -v

# Expected result: 21 passed in ~2.5s
```

**Congratulations!** If all tests pass, you have a fully functional development environment!

---

## Detailed Setup Guide

### Understanding the Architecture

```
Your Local Machine (localhost)
├── Port 8090: Content Bridge API (main content service)
├── Port 8010: ML Server API (machine learning service)  
├── Port 5432: PostgreSQL Database (data storage)
├── Port 6379: Redis Cache (session & caching)
├── Port 9000-9001: MinIO Object Storage (file storage)
├── Port 8080: Adminer (database management UI)
└── Port 8081: Redis Commander (cache management UI)
```

### Service Details

#### Content Bridge API (Port 8090)
- **Purpose**: Main API for content delivery, user management, authentication
- **Health Check**: `curl http://localhost:8090`
- **Key Features**: User auth, content upload, admin functions

#### ML Server API (Port 8010)  
- **Purpose**: Machine learning predictions and model management
- **Health Check**: `curl http://localhost:8010`
- **Key Features**: Model inference, predictions, analytics

#### PostgreSQL Database (Port 5432)
- **Username**: `hma_admin`
- **Password**: `dev_password`
- **Database**: `huntmaster`
- **Access**: `docker exec -it hma_postgres psql -U hma_admin -d huntmaster`

#### Redis Cache (Port 6379)
- **Password**: `development_password`  
- **Access**: `docker exec -it hma_redis redis-cli`
- **Web UI**: http://localhost:8081

#### MinIO Object Storage (Ports 9000-9001)
- **Username**: `minioadmin`
- **Password**: `minioadmin`
- **Web UI**: http://localhost:9000
- **API**: http://localhost:9001

---

## Development Workflow

### Daily Development Routine

#### 1. Start Your Development Session
```bash
# Navigate to project
cd hma-infra

# Activate Python environment
source test_env/bin/activate  # Linux/Mac
# test_env\Scripts\activate   # Windows

# Start services (if not already running)
docker-compose up -d

# Quick health check
python -m pytest tests/test_service_integration.py::TestServiceHealth -v
```

#### 2. Make Your Changes
- Edit service code in `services/content-bridge/` or `services/ml-server/`
- Update tests in `tests/test_service_integration.py`
- Modify configuration in `docker-compose.yml` if needed

#### 3. Test Your Changes
```bash
# Restart specific service after code changes
docker-compose restart hma-content-bridge
# or
docker-compose restart hma-ml-server

# Run relevant tests
python -m pytest tests/test_service_integration.py::TestAuthentication -v

# Run full test suite for final validation
python -m pytest tests/test_service_integration.py -v
```

#### 4. Debug Issues
```bash
# View service logs
docker logs hma-content-bridge
docker logs hma-ml-server

# Connect to services for debugging
docker exec -it hma-content-bridge /bin/bash
docker exec -it hma-ml-server /bin/bash

# Database debugging
docker exec -it hma_postgres psql -U hma_admin -d huntmaster

# Redis debugging  
docker exec -it hma_redis redis-cli
```

### Code Organization

```
hma-infra/
├── services/
│   ├── content-bridge/
│   │   ├── app.py              # Main FastAPI application
│   │   ├── Dockerfile          # Container definition
│   │   └── requirements.txt    # Python dependencies
│   └── ml-server/
│       ├── src/main.py         # Main FastAPI application
│       ├── Dockerfile          # Container definition
│       └── requirements.txt    # Python dependencies
├── tests/
│   └── test_service_integration.py  # All integration tests
├── docs/
│   ├── ALPHA_HANDOFF_README.md      # Complete system documentation
│   ├── API_DOCUMENTATION.md         # Detailed API specs
│   ├── DEVELOPER_ONBOARDING.md      # This guide
│   └── TEST_COVERAGE.md             # Test documentation
├── docker-compose.yml              # Service orchestration
└── README.md                       # Quick start guide
```

---

## 🔍 Common Development Tasks

### Adding New API Endpoints

#### Content Bridge API Example
```python
# In services/content-bridge/app.py

@app.post("/api/new-endpoint")
async def new_endpoint(request_data: dict):
    """Add your new endpoint here"""
    return {
        "status": "success",
        "data": request_data,
        "timestamp": datetime.now().isoformat()
    }
```

#### ML Server API Example
```python
# In services/ml-server/src/main.py

@app.post("/models/new-operation")
async def new_model_operation(model_data: dict):
    """Add your new ML operation here"""
    return {
        "model_id": model_data.get("id"),
        "operation": "completed",
        "timestamp": datetime.now().isoformat()
    }
```

### Adding New Tests
```python
# In tests/test_service_integration.py

def test_my_new_feature(self, content_bridge_session):
    """Test your new feature"""
    response = content_bridge_session.post(
        f"{CONTENT_BRIDGE_URL}/api/new-endpoint",
        json={"test": "data"}
    )
    
    assert response.status_code == 200
    assert "status" in response.json()
    assert response.json()["status"] == "success"
```

### Database Operations
```python
# Adding new tables or schemas
import subprocess

result = subprocess.run([
    'docker', 'exec', 'hma_postgres', 'psql', 
    '-U', 'hma_admin', '-d', 'huntmaster',
    '-c', '''
        CREATE SCHEMA IF NOT EXISTS my_new_schema;
        CREATE TABLE IF NOT EXISTS my_new_schema.my_table (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255),
            created_at TIMESTAMP DEFAULT NOW()
        );
    '''
], capture_output=True, text=True)
```

### Cache Operations
```python
# Working with Redis cache
import redis

redis_client = redis.Redis(
    host='localhost', 
    port=6379, 
    password='development_password',
    decode_responses=True
)

# Store data
redis_client.setex("my_key", 3600, json.dumps({"data": "value"}))

# Retrieve data
cached_data = redis_client.get("my_key")
if cached_data:
    data = json.loads(cached_data)
```

### File Storage Operations
```python
# Working with MinIO object storage
import boto3

s3_client = boto3.client(
    's3',
    endpoint_url='http://localhost:9000',
    aws_access_key_id='minioadmin',
    aws_secret_access_key='minioadmin'
)

# Store file
s3_client.put_object(
    Bucket='my-bucket',
    Key='my-file.txt',
    Body=b'file content'
)

# Retrieve file
response = s3_client.get_object(Bucket='my-bucket', Key='my-file.txt')
content = response['Body'].read()
```

---

## Troubleshooting Guide

### Common Issues & Solutions

#### Issue: Docker containers won't start
```bash
# Check Docker status
docker info

# Check available resources
docker system df

# Clean up if needed
docker system prune -f

# Restart Docker service
# Linux: sudo systemctl restart docker
# Windows/Mac: Restart Docker Desktop
```

#### Issue: Port conflicts (Address already in use)
```bash
# Find what's using the port
lsof -i :8090  # Linux/Mac
netstat -ano | findstr :8090  # Windows

# Kill the process or change port in docker-compose.yml
# Edit docker-compose.yml and change port mapping:
# "8091:8090" instead of "8090:8090"
```

#### Issue: Tests failing with connection errors
```bash
# Wait for services to fully start
docker-compose logs | grep "healthy"

# Check service health individually
curl http://localhost:8090
curl http://localhost:8010

# Restart specific service
docker-compose restart hma-content-bridge
```

#### Issue: Database connection failures
```bash
# Check PostgreSQL logs
docker logs hma_postgres

# Verify database exists
docker exec -it hma_postgres psql -U hma_admin -l

# Reset database if needed
docker-compose down
docker volume rm hma-infra_postgres_data
docker-compose up -d
```

#### Issue: Python import errors
```bash
# Verify virtual environment is activated
which python  # Should show test_env path

# Reinstall dependencies
pip install --upgrade pytest requests psycopg2-binary redis boto3

# Check Python version
python --version  # Should be 3.12+
```

### Performance Issues

#### Slow startup times
- **Cause**: First-time Docker image downloads
- **Solution**: Be patient on first run, subsequent starts are faster

#### High memory usage  
- **Cause**: Multiple containers running
- **Solution**: Close other applications, increase Docker memory limit

#### Slow test execution
- **Cause**: Network latency or resource constraints
- **Solution**: Run tests in smaller groups, check system resources

---

## Learning Resources

### Understanding the Codebase

#### FastAPI Documentation
- **Official Docs**: https://fastapi.tiangolo.com/
- **Key Concepts**: Path operations, request/response models, dependency injection
- **Used For**: Both Content Bridge and ML Server APIs

#### Docker & Docker Compose
- **Official Docs**: https://docs.docker.com/
- **Key Concepts**: Containerization, service orchestration, networking
- **Used For**: All service deployment and management

#### PostgreSQL
- **Official Docs**: https://www.postgresql.org/docs/
- **Key Concepts**: Schemas, tables, queries, transactions
- **Used For**: Primary data storage

#### Redis
- **Official Docs**: https://redis.io/documentation
- **Key Concepts**: Key-value storage, expiration, data types
- **Used For**: Caching and session management

#### MinIO
- **Official Docs**: https://docs.min.io/
- **Key Concepts**: S3-compatible object storage, buckets, objects
- **Used For**: File and asset storage

### Testing with pytest
- **Official Docs**: https://docs.pytest.org/
- **Key Concepts**: Fixtures, parametrization, assertion introspection
- **Used For**: All integration testing

---

## Development Best Practices

### Code Standards
- **Python**: Follow PEP 8 style guide
- **API Design**: Use RESTful conventions
- **Error Handling**: Always return structured error responses
- **Documentation**: Update docs when adding features

### Testing Standards
- **Coverage**: Add tests for all new functionality
- **Integration**: Test complete workflows, not just units
- **Cleanup**: Always clean up test data
- **Performance**: Include performance assertions for critical paths

### Git Workflow
```bash
# Create feature branch
git checkout -b feature/my-new-feature

# Make your changes
# ... edit code ...

# Test your changes
python -m pytest tests/test_service_integration.py -v

# Commit changes
git add .
git commit -m "Add new feature: description"

# Push and create pull request
git push origin feature/my-new-feature
```

### Documentation Standards
- **Code Comments**: Explain complex logic
- **API Changes**: Update API_DOCUMENTATION.md
- **New Features**: Update README.md
- **Breaking Changes**: Update ALPHA_HANDOFF_README.md

---

## Next Steps

### Immediate Tasks (First Week)
1. **Get familiar** with the codebase structure
2. **Run all tests** and understand what they validate
3. **Explore APIs** using curl or Postman
4. **Review documentation** to understand architecture

### Short-term Goals (First Month)
1. **Add new API endpoint** following existing patterns
2. **Write integration test** for your new endpoint  
3. **Optimize performance** of existing endpoints
4. **Contribute to documentation**

### Advanced Development (2-3 Months)
1. **Implement real authentication** system (JWT/OAuth2)
2. **Add actual ML model** loading and inference
3. **Build content processing** pipeline
4. **Set up monitoring** and alerting

---

## Getting Help

### Self-Service Resources
1. **Check logs**: `docker logs <container_name>`
2. **Review documentation**: All docs in `docs/` folder
3. **Run health checks**: `python -m pytest tests/ -k health`
4. **Search issues**: Check if problem is documented

### When to Ask for Help
- Tests are failing and you can't determine why
- Performance issues that don't resolve with restart
- Architecture questions about extending the system
- Integration questions with other modules

### How to Ask for Help
1. **Include context**: What were you trying to do?
2. **Show your work**: What commands did you run?
3. **Include output**: Copy/paste error messages
4. **Specify environment**: OS, Docker version, Python version

---

## Checklist for New Developers

### Setup Completion
- [ ] Docker Desktop installed and running
- [ ] Python 3.12+ environment created
- [ ] Repository cloned and dependencies installed
- [ ] All services started successfully (`docker ps` shows all healthy)
- [ ] All tests passing (`21 passed` in test output)
- [ ] Can access all web interfaces (8080, 8081, 9000)

### Understanding Verification
- [ ] Can explain what each service does
- [ ] Understand the data flow between services
- [ ] Know how to restart services and run tests
- [ ] Familiar with the file structure
- [ ] Comfortable with basic Docker commands

### Development Readiness
- [ ] Successfully made a small change to an API
- [ ] Added and ran a new test
- [ ] Used database, cache, and storage interfaces
- [ ] Comfortable with the debugging workflow
- [ ] Know where to find documentation

---

**Welcome to the team!** 

You're now ready to contribute to the Hunt Master Academy infrastructure. Remember: when in doubt, run the tests - they'll tell you if your changes work correctly.

For questions or suggestions about this onboarding guide, please update the documentation or reach out to the team.

---

*This developer onboarding guide reflects the Hunt Master Academy infrastructure as of September 12, 2025. Happy coding!*
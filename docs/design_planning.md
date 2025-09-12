# Database Architecture Management Strategy

## Recommendation: Centralize in `hma-infra`

You're absolutely right - a **single repository approach using `hma-infra`** is the best choice for managing database architecture. Here's why and how to structure it:

## Why `hma-infra` is the Right Choice

### 1. **Single Source of Truth**
```yaml
# hma-infra repository structure for database management
hma-infra/
├── databases/
│   ├── schemas/                    # All database schemas
│   │   ├── core/                   # Shared/canonical models
│   │   │   ├── users.sql           # Canonical user model
│   │   │   ├── authentication.sql  # Shared auth tables
│   │   │   └── audit.sql           # Cross-service audit
│   │   ├── education/              # Education domain
│   │   │   ├── courses.sql
│   │   │   ├── lessons.sql
│   │   │   └── progress.sql
│   │   ├── field/                  # Field operations domain
│   │   │   ├── locations.sql
│   │   │   ├── wildlife.sql
│   │   │   └── plans.sql
│   │   ├── social/                 # Social platform
│   │   │   ├── posts.sql
│   │   │   ├── relationships.sql
│   │   │   └── notifications.sql
│   │   └── ai/                     # AI/ML domain
│   │       ├── models.sql
│   │       ├── embeddings.sql
│   │       └── training.sql
│   ├── migrations/                 # Version-controlled migrations
│   │   ├── core/
│   │   │   ├── 001_initial_users.sql
│   │   │   ├── 002_add_profiles.sql
│   │   │   └── 003_add_preferences.sql
│   │   └── [domain]/
│   │       └── [sequential migrations]
│   ├── seeds/                      # Test data for each environment
│   │   ├── alpha/
│   │   ├── beta/
│   │   └── production/
│   ├── procedures/                 # Stored procedures & functions
│   │   ├── core/
│   │   └── [domain]/
│   └── policies/                   # RLS, permissions, etc.
│       ├── rbac.sql
│       └── row_level_security.sql
```

### 2. **Critical Benefits of Centralization**

#### Data Integrity & Consistency
```yaml
benefits:
  cross_service_integrity:
    - Foreign key relationships managed centrally
    - Consistent data types and constraints
    - Unified timestamp and timezone handling
    - Standardized geographic data formats (PostGIS)
    
  migration_coordination:
    - Atomic migrations across services
    - Dependency-aware migration ordering
    - Rollback strategies that maintain consistency
    - Single migration history table
    
  governance:
    - Centralized data standards enforcement
    - Unified naming conventions
    - Consistent indexing strategies
    - Single point for compliance auditing
```

### 3. **Implementation Structure**

```yaml
# hma-infra/terraform/databases/main.tf
module "databases" {
  source = "./modules/databases"
  
  environment = var.environment
  
  # Core database cluster
  primary_cluster = {
    engine         = "aurora-postgresql"
    version        = "15.4"
    instance_class = var.db_instance_class[var.environment]
    
    databases = [
      "hma_core",        # Shared data
      "hma_education",   # Education domain
      "hma_field",       # Field operations
      "hma_social",      # Social platform
      "hma_ai"          # AI/ML data
    ]
  }
  
  # Service-specific configs passed from here
  service_configs = {
    education = {
      max_connections = 200
      shared_buffers  = "8GB"
    }
    field = {
      extensions = ["postgis", "postgis_topology"]
    }
    ai = {
      extensions = ["pgvector", "pg_stat_statements"]
    }
  }
}
```

## Recommended Repository Organization

### Complete `hma-infra` Database Management Structure

```yaml
hma-infra/
├── README.md                       # Infrastructure overview
├── databases/
│   ├── README.md                   # Database architecture docs
│   ├── architecture/
│   │   ├── data-flow.md           # Cross-service data flows
│   │   ├── er-diagrams/            # Entity relationship diagrams
│   │   └── decisions/              # ADRs for database decisions
│   ├── schemas/                    # Schema definitions
│   ├── migrations/                 # Migration scripts
│   │   ├── migrate.sh              # Migration runner
│   │   ├── rollback.sh             # Rollback automation
│   │   └── versions/               # Versioned migrations
│   ├── monitoring/
│   │   ├── queries/                # Performance monitoring queries
│   │   ├── alerts/                 # Database alert definitions
│   │   └── dashboards/             # Grafana dashboard configs
│   └── backup/
│       ├── strategies/             # Backup strategies per env
│       └── restore/                # Restoration procedures
├── terraform/
│   ├── modules/
│   │   ├── rds/                    # RDS/Aurora module
│   │   ├── elasticache/            # Redis module
│   │   ├── s3/                     # Object storage module
│   │   └── databases/              # Database provisioning
│   └── environments/
│       ├── alpha/
│       ├── beta/
│       └── production/
├── kubernetes/
│   ├── operators/
│   │   ├── postgres-operator/      # CloudNativePG or similar
│   │   └── redis-operator/         # Redis operator
│   └── backups/
│       └── velero/                 # Backup configurations
├── scripts/
│   ├── database/
│   │   ├── create-databases.sh
│   │   ├── run-migrations.sh
│   │   ├── backup.sh
│   │   ├── restore.sh
│   │   └── sync-environments.sh
│   └── monitoring/
│       ├── check-replication.sh
│       └── analyze-performance.sh
└── .github/
    └── workflows/
        ├── database-migrations.yml  # CI/CD for migrations
        ├── schema-validation.yml    # Schema linting
        └── backup-verification.yml  # Backup testing
```

## Migration Management Strategy

### Centralized Migration Control
```python
# hma-infra/databases/migrations/migration_manager.py
import os
import hashlib
import asyncpg
from datetime import datetime
from typing import List, Dict

class MigrationManager:
    """Centralized migration management for all HMA databases"""
    
    def __init__(self, environment: str):
        self.environment = environment
        self.migration_table = "schema_migrations"
        self.domains = [
            'core',      # Must run first
            'education',
            'field',
            'social',
            'ai',
            'monitoring'
        ]
    
    async def initialize(self):
        """Create migration tracking table"""
        await self.conn.execute(f"""
            CREATE TABLE IF NOT EXISTS {self.migration_table} (
                id SERIAL PRIMARY KEY,
                domain VARCHAR(50) NOT NULL,
                version VARCHAR(20) NOT NULL,
                filename VARCHAR(255) NOT NULL,
                checksum VARCHAR(64) NOT NULL,
                executed_at TIMESTAMP DEFAULT NOW(),
                execution_time_ms INTEGER,
                rolled_back BOOLEAN DEFAULT FALSE,
                UNIQUE(domain, version)
            )
        """)
    
    async def run_migrations(self):
        """Run migrations in dependency order"""
        for domain in self.domains:
            await self.run_domain_migrations(domain)
    
    async def run_domain_migrations(self, domain: str):
        """Run migrations for a specific domain"""
        migration_dir = f"databases/migrations/{domain}"
        migrations = self.get_pending_migrations(domain, migration_dir)
        
        for migration in migrations:
            print(f"Running {domain}/{migration['filename']}...")
            
            start_time = datetime.now()
            
            try:
                # Begin transaction
                async with self.conn.transaction():
                    # Execute migration
                    with open(migration['filepath'], 'r') as f:
                        await self.conn.execute(f.read())
                    
                    # Record migration
                    await self.record_migration(
                        domain=domain,
                        version=migration['version'],
                        filename=migration['filename'],
                        checksum=migration['checksum'],
                        execution_time_ms=int(
                            (datetime.now() - start_time).total_seconds() * 1000
                        )
                    )
                    
                print(f"✓ Completed {domain}/{migration['filename']}")
                
            except Exception as e:
                print(f"✗ Failed {domain}/{migration['filename']}: {e}")
                raise
    
    def get_pending_migrations(self, domain: str, directory: str) -> List[Dict]:
        """Get list of migrations that haven't been run"""
        # Get executed migrations
        executed = self.get_executed_migrations(domain)
        
        # Get all migration files
        all_migrations = []
        for filename in sorted(os.listdir(directory)):
            if filename.endswith('.sql'):
                filepath = os.path.join(directory, filename)
                version = filename.split('_')[0]  # e.g., "001_initial.sql"
                
                with open(filepath, 'rb') as f:
                    checksum = hashlib.sha256(f.read()).hexdigest()
                
                if version not in executed:
                    all_migrations.append({
                        'version': version,
                        'filename': filename,
                        'filepath': filepath,
                        'checksum': checksum
                    })
        
        return all_migrations

# Usage in CI/CD
async def main():
    manager = MigrationManager(environment=os.getenv('ENVIRONMENT'))
    await manager.initialize()
    await manager.run_migrations()
```

## Service Integration Pattern

### How Services Interact with Centralized Database

```yaml
# Service deployment references infra-managed databases
# hma-academy-web/k8s/deployment.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: academy-db-config
data:
  database-url: "postgresql://$(DB_USER):$(DB_PASSWORD)@$(DB_HOST)/hma_education"
  
---
# Secret references from hma-infra managed secrets
apiVersion: v1
kind: Secret
metadata:
  name: academy-db-secret
type: Opaque
stringData:
  DB_USER: "academy_service"
  DB_PASSWORD: "$(vault:secret/data/hma/education/db#password)"
  DB_HOST: "hma-cluster.region.rds.amazonaws.com"
```

### Service Repository Structure
```yaml
# Each service repo only contains:
service-repo/
├── src/                    # Application code
├── models/                 # ORM models (read from central schema)
│   └── index.ts           # Sequelize/Prisma models
├── migrations/            # REMOVED - managed in hma-infra
└── config/
    └── database.ts        # Connection config only
```

## Benefits vs Alternatives Comparison

| Aspect | Centralized (hma-infra) | Distributed (per-service) | Hybrid |
|--------|------------------------|--------------------------|---------|
| **Data Consistency** | Excellent - single source | Difficult - coordination needed | Complex |
| **Migration Management** | Atomic, ordered | Race conditions | Partial coverage |
| **Cross-Service Queries** | Native support | Requires federation | Limited |
| **Development Speed** | Faster - reuse schemas | Duplication | Mixed |
| **Operational Complexity** | Single point to manage | Multiple points | Most complex |
| **Rollback Capability** | Coordinated | Service-by-service | Partial |
| **Compliance/Auditing** | Centralized | Distributed | Multiple locations |
| **Team Autonomy** | Requires coordination | Full autonomy | Mixed |

## Implementation Checklist

```markdown
## Phase 1: Repository Setup (Week 1)
- [ ] Create database directory structure in hma-infra
- [ ] Move all existing schemas to hma-infra
- [ ] Set up migration framework
- [ ] Create CI/CD pipelines for schema changes
- [ ] Document data governance policies

## Phase 2: Schema Consolidation (Week 2)
- [ ] Merge duplicate user models into canonical version
- [ ] Standardize data types across services
- [ ] Create foreign key relationships
- [ ] Add database documentation

## Phase 3: Migration Strategy (Week 3)
- [ ] Create migration ordering system
- [ ] Build rollback procedures
- [ ] Set up migration testing framework
- [ ] Create environment promotion pipeline

## Phase 4: Service Integration (Week 4)
- [ ] Update service repos to remove local schemas
- [ ] Configure services to use central database
- [ ] Update ORM models to match central schemas
- [ ] Test cross-service queries

## Phase 5: Monitoring & Operations (Week 5)
- [ ] Set up schema change notifications
- [ ] Create performance monitoring
- [ ] Implement backup verification
- [ ] Document runbooks
```

## Key Success Factors

1. **Clear Ownership**: Database team owns `hma-infra/databases/`
2. **Service Boundaries**: Services can request schema changes via PR
3. **Automated Testing**: All migrations tested in CI before merge
4. **Version Control**: Every schema change tracked and reversible
5. **Documentation**: Data dictionary maintained automatically

This centralized approach in `hma-infra` provides the best balance of control, consistency, and operational efficiency for Hunt Master Academy's complex multi-service architecture.
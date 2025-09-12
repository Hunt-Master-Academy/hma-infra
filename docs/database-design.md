# HMA Complete Database Deployment & Migration Strategy

## Executive Summary

Based on the comprehensive architecture analysis, Hunt Master Academy requires a multi-database strategy across 15+ microservices with careful orchestration for content storage, user data, and specialized domain requirements. This document outlines all databases to deploy and migration strategies for alpha → beta → production environments.

---

## Database Deployment Matrix

### Primary Databases by Domain

| Domain | Primary DB | Cache | Search | Specialized | Storage |
|--------|------------|-------|--------|-------------|---------|
| **Educational Core** | PostgreSQL 15 | Redis 7 | Elasticsearch 8 | - | S3 + CloudFront |
| **User Identity** | PostgreSQL 15 | Redis 7 | - | - | - |
| **Content Management** | Git + PostgreSQL | Redis 7 | Elasticsearch 8 | Git LFS | S3 + CloudFront |
| **Social Platform** | PostgreSQL 15 | Redis 7 | - | - | S3 |
| **Field Operations** | PostgreSQL + PostGIS | Redis 7 | - | SQLite (mobile) | S3 |
| **AI/ML Systems** | PostgreSQL 15 | Redis 7 | - | Vector DB (pgvector) | S3 + EFS |
| **Assessment Engine** | PostgreSQL 15 | Redis 7 | - | InfluxDB (analytics) | S3 |
| **Monitoring** | Prometheus TSDB | Redis 7 | Elasticsearch 8 | Loki, Tempo | S3 (cold) |
| **Security/Audit** | PostgreSQL 15 | Redis 7 | Elasticsearch 8 | - | S3 (archive) |

---

## Complete Database Deployment Plan

### 1. Core Educational Database Cluster

#### 1.1 Primary Educational Database (PostgreSQL)
```yaml
# deployment/databases/education/postgresql.yaml
name: hma-education-db
version: PostgreSQL 15.4
configuration:
  type: RDS Aurora PostgreSQL Serverless v2
  capacity:
    alpha: 0.5-1 ACU
    beta: 1-4 ACU
    production: 2-16 ACU
  
  databases:
    - hma_academy        # Core educational platform
    - hma_users          # User management
    - hma_progress       # Learning progress tracking
    - hma_assessments    # Assessment and testing
    
  high_availability:
    alpha: single-az
    beta: multi-az (2 zones)
    production: multi-az (3 zones) + read replicas
    
  backup:
    alpha: daily snapshots, 7-day retention
    beta: daily snapshots, 14-day retention
    production: continuous backup, 35-day retention, cross-region
```

#### Database Schema
```sql
-- Core Educational Schema
CREATE SCHEMA education;
CREATE SCHEMA users;
CREATE SCHEMA progress;
CREATE SCHEMA content;

-- User Management (Canonical Model)
CREATE TABLE users.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,
    username VARCHAR(100) UNIQUE,
    password_hash VARCHAR(255),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    display_name VARCHAR(255),
    avatar_url TEXT,
    role ENUM('student','instructor','admin','super_admin') DEFAULT 'student',
    status ENUM('active','suspended','deleted') DEFAULT 'active',
    preferences JSONB DEFAULT '{}',
    metadata JSONB DEFAULT '{}',
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Extended Profile (Federated across services)
CREATE TABLE users.profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES users.users(id) ON DELETE CASCADE,
    bio TEXT,
    location VARCHAR(255),
    timezone VARCHAR(50) DEFAULT 'UTC',
    language VARCHAR(10) DEFAULT 'en',
    hunting_experience ENUM('novice','intermediate','experienced','expert'),
    certifications JSONB DEFAULT '[]',
    social_links JSONB DEFAULT '{}',
    privacy_settings JSONB DEFAULT '{"profile_public": false}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Educational Content Structure
CREATE TABLE education.pillars (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    icon_url TEXT,
    color_hex VARCHAR(7),
    sort_order INTEGER,
    is_published BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE education.courses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pillar_id UUID REFERENCES education.pillars(id),
    slug VARCHAR(100) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    thumbnail_url TEXT,
    difficulty_level ENUM('beginner','intermediate','advanced','expert'),
    estimated_hours DECIMAL(5,2),
    prerequisites UUID[] DEFAULT '{}',
    tags TEXT[] DEFAULT '{}',
    is_published BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(pillar_id, slug)
);

CREATE TABLE education.lessons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    course_id UUID REFERENCES education.courses(id) ON DELETE CASCADE,
    slug VARCHAR(100) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    content_type ENUM('video','audio','text','interactive','mixed'),
    content_url TEXT,
    duration_minutes INTEGER,
    sort_order INTEGER,
    is_published BOOLEAN DEFAULT FALSE,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(course_id, slug)
);

-- Progress Tracking
CREATE TABLE progress.user_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users.users(id) ON DELETE CASCADE,
    course_id UUID REFERENCES education.courses(id) ON DELETE CASCADE,
    lesson_id UUID REFERENCES education.lessons(id) ON DELETE CASCADE,
    status ENUM('not_started','in_progress','completed','skipped') DEFAULT 'not_started',
    completion_percentage DECIMAL(5,2) DEFAULT 0,
    time_spent_seconds INTEGER DEFAULT 0,
    last_accessed TIMESTAMP,
    completed_at TIMESTAMP,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, lesson_id)
);

-- Partition by month for scalability
CREATE TABLE progress.activity_log (
    id UUID DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    action VARCHAR(100) NOT NULL,
    entity_type VARCHAR(50),
    entity_id UUID,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

-- Create partitions
CREATE TABLE progress.activity_log_2025_01 PARTITION OF progress.activity_log
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
-- Continue monthly...
```

### 2. Content Storage System

#### 2.1 Content Management Database
```yaml
# deployment/databases/content/content-mgmt.yaml
name: hma-content-db
configuration:
  git_repository:
    primary: GitHub/GitLab
    lfs: enabled
    webhooks: enabled
    
  metadata_store: PostgreSQL 15
  databases:
    - hma_content_metadata
    - hma_content_versions
    - hma_content_assets
```

#### Content Storage Schema
```sql
-- Content Metadata Database
CREATE SCHEMA content_mgmt;
CREATE SCHEMA assets;
CREATE SCHEMA versions;

-- Content Registry
CREATE TABLE content_mgmt.content_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_type ENUM('lesson','article','video','audio','document','interactive'),
    pillar_id UUID,
    course_id UUID,
    lesson_id UUID,
    title VARCHAR(500) NOT NULL,
    slug VARCHAR(255) NOT NULL,
    description TEXT,
    author_id UUID,
    reviewer_id UUID,
    status ENUM('draft','review','approved','published','archived') DEFAULT 'draft',
    version VARCHAR(20) DEFAULT '1.0.0',
    git_commit_hash VARCHAR(40),
    file_path TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    published_at TIMESTAMP,
    UNIQUE(content_type, slug)
);

-- Media Assets Management
CREATE TABLE assets.media_library (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    filename VARCHAR(500) NOT NULL,
    original_name VARCHAR(500),
    mime_type VARCHAR(100),
    file_size BIGINT,
    storage_path TEXT NOT NULL,
    cdn_url TEXT,
    thumbnail_url TEXT,
    checksum VARCHAR(64),
    dimensions JSONB, -- {width, height, duration, etc}
    metadata JSONB DEFAULT '{}',
    optimization_status ENUM('pending','processing','optimized','failed') DEFAULT 'pending',
    usage_count INTEGER DEFAULT 0,
    created_by UUID,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Content Versions
CREATE TABLE versions.content_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID REFERENCES content_mgmt.content_items(id),
    version_number VARCHAR(20) NOT NULL,
    git_commit_hash VARCHAR(40),
    change_type ENUM('major','minor','patch','hotfix'),
    change_summary TEXT,
    changed_by UUID,
    diff_stats JSONB, -- {additions, deletions, modifications}
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(content_id, version_number)
);

-- Content Translations
CREATE TABLE content_mgmt.translations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID REFERENCES content_mgmt.content_items(id),
    language_code VARCHAR(10) NOT NULL,
    title VARCHAR(500),
    description TEXT,
    content_path TEXT,
    translator_id UUID,
    reviewer_id UUID,
    status ENUM('pending','in_progress','review','approved','published') DEFAULT 'pending',
    quality_score DECIMAL(3,2),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(content_id, language_code)
);
```

#### 2.2 Object Storage Configuration
```yaml
# deployment/storage/s3-config.yaml
buckets:
  # Educational Content
  - name: hma-content-{environment}
    versioning: enabled
    lifecycle:
      - videos:
          transition_to_ia: 90 days
          transition_to_glacier: 365 days
      - documents:
          transition_to_ia: 180 days
    replication:
      production: cross-region to us-west-2
    
  # User Generated Content
  - name: hma-ugc-{environment}
    versioning: enabled
    lifecycle:
      - user_uploads:
          expire: 90 days if not accessed
    cors: enabled
    
  # Media Assets (CDN Origin)
  - name: hma-media-{environment}
    cloudfront:
      enabled: true
      cache_behaviors:
        - path: /videos/*
          ttl: 86400
        - path: /images/*
          ttl: 604800
```

### 3. Field Operations Databases

#### 3.1 Field Data Platform
```sql
-- Field Operations Database with PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

CREATE SCHEMA field_ops;
CREATE SCHEMA locations;
CREATE SCHEMA wildlife;

-- Hunt Planning
CREATE TABLE field_ops.hunt_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users.users(id),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    planned_date DATE,
    location GEOGRAPHY(POINT, 4326),
    boundaries GEOGRAPHY(POLYGON, 4326),
    participants UUID[] DEFAULT '{}',
    weather_conditions JSONB,
    strategy_notes TEXT,
    success_probability DECIMAL(3,2),
    status ENUM('draft','active','completed','cancelled') DEFAULT 'draft',
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Wildlife Tracking
CREATE TABLE wildlife.sightings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    species VARCHAR(255) NOT NULL,
    count INTEGER DEFAULT 1,
    location GEOGRAPHY(POINT, 4326) NOT NULL,
    accuracy_meters DECIMAL(8,2),
    observed_at TIMESTAMP NOT NULL,
    behavior_notes TEXT,
    media_ids UUID[] DEFAULT '{}',
    weather_data JSONB,
    moon_phase DECIMAL(3,2),
    confidence ENUM('certain','likely','possible'),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create spatial indices
CREATE INDEX idx_hunt_plans_location ON field_ops.hunt_plans USING GIST(location);
CREATE INDEX idx_hunt_plans_boundaries ON field_ops.hunt_plans USING GIST(boundaries);
CREATE INDEX idx_sightings_location ON wildlife.sightings USING GIST(location);
CREATE INDEX idx_sightings_species_time ON wildlife.sightings(species, observed_at DESC);

-- Mobile Sync Queue
CREATE TABLE field_ops.sync_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    device_id VARCHAR(255) NOT NULL,
    user_id UUID NOT NULL,
    operation ENUM('create','update','delete'),
    entity_type VARCHAR(100),
    entity_id UUID,
    payload JSONB,
    sync_status ENUM('pending','processing','completed','failed') DEFAULT 'pending',
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    processed_at TIMESTAMP
);
```

#### 3.2 Mobile Database (SQLite/Room)
```kotlin
// Mobile app local database schema
@Database(
    entities = [
        User::class,
        OfflineContent::class,
        Location::class,
        Sighting::class,
        SyncRecord::class
    ],
    version = 1,
    exportSchema = true
)
@TypeConverters(Converters::class)
abstract class HMAFieldDatabase : RoomDatabase() {
    abstract fun userDao(): UserDao
    abstract fun contentDao(): ContentDao
    abstract fun locationDao(): LocationDao
    abstract fun sightingDao(): SightingDao
    abstract fun syncDao(): SyncDao
}

@Entity(tableName = "offline_content")
data class OfflineContent(
    @PrimaryKey val id: String,
    val type: String,
    val title: String,
    val data: String, // JSON
    val lastUpdated: Long,
    val expiresAt: Long?
)

@Entity(tableName = "sync_records")
data class SyncRecord(
    @PrimaryKey val id: String,
    val entityType: String,
    val entityId: String,
    val operation: String,
    val payload: String,
    val status: String,
    val createdAt: Long,
    val syncedAt: Long?
)
```

### 4. AI/ML Databases

#### 4.1 Vector Database for AI
```yaml
# deployment/databases/ai/vector-db.yaml
name: hma-vector-db
configuration:
  type: pgvector on PostgreSQL 15
  alternatives:
    - Qdrant (dedicated vector DB)
    - Chroma (embedded option)
    - Pinecone (managed service)
    
  capacity:
    alpha: 2 vCPU, 8GB RAM
    beta: 4 vCPU, 16GB RAM
    production: 8 vCPU, 32GB RAM, autoscaling
```

```sql
-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

CREATE SCHEMA embeddings;
CREATE SCHEMA ml_models;

-- Content Embeddings for Semantic Search
CREATE TABLE embeddings.content_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content_id UUID NOT NULL,
    content_type VARCHAR(50),
    embedding vector(1536), -- OpenAI ada-002 dimensions
    model_version VARCHAR(50),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMP DEFAULT NOW()
);

-- User Embeddings for Personalization
CREATE TABLE embeddings.user_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    embedding_type VARCHAR(50), -- 'interests', 'skills', 'behavior'
    embedding vector(768), -- BERT dimensions
    model_version VARCHAR(50),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create vector similarity indices
CREATE INDEX idx_content_embedding ON embeddings.content_embeddings 
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

CREATE INDEX idx_user_embedding ON embeddings.user_embeddings 
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 50);

-- ML Model Registry
CREATE TABLE ml_models.model_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    version VARCHAR(50) NOT NULL,
    type ENUM('classification','regression','nlp','cv','audio'),
    framework ENUM('tensorflow','pytorch','onnx','custom'),
    pillar VARCHAR(100),
    artifacts JSONB, -- S3 paths, checksums
    metrics JSONB, -- accuracy, f1, etc
    config JSONB,
    status ENUM('training','validating','staging','production','retired'),
    created_at TIMESTAMP DEFAULT NOW(),
    deployed_at TIMESTAMP,
    UNIQUE(name, version)
);
```

### 5. Social Platform Database

```sql
-- Social Features Database
CREATE SCHEMA social;
CREATE SCHEMA notifications;

-- Social Graph
CREATE TABLE social.follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID REFERENCES users.users(id) ON DELETE CASCADE,
    following_id UUID REFERENCES users.users(id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(follower_id, following_id),
    CHECK (follower_id != following_id)
);

-- User Generated Content
CREATE TABLE social.posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users.users(id) ON DELETE CASCADE,
    type ENUM('text','photo','video','achievement','hunt_log'),
    content TEXT,
    media_urls TEXT[] DEFAULT '{}',
    location GEOGRAPHY(POINT, 4326),
    privacy ENUM('public','followers','private') DEFAULT 'followers',
    tags TEXT[] DEFAULT '{}',
    like_count INTEGER DEFAULT 0,
    comment_count INTEGER DEFAULT 0,
    share_count INTEGER DEFAULT 0,
    is_edited BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Real-time Notifications
CREATE TABLE notifications.notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recipient_id UUID REFERENCES users.users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255),
    message TEXT,
    data JSONB DEFAULT '{}',
    read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create indices for performance
CREATE INDEX idx_posts_user_created ON social.posts(user_id, created_at DESC);
CREATE INDEX idx_posts_tags ON social.posts USING GIN(tags);
CREATE INDEX idx_notifications_recipient ON notifications.notifications(recipient_id, read, created_at DESC);
```

### 6. Cache Layer (Redis)

```yaml
# deployment/cache/redis-config.yaml
redis_clusters:
  # Session Management
  - name: hma-sessions
    purpose: user sessions, auth tokens
    configuration:
      alpha: single node, 2GB
      beta: master-replica, 4GB
      production: cluster mode, 16GB, 6 nodes
    eviction: allkeys-lru
    persistence: AOF
    
  # Application Cache
  - name: hma-cache
    purpose: api responses, computed data
    configuration:
      alpha: single node, 4GB
      beta: master-replica, 8GB
      production: cluster mode, 32GB, 6 nodes
    eviction: allkeys-lfu
    persistence: RDB snapshots
    
  # Real-time Features
  - name: hma-realtime
    purpose: websocket, notifications, presence
    configuration:
      alpha: single node, 1GB
      beta: master-replica, 2GB
      production: cluster mode, 8GB, 3 nodes
    eviction: volatile-ttl
    persistence: disabled
    
  # Queue Management
  - name: hma-queues
    purpose: job queues, task scheduling
    configuration:
      alpha: single node, 2GB
      beta: master-replica, 4GB
      production: cluster mode, 8GB, 3 nodes
    eviction: noeviction
    persistence: AOF + RDB
```

---

## Migration Strategy: Alpha → Beta → Production

### Phase 1: Alpha Environment Setup

#### Initial Deployment (Week 1-2)
```bash
#!/bin/bash
# deploy-alpha.sh

# 1. Create Alpha RDS Instance
aws rds create-db-cluster \
  --db-cluster-identifier hma-alpha-cluster \
  --engine aurora-postgresql \
  --engine-version 15.4 \
  --master-username hmaadmin \
  --master-user-password $ALPHA_DB_PASSWORD \
  --database-name hma_alpha \
  --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=1

# 2. Initialize Schema
psql -h hma-alpha-cluster.cluster-xxxxx.amazonaws.com \
  -U hmaadmin -d hma_alpha \
  -f migrations/001_create_schemas.sql \
  -f migrations/002_create_users.sql \
  -f migrations/003_create_education.sql

# 3. Deploy Redis
aws elasticache create-cache-cluster \
  --cache-cluster-id hma-alpha-cache \
  --engine redis \
  --cache-node-type cache.t3.micro \
  --num-cache-nodes 1

# 4. Create S3 Buckets
aws s3 mb s3://hma-content-alpha
aws s3 mb s3://hma-media-alpha
aws s3 mb s3://hma-ugc-alpha

# 5. Seed Test Data
python scripts/seed_alpha_data.py
```

#### Alpha Data Seeding
```python
# scripts/seed_alpha_data.py
import asyncio
import asyncpg
from faker import Faker
import random

async def seed_alpha_database():
    conn = await asyncpg.connect(
        'postgresql://hmaadmin:password@hma-alpha-cluster/hma_alpha'
    )
    
    fake = Faker()
    
    # Create test users
    users = []
    for i in range(100):
        user_id = await conn.fetchval("""
            INSERT INTO users.users (email, first_name, last_name, role)
            VALUES ($1, $2, $3, $4)
            RETURNING id
        """, 
        f"test{i}@huntmaster.academy",
        fake.first_name(),
        fake.last_name(),
        random.choice(['student', 'student', 'instructor'])
        )
        users.append(user_id)
    
    # Create test content
    pillars = ['game_calls', 'hunt_strategy', 'stealth_scouting', 
               'tracking_recovery', 'gear_marksmanship']
    
    for pillar in pillars:
        pillar_id = await conn.fetchval("""
            INSERT INTO education.pillars (slug, name, description)
            VALUES ($1, $2, $3)
            RETURNING id
        """, pillar, pillar.replace('_', ' ').title(), 
        f"Master the art of {pillar.replace('_', ' ')}")
        
        # Create courses
        for course_num in range(3):
            course_id = await conn.fetchval("""
                INSERT INTO education.courses 
                (pillar_id, slug, title, difficulty_level)
                VALUES ($1, $2, $3, $4)
                RETURNING id
            """,
            pillar_id,
            f"{pillar}-course-{course_num}",
            f"{pillar.replace('_', ' ').title()} Course {course_num + 1}",
            random.choice(['beginner', 'intermediate', 'advanced'])
            )
            
            # Create lessons
            for lesson_num in range(5):
                await conn.execute("""
                    INSERT INTO education.lessons 
                    (course_id, slug, title, content_type, duration_minutes)
                    VALUES ($1, $2, $3, $4, $5)
                """,
                course_id,
                f"lesson-{lesson_num}",
                f"Lesson {lesson_num + 1}: {fake.sentence()}",
                random.choice(['video', 'text', 'interactive']),
                random.randint(10, 45)
                )
    
    await conn.close()
    print("Alpha environment seeded successfully!")

asyncio.run(seed_alpha_database())
```

### Phase 2: Beta Migration Strategy

#### Migration Plan (Week 3-4)
```yaml
# migration/alpha-to-beta.yaml
migration_strategy:
  approach: blue-green deployment
  
  steps:
    1_create_beta_infrastructure:
      - Create Beta RDS cluster (larger capacity)
      - Set up read replicas
      - Configure automated backups
      
    2_schema_migration:
      - Apply schema changes via migrations
      - Add new indices for performance
      - Create partitions for large tables
      
    3_data_migration:
      method: logical replication
      tools:
        - AWS DMS for initial load
        - pg_logical for ongoing sync
      validation:
        - Row count verification
        - Checksum validation
        - Sample data comparison
      
    4_cutover:
      - Enable read-only mode on Alpha
      - Final sync of changes
      - Update application configs
      - Switch traffic to Beta
      
    5_validation:
      - Run smoke tests
      - Verify data integrity
      - Monitor performance metrics
      
    rollback_plan:
      - Keep Alpha running for 48 hours
      - Maintain reverse replication
      - One-click rollback capability
```

#### Beta Migration Script
```python
# migration/migrate_alpha_to_beta.py
import asyncio
import asyncpg
import logging
from datetime import datetime

class AlphaToBetaMigration:
    def __init__(self):
        self.alpha_conn = None
        self.beta_conn = None
        self.logger = logging.getLogger(__name__)
        
    async def connect(self):
        self.alpha_conn = await asyncpg.connect(
            'postgresql://hmaadmin@hma-alpha-cluster/hma_alpha'
        )
        self.beta_conn = await asyncpg.connect(
            'postgresql://hmaadmin@hma-beta-cluster/hma_beta'
        )
    
    async def migrate_users(self):
        """Migrate user data with validation"""
        self.logger.info("Starting user migration...")
        
        # Get users from Alpha
        users = await self.alpha_conn.fetch("""
            SELECT * FROM users.users
            ORDER BY created_at
        """)
        
        # Batch insert to Beta
        await self.beta_conn.executemany("""
            INSERT INTO users.users 
            (id, email, username, first_name, last_name, role, 
             preferences, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            ON CONFLICT (id) DO UPDATE SET
                updated_at = EXCLUDED.updated_at
        """, [
            (u['id'], u['email'], u['username'], u['first_name'],
             u['last_name'], u['role'], u['preferences'],
             u['created_at'], u['updated_at'])
            for u in users
        ])
        
        # Validate migration
        alpha_count = await self.alpha_conn.fetchval(
            "SELECT COUNT(*) FROM users.users"
        )
        beta_count = await self.beta_conn.fetchval(
            "SELECT COUNT(*) FROM users.users"
        )
        
        if alpha_count != beta_count:
            raise Exception(f"User count mismatch: Alpha={alpha_count}, Beta={beta_count}")
        
        self.logger.info(f"Migrated {beta_count} users successfully")
    
    async def migrate_content(self):
        """Migrate educational content"""
        # Similar pattern for content migration
        pass
    
    async def migrate_progress(self):
        """Migrate user progress data"""
        # Partition-aware migration
        pass
    
    async def verify_migration(self):
        """Run comprehensive validation checks"""
        checks = []
        
        # Check row counts
        tables = [
            'users.users',
            'users.profiles',
            'education.courses',
            'education.lessons',
            'progress.user_progress'
        ]
        
        for table in tables:
            alpha_count = await self.alpha_conn.fetchval(
                f"SELECT COUNT(*) FROM {table}"
            )
            beta_count = await self.beta_conn.fetchval(
                f"SELECT COUNT(*) FROM {table}"
            )
            
            checks.append({
                'table': table,
                'alpha_count': alpha_count,
                'beta_count': beta_count,
                'match': alpha_count == beta_count
            })
        
        return all(c['match'] for c in checks), checks
    
    async def run(self):
        try:
            await self.connect()
            
            # Run migrations in order
            await self.migrate_users()
            await self.migrate_content()
            await self.migrate_progress()
            
            # Verify
            success, checks = await self.verify_migration()
            
            if success:
                self.logger.info("Migration completed successfully!")
            else:
                self.logger.error(f"Migration validation failed: {checks}")
                raise Exception("Migration validation failed")
                
        finally:
            if self.alpha_conn:
                await self.alpha_conn.close()
            if self.beta_conn:
                await self.beta_conn.close()

# Run migration
asyncio.run(AlphaToBetaMigration().run())
```

### Phase 3: Production Deployment

#### Production Migration Strategy (Week 5-6)
```yaml
# migration/beta-to-production.yaml
production_deployment:
  strategy: zero-downtime migration
  
  infrastructure:
    database:
      - Multi-AZ Aurora PostgreSQL cluster
      - 3 read replicas across regions
      - Auto-scaling enabled (2-16 ACUs)
      
    caching:
      - Redis cluster mode (6 nodes)
      - Separate clusters for sessions/cache/queues
      
    storage:
      - S3 with cross-region replication
      - CloudFront CDN for media delivery
      
  migration_steps:
    1_pre_migration:
      - Full backup of Beta environment
      - Create production infrastructure
      - Set up monitoring and alerts
      - Load test production environment
      
    2_data_sync:
      - Set up logical replication from Beta
      - Initial data copy (off-peak hours)
      - Continuous CDC replication
      
    3_validation:
      - Data integrity checks
      - Performance benchmarking
      - Security scanning
      
    4_gradual_rollout:
      - 5% traffic to production (canary)
      - Monitor metrics for 2 hours
      - 25% traffic if stable
      - 50% traffic after 24 hours
      - 100% traffic after 48 hours
      
    5_post_migration:
      - Monitor for 7 days
      - Optimize indices and queries
      - Update documentation
```

#### Production Deployment Automation
```python
# deployment/deploy_production.py
import boto3
import time
from typing import Dict, List
import yaml

class ProductionDeployment:
    def __init__(self):
        self.rds = boto3.client('rds')
        self.elasticache = boto3.client('elasticache')
        self.s3 = boto3.client('s3')
        self.cloudfront = boto3.client('cloudfront')
        
    def create_production_database(self) -> str:
        """Create production Aurora cluster"""
        response = self.rds.create_db_cluster(
            DBClusterIdentifier='hma-production-cluster',
            Engine='aurora-postgresql',
            EngineVersion='15.4',
            MasterUsername='hmaadmin',
            MasterUserPassword=self.get_secret('prod/db/password'),
            DatabaseName='hma_production',
            ServerlessV2ScalingConfiguration={
                'MinCapacity': 2,
                'MaxCapacity': 16
            },
            StorageEncrypted=True,
            KmsKeyId=self.get_kms_key(),
            EnableCloudwatchLogsExports=['postgresql'],
            DeletionProtection=True,
            BackupRetentionPeriod=35,
            PreferredBackupWindow='03:00-04:00',
            PreferredMaintenanceWindow='mon:04:00-mon:05:00',
            Tags=[
                {'Key': 'Environment', 'Value': 'production'},
                {'Key': 'Application', 'Value': 'HMA'},
                {'Key': 'CostCenter', 'Value': 'Engineering'}
            ]
        )
        
        # Wait for cluster to be available
        waiter = self.rds.get_waiter('db_cluster_available')
        waiter.wait(DBClusterIdentifier='hma-production-cluster')
        
        # Create read replicas
        self.create_read_replicas()
        
        return response['DBCluster']['Endpoint']
    
    def create_read_replicas(self):
        """Create read replicas in multiple regions"""
        regions = ['us-west-2', 'eu-west-1']
        
        for region in regions:
            self.rds.create_db_cluster_read_replica(
                DBClusterIdentifier=f'hma-production-replica-{region}',
                SourceDBClusterIdentifier='hma-production-cluster',
                Tags=[
                    {'Key': 'Environment', 'Value': 'production'},
                    {'Key': 'Type', 'Value': 'read-replica'}
                ]
            )
    
    def setup_redis_clusters(self) -> Dict[str, str]:
        """Create Redis clusters for different purposes"""
        clusters = {}
        
        configs = {
            'sessions': {
                'CacheNodeType': 'cache.r6g.xlarge',
                'NumNodeGroups': 3,
                'ReplicasPerNodeGroup': 1
            },
            'cache': {
                'CacheNodeType': 'cache.r6g.2xlarge',
                'NumNodeGroups': 3,
                'ReplicasPerNodeGroup': 2
            },
            'queues': {
                'CacheNodeType': 'cache.r6g.large',
                'NumNodeGroups': 2,
                'ReplicasPerNodeGroup': 1
            }
        }
        
        for name, config in configs.items():
            response = self.elasticache.create_replication_group(
                ReplicationGroupId=f'hma-prod-{name}',
                ReplicationGroupDescription=f'HMA Production {name.title()}',
                Engine='redis',
                CacheNodeType=config['CacheNodeType'],
                NumNodeGroups=config['NumNodeGroups'],
                ReplicasPerNodeGroup=config['ReplicasPerNodeGroup'],
                AutomaticFailoverEnabled=True,
                MultiAZEnabled=True,
                AtRestEncryptionEnabled=True,
                TransitEncryptionEnabled=True,
                SnapshotRetentionLimit=7,
                Tags=[
                    {'Key': 'Environment', 'Value': 'production'},
                    {'Key': 'Purpose', 'Value': name}
                ]
            )
            
            clusters[name] = response['ReplicationGroup']['ConfigurationEndpoint']['Address']
        
        return clusters
    
    def create_s3_buckets(self):
        """Create S3 buckets with proper configuration"""
        buckets = [
            'hma-content-production',
            'hma-media-production',
            'hma-ugc-production',
            'hma-backups-production'
        ]
        
        for bucket in buckets:
            # Create bucket
            self.s3.create_bucket(
                Bucket=bucket,
                CreateBucketConfiguration={'LocationConstraint': 'us-east-1'}
            )
            
            # Enable versioning
            self.s3.put_bucket_versioning(
                Bucket=bucket,
                VersioningConfiguration={'Status': 'Enabled'}
            )
            
            # Enable encryption
            self.s3.put_bucket_encryption(
                Bucket=bucket,
                ServerSideEncryptionConfiguration={
                    'Rules': [{
                        'ApplyServerSideEncryptionByDefault': {
                            'SSEAlgorithm': 'aws:kms',
                            'KMSMasterKeyID': self.get_kms_key()
                        }
                    }]
                }
            )
            
            # Set up lifecycle policies
            self.setup_s3_lifecycle(bucket)
            
            # Enable cross-region replication for critical buckets
            if 'content' in bucket or 'media' in bucket:
                self.setup_s3_replication(bucket)
    
    def setup_cloudfront(self) -> str:
        """Create CloudFront distribution for media delivery"""
        response = self.cloudfront.create_distribution(
            DistributionConfig={
                'CallerReference': str(time.time()),
                'Origins': {
                    'Quantity': 1,
                    'Items': [{
                        'Id': 'S3-hma-media-production',
                        'DomainName': 'hma-media-production.s3.amazonaws.com',
                        'S3OriginConfig': {
                            'OriginAccessIdentity': self.get_oai()
                        }
                    }]
                },
                'DefaultCacheBehavior': {
                    'TargetOriginId': 'S3-hma-media-production',
                    'ViewerProtocolPolicy': 'redirect-to-https',
                    'AllowedMethods': {
                        'Quantity': 2,
                        'Items': ['GET', 'HEAD'],
                        'CachedMethods': {
                            'Quantity': 2,
                            'Items': ['GET', 'HEAD']
                        }
                    },
                    'Compress': True,
                    'CachePolicyId': self.get_cache_policy()
                },
                'Comment': 'HMA Production Media CDN',
                'Enabled': True,
                'PriceClass': 'PriceClass_100',
                'ViewerCertificate': {
                    'ACMCertificateArn': self.get_ssl_cert(),
                    'SSLSupportMethod': 'sni-only'
                },
                'Aliases': {
                    'Quantity': 1,
                    'Items': ['cdn.huntmaster.academy']
                }
            }
        )
        
        return response['Distribution']['DomainName']
    
    def validate_deployment(self) -> bool:
        """Run validation checks on production deployment"""
        checks = []
        
        # Check database cluster
        db_response = self.rds.describe_db_clusters(
            DBClusterIdentifier='hma-production-cluster'
        )
        checks.append({
            'service': 'RDS',
            'status': db_response['DBClusters'][0]['Status'] == 'available'
        })
        
        # Check Redis clusters
        for cluster_type in ['sessions', 'cache', 'queues']:
            redis_response = self.elasticache.describe_replication_groups(
                ReplicationGroupId=f'hma-prod-{cluster_type}'
            )
            checks.append({
                'service': f'Redis-{cluster_type}',
                'status': redis_response['ReplicationGroups'][0]['Status'] == 'available'
            })
        
        # Check S3 buckets
        buckets = self.s3.list_buckets()
        prod_buckets = [b for b in buckets['Buckets'] 
                       if 'hma' in b['Name'] and 'production' in b['Name']]
        checks.append({
            'service': 'S3',
            'status': len(prod_buckets) >= 4
        })
        
        return all(c['status'] for c in checks), checks

# Execute deployment
if __name__ == "__main__":
    deployer = ProductionDeployment()
    
    print("Creating production database cluster...")
    db_endpoint = deployer.create_production_database()
    
    print("Setting up Redis clusters...")
    redis_endpoints = deployer.setup_redis_clusters()
    
    print("Creating S3 buckets...")
    deployer.create_s3_buckets()
    
    print("Setting up CloudFront CDN...")
    cdn_domain = deployer.setup_cloudfront()
    
    print("Validating deployment...")
    success, checks = deployer.validate_deployment()
    
    if success:
        print("Production deployment completed successfully!")
        print(f"Database endpoint: {db_endpoint}")
        print(f"Redis endpoints: {redis_endpoints}")
        print(f"CDN domain: {cdn_domain}")
    else:
        print(f"Deployment validation failed: {checks}")
```

---

## Monitoring & Maintenance

### Database Monitoring Setup
```sql
-- Create monitoring schema
CREATE SCHEMA monitoring;

-- Database statistics view
CREATE VIEW monitoring.database_stats AS
SELECT 
    current_database() as database_name,
    pg_database_size(current_database()) as size_bytes,
    (SELECT count(*) FROM pg_stat_activity) as active_connections,
    (SELECT count(*) FROM pg_stat_activity WHERE state = 'active') as active_queries,
    (SELECT max(now() - xact_start) FROM pg_stat_activity WHERE state = 'active') as longest_query_time,
    (SELECT count(*) FROM pg_stat_user_tables) as table_count,
    (SELECT sum(n_tup_ins + n_tup_upd + n_tup_del) FROM pg_stat_user_tables) as total_dml_operations,
    now() as collected_at;

-- Slow query tracking
CREATE TABLE monitoring.slow_queries (
    id SERIAL PRIMARY KEY,
    query_text TEXT,
    duration_ms INTEGER,
    user_name VARCHAR(100),
    database_name VARCHAR(100),
    application_name VARCHAR(255),
    client_addr INET,
    captured_at TIMESTAMP DEFAULT NOW()
);

-- Table growth tracking
CREATE TABLE monitoring.table_growth (
    id SERIAL PRIMARY KEY,
    schema_name VARCHAR(100),
    table_name VARCHAR(100),
    row_count BIGINT,
    total_size_bytes BIGINT,
    index_size_bytes BIGINT,
    toast_size_bytes BIGINT,
    captured_at TIMESTAMP DEFAULT NOW()
);

-- Automated monitoring job
CREATE OR REPLACE FUNCTION monitoring.capture_table_stats()
RETURNS void AS $$
BEGIN
    INSERT INTO monitoring.table_growth 
    (schema_name, table_name, row_count, total_size_bytes, 
     index_size_bytes, toast_size_bytes)
    SELECT 
        schemaname,
        tablename,
        n_live_tup,
        pg_total_relation_size(schemaname||'.'||tablename),
        pg_indexes_size(schemaname||'.'||tablename),
        pg_total_relation_size(schemaname||'.'||tablename) - 
            pg_relation_size(schemaname||'.'||tablename) - 
            pg_indexes_size(schemaname||'.'||tablename)
    FROM pg_stat_user_tables;
END;
$$ LANGUAGE plpgsql;

-- Schedule monitoring job
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule('capture-table-stats', '0 * * * *', 
    'SELECT monitoring.capture_table_stats()');
```

### Backup and Recovery Procedures
```bash
#!/bin/bash
# backup-production.sh

# Configuration
ENVIRONMENT=${1:-production}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/${ENVIRONMENT}"
S3_BUCKET="hma-backups-${ENVIRONMENT}"

# Backup PostgreSQL
echo "Starting PostgreSQL backup..."
pg_dump \
    -h hma-${ENVIRONMENT}-cluster.cluster-xxxxx.amazonaws.com \
    -U hmaadmin \
    -d hma_${ENVIRONMENT} \
    --format=custom \
    --verbose \
    --file=${BACKUP_DIR}/postgres_${TIMESTAMP}.dump

# Backup Redis
echo "Starting Redis backup..."
redis-cli -h hma-${ENVIRONMENT}-cache.xxxxx.cache.amazonaws.com BGSAVE
redis-cli -h hma-${ENVIRONMENT}-cache.xxxxx.cache.amazonaws.com --rdb ${BACKUP_DIR}/redis_${TIMESTAMP}.rdb

# Upload to S3
echo "Uploading to S3..."
aws s3 cp ${BACKUP_DIR}/ s3://${S3_BUCKET}/${TIMESTAMP}/ \
    --recursive \
    --storage-class GLACIER_IR

# Verify backup
echo "Verifying backup..."
pg_restore --list ${BACKUP_DIR}/postgres_${TIMESTAMP}.dump > /dev/null
if [ $? -eq 0 ]; then
    echo "Backup verified successfully"
else
    echo "Backup verification failed!"
    exit 1
fi

# Clean old backups (keep last 30 days)
find ${BACKUP_DIR} -type f -mtime +30 -delete

echo "Backup completed: ${TIMESTAMP}"
```

---

## Security Considerations

### Data Encryption
```yaml
encryption_strategy:
  at_rest:
    postgresql:
      - AWS KMS encryption for RDS
      - Encrypted EBS volumes
      
    redis:
      - At-rest encryption enabled
      - Encrypted snapshots
      
    s3:
      - SSE-KMS for all buckets
      - Bucket policies enforce encryption
      
  in_transit:
    postgresql:
      - SSL/TLS required for all connections
      - Certificate validation
      
    redis:
      - TLS 1.2+ for all connections
      - AUTH required
      
    api:
      - HTTPS only
      - TLS 1.3 preferred
      
  application_level:
    - Field-level encryption for PII
    - Tokenization for sensitive data
    - Key rotation every 90 days
```

### Access Control
```sql
-- Role-based access control
CREATE ROLE readonly;
GRANT CONNECT ON DATABASE hma_production TO readonly;
GRANT USAGE ON SCHEMA users, education, progress TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA users, education, progress TO readonly;

CREATE ROLE readwrite;
GRANT CONNECT ON DATABASE hma_production TO readwrite;
GRANT USAGE, CREATE ON SCHEMA users, education, progress TO readwrite;
GRANT ALL ON ALL TABLES IN SCHEMA users, education, progress TO readwrite;

CREATE ROLE admin;
GRANT ALL PRIVILEGES ON DATABASE hma_production TO admin;

-- Create users with appropriate roles
CREATE USER app_reader WITH PASSWORD 'secure_password';
GRANT readonly TO app_reader;

CREATE USER app_writer WITH PASSWORD 'secure_password';
GRANT readwrite TO app_writer;

CREATE USER app_admin WITH PASSWORD 'secure_password';
GRANT admin TO app_admin;
```

---

## Success Metrics & KPIs

### Database Performance Metrics
- Query response time: P95 < 100ms
- Connection pool efficiency: > 90%
- Cache hit ratio: > 95%
- Replication lag: < 1 second
- Backup success rate: 100%
- Recovery time objective (RTO): < 1 hour
- Recovery point objective (RPO): < 5 minutes

### Data Quality Metrics
- Data consistency across services: > 99.9%
- Schema migration success rate: 100%
- Data validation pass rate: > 99.99%
- Duplicate record rate: < 0.01%

### Operational Metrics
- Deployment success rate: > 99%
- Rollback frequency: < 1%
- Mean time to recovery (MTTR): < 30 minutes
- Database availability: > 99.99%

---

This comprehensive database deployment and migration strategy ensures Hunt Master Academy has a robust, scalable, and maintainable data infrastructure that can grow from alpha testing through to full production deployment while maintaining data integrity, performance, and security throughout the journey.
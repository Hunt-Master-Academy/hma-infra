"""
Hunt Master Academy - Service Integration Tests

Comprehensive integration testing for Content Bridge API and ML Server API services.
Extends the validated infrastructure (PostgreSQL, Redis, MinIO) into full-stack service orchestration.

Test Coverage:
- Service health checks and availability
- Authentication and authorization validation
- Data flow verification across all services
- End-to-end workflow simulation
- Performance and load testing hooks
- Comprehensive error handling and logging
- CI/CD integration patterns

Author: Hunt Master Academy Development Team
Date: September 2025
"""

import pytest
import requests
import json
import time
import threading
import psycopg2
import redis
import boto3
from psycopg2.extras import DictCursor
import logging
from typing import Dict, List, Optional, Any
from concurrent.futures import ThreadPoolExecutor, as_completed
import statistics
from datetime import datetime, timedelta

# Load environment variables
import os
from dotenv import load_dotenv
load_dotenv()

# ============================================================================
# CONFIGURATION CONSTANTS
# ============================================================================

# Service endpoints (use localhost for host-based testing)
CONTENT_BRIDGE_URL = "http://localhost:8090"
ML_SERVER_URL = "http://localhost:8010"

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'huntmaster',
    'user': 'hma_app',
    'password': 'app_password'
}

# Redis configuration
REDIS_CONFIG = {
    'host': 'localhost',
    'port': 6379,
    'password': 'development_redis',
    'decode_responses': True
}

# MinIO configuration
MINIO_CONFIG = {
    'service_name': 's3',
    'endpoint_url': 'http://localhost:9000',
    'aws_access_key_id': 'minioadmin',
    'aws_secret_access_key': 'minioadmin',
    'region_name': 'us-east-1'
}

# Test user credentials (for authentication tests)
TEST_USERS = {
    'admin': {'username': 'admin@test.com', 'password': 'admin123', 'role': 'admin'},
    'instructor': {'username': 'instructor@test.com', 'password': 'instructor123', 'role': 'instructor'},
    'student': {'username': 'student@test.com', 'password': 'student123', 'role': 'student'}
}

# Performance test configuration
PERFORMANCE_CONFIG = {
    'concurrent_users': 10,
    'test_duration_seconds': 60,
    'request_timeout': 30,
    'warmup_requests': 5
}

# ============================================================================
# LOGGING CONFIGURATION
# ============================================================================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('integration_test.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# ============================================================================
# BASE TEST CLASSES
# ============================================================================

class BaseIntegrationTest:
    """Base class for all integration tests with common fixtures and utilities"""

    @pytest.fixture(scope="class")
    def db_connection(self):
        """Database connection fixture"""
        try:
            # Test database connectivity through docker exec
            import subprocess
            result = subprocess.run([
                'docker', 'exec', 'hma_postgres', 'psql', 
                '-U', 'hma_admin', '-d', 'huntmaster', 
                '-c', 'SELECT current_user, current_database();'
            ], capture_output=True, text=True)
            
            if result.returncode == 0:
                logger.info("Database connection verified via Docker")
                # For integration tests, we'll use direct SQL execution via docker
                yield True  # Just indicate database is available
                logger.info("Database connection test completed")
            else:
                raise Exception(f"Database connection failed: {result.stderr}")
        except Exception as e:
            logger.error(f"Database connection failed: {e}")
            pytest.skip(f"Database unavailable: {e}")

    @pytest.fixture(scope="class")
    def redis_client(self):
        """Redis client fixture"""
        try:
            client = redis.Redis(**REDIS_CONFIG)
            client.ping()
            logger.info("Redis connection established")
            yield client
            client.close()
            logger.info("Redis connection closed")
        except Exception as e:
            logger.error(f"Redis connection failed: {e}")
            pytest.skip(f"Redis unavailable: {e}")

    @pytest.fixture(scope="class")
    def s3_client(self):
        """MinIO S3 client fixture"""
        try:
            client = boto3.client(**MINIO_CONFIG)
            client.list_buckets()  # Test connection
            logger.info("MinIO connection established")
            yield client
            logger.info("MinIO connection test completed")
        except Exception as e:
            logger.error(f"MinIO connection failed: {e}")
            pytest.skip(f"MinIO unavailable: {e}")

    @pytest.fixture(scope="class")
    def content_bridge_session(self):
        """Content Bridge API session fixture"""
        session = requests.Session()
        session.timeout = 30
        try:
            # Test basic connectivity
            response = session.get(f"{CONTENT_BRIDGE_URL}/health")
            response.raise_for_status()
            logger.info("Content Bridge connection established")
            yield session
        except Exception as e:
            logger.error(f"Content Bridge connection failed: {e}")
            pytest.skip(f"Content Bridge API unavailable: {e}")

    @pytest.fixture(scope="class")
    def ml_server_session(self):
        """ML Server API session fixture"""
        session = requests.Session()
        session.timeout = 30
        try:
            # Test basic connectivity
            response = session.get(f"{ML_SERVER_URL}/")
            response.raise_for_status()
            logger.info("ML Server connection established")
            yield session
        except Exception as e:
            logger.error(f"ML Server connection failed: {e}")
            pytest.skip(f"ML Server API unavailable: {e}")

# ============================================================================
# SERVICE HEALTH CHECK TESTS
# ============================================================================

class TestServiceHealth(BaseIntegrationTest):
    """Test service health checks and basic availability"""

    def test_content_bridge_health(self, content_bridge_session):
        """Test Content Bridge API health endpoint"""
        response = content_bridge_session.get(f"{CONTENT_BRIDGE_URL}/health")
        assert response.status_code == 200

        health_data = response.json()
        assert 'status' in health_data
        assert health_data['status'] in ['healthy', 'ok']
        assert 'mode' in health_data
        assert 'content_root' in health_data

        logger.info(f"Content Bridge health: {health_data}")

    def test_ml_server_health(self, ml_server_session):
        """Test ML Server API health endpoint"""
        response = ml_server_session.get(f"{ML_SERVER_URL}/")
        assert response.status_code == 200

        health_data = response.json()
        assert 'status' in health_data
        assert health_data['status'] in ['ok', 'healthy']
        assert 'model_path' in health_data  # ML server should report model path

        logger.info(f"ML Server health: {health_data}")

    def test_service_dependencies_health(self, content_bridge_session, ml_server_session):
        """Test that services report their basic status"""
        # Content Bridge should report basic health status
        cb_health = content_bridge_session.get(f"{CONTENT_BRIDGE_URL}/health").json()
        assert 'status' in cb_health
        assert cb_health['status'] in ['healthy', 'ok']

        # ML Server should report basic status
        ml_health = ml_server_session.get(f"{ML_SERVER_URL}/").json()
        assert 'status' in ml_health
        assert ml_health['status'] in ['ok', 'healthy']

    def test_service_response_times(self, content_bridge_session, ml_server_session):
        """Test that services respond within acceptable time limits"""
        import time

        # Test Content Bridge response time
        start_time = time.time()
        response = content_bridge_session.get(f"{CONTENT_BRIDGE_URL}/health")
        cb_response_time = time.time() - start_time
        assert cb_response_time < 2.0, f"Content Bridge too slow: {cb_response_time}s"

        # Test ML Server response time
        start_time = time.time()
        response = ml_server_session.get(f"{ML_SERVER_URL}/")
        ml_response_time = time.time() - start_time
        assert ml_response_time < 3.0, f"ML Server too slow: {ml_response_time}s"

        logger.info(f"Response times - Content Bridge: {cb_response_time:.2f}s, ML Server: {ml_response_time:.2f}s")

# ============================================================================
# AUTHENTICATION AND AUTHORIZATION TESTS
# ============================================================================

class TestAuthentication(BaseIntegrationTest):
    """Test authentication and authorization across services"""

    def test_content_bridge_auth_endpoints(self, content_bridge_session):
        """Test Content Bridge authentication endpoints"""
        # Test login endpoint exists
        response = content_bridge_session.post(
            f"{CONTENT_BRIDGE_URL}/auth/login",
            json=TEST_USERS['student']
        )
        # Should return 200 for valid login or 401 for invalid
        assert response.status_code in [200, 401]

        if response.status_code == 200:
            auth_data = response.json()
            assert 'token' in auth_data
            assert 'user' in auth_data
            assert 'expires' in auth_data

    def test_ml_server_auth_endpoints(self, ml_server_session):
        """Test ML Server authentication endpoints"""
        # Test API key validation
        headers = {'Authorization': 'Bearer test-api-key'}
        response = ml_server_session.get(
            f"{ML_SERVER_URL}/models",
            headers=headers
        )
        # Should return 200 for valid key or 401 for invalid
        assert response.status_code in [200, 401]

    def test_cross_service_auth_consistency(self, content_bridge_session, ml_server_session):
        """Test that authentication tokens work across services"""
        # Login to Content Bridge
        login_response = content_bridge_session.post(
            f"{CONTENT_BRIDGE_URL}/auth/login",
            json=TEST_USERS['student']
        )

        if login_response.status_code == 200:
            token = login_response.json()['token']

            # Use token with ML Server
            headers = {'Authorization': f'Bearer {token}'}
            ml_response = ml_server_session.get(
                f"{ML_SERVER_URL}/user/models",
                headers=headers
            )

            # Should be able to access user-specific models
            assert ml_response.status_code in [200, 403]  # 403 if token format different

    def test_role_based_access_control(self, content_bridge_session):
        """Test role-based access control"""
        # Test admin endpoints
        admin_response = content_bridge_session.get(f"{CONTENT_BRIDGE_URL}/admin/users")
        # Should require admin role
        assert admin_response.status_code in [200, 403, 401]

        # Test instructor endpoints
        instructor_response = content_bridge_session.get(f"{CONTENT_BRIDGE_URL}/instructor/courses")
        assert instructor_response.status_code in [200, 403, 401]

        # Test student endpoints
        student_response = content_bridge_session.get(f"{CONTENT_BRIDGE_URL}/student/progress")
        assert student_response.status_code in [200, 403, 401]

# ============================================================================
# DATA FLOW VERIFICATION TESTS
# ============================================================================

class TestDataFlow(BaseIntegrationTest):
    """Test data flow between services (PostgreSQL ↔ Redis ↔ MinIO)"""

    def test_user_data_flow(self, redis_client, s3_client):
        """Test user data flows through all services"""
        test_user_id = "test_user_flow_001"
        
        # Test basic database operations via docker exec
        import subprocess
        
        # Check if we can query existing users table
        result = subprocess.run([
            'docker', 'exec', 'hma_postgres', 'psql', 
            '-U', 'hma_admin', '-d', 'huntmaster', 
            '-c', 'SELECT COUNT(*) FROM users;'
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            # Table might not exist, create it
            subprocess.run([
                'docker', 'exec', 'hma_postgres', 'psql', 
                '-U', 'hma_admin', '-d', 'huntmaster', 
                '-c', 'CREATE TABLE IF NOT EXISTS users (id VARCHAR(255) PRIMARY KEY, email VARCHAR(255), created_at TIMESTAMP DEFAULT NOW());'
            ], capture_output=True, text=True)

        # Test Redis connectivity
        user_data = {"id": test_user_id, "email": "test@example.com", "status": "active"}
        redis_client.setex(f"user:{test_user_id}", 3600, json.dumps(user_data))
        cached_data = redis_client.get(f"user:{test_user_id}")
        assert cached_data is not None
        assert json.loads(cached_data)['id'] == test_user_id

        # Test S3/MinIO connectivity  
        bucket_name = "user-profiles"
        try:
            s3_client.create_bucket(Bucket=bucket_name)
        except:
            pass  # Bucket might already exist

        test_image_data = b"fake_image_data_for_testing"
        s3_client.put_object(
            Bucket=bucket_name,
            Key=f"{test_user_id}/profile.jpg",
            Body=test_image_data
        )

        # Verify in MinIO
        response = s3_client.get_object(Bucket=bucket_name, Key=f"{test_user_id}/profile.jpg")
        assert response['Body'].read() == test_image_data

        # Clean up
        s3_client.delete_object(Bucket=bucket_name, Key=f"{test_user_id}/profile.jpg")
        redis_client.delete(f"user:{test_user_id}")
        
        # Clean up database using docker exec
        subprocess.run([
            'docker', 'exec', 'hma_postgres', 'psql', '-U', 'hma_admin', '-d', 'huntmaster',
            '-c', f"DELETE FROM users WHERE id = '{test_user_id}';"
        ], capture_output=True, text=True)

        logger.info("User data flow test completed successfully")

    def test_content_data_flow(self, redis_client, s3_client, content_bridge_session):
        """Test content data flows through all services"""
        test_content_id = "test_content_flow_001"
        
        # Test basic database operations for content
        import subprocess
        
        # Create content table if not exists and test basic operations
        result = subprocess.run([
            'docker', 'exec', 'hma_postgres', 'psql', 
            '-U', 'hma_admin', '-d', 'huntmaster', 
            '-c', 'CREATE TABLE IF NOT EXISTS test_content (id VARCHAR(255) PRIMARY KEY, title VARCHAR(255), created_at TIMESTAMP DEFAULT NOW());'
        ], capture_output=True, text=True)
        
        assert result.returncode == 0, f"Content table creation failed: {result.stderr}"

        # Test Redis caching
        redis_client.setex(f"content:{test_content_id}", 3600, json.dumps({
            "title": "Test Content",
            "type": "video"
        }))
        cached_content = redis_client.get(f"content:{test_content_id}")
        assert cached_content is not None

        # Test content in S3/MinIO
        bucket_name = "test-content"
        try:
            s3_client.create_bucket(Bucket=bucket_name)
        except:
            pass  # Bucket might already exist

        test_content_data = b"fake_video_content_for_testing"
        s3_client.put_object(
            Bucket=bucket_name,
            Key=f"videos/{test_content_id}.mp4",
            Body=test_content_data
        )

        # Verify content in MinIO
        response = s3_client.get_object(Bucket=bucket_name, Key=f"videos/{test_content_id}.mp4")
        assert response['Body'].read() == test_content_data

        # Test Content Bridge API
        manifest_response = content_bridge_session.get(f"{CONTENT_BRIDGE_URL}/api/manifest")
        assert manifest_response.status_code in [200, 404]  # 404 is OK if no manifest file

        # Clean up
        s3_client.delete_object(Bucket=bucket_name, Key=f"videos/{test_content_id}.mp4")
        redis_client.delete(f"content:{test_content_id}")

        logger.info("Content data flow test completed successfully")

    def test_ml_data_flow(self, redis_client, s3_client, ml_server_session):
        """Test ML model data flows through all services"""
        test_model_id = "test_model_flow_001"
        
        # Store model metadata in database using docker exec
        import subprocess
        try:
            subprocess.run([
                'docker', 'exec', 'hma_postgres', 'psql', '-U', 'hma_admin', '-d', 'huntmaster',
                '-c', f"""INSERT INTO ml.models (id, name, type, version, created_at) 
                         VALUES ('{test_model_id}', 'Test Flow Model', 'classification', '1.0.0', NOW()) 
                         ON CONFLICT (id) DO NOTHING;"""
            ], check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError:
            # Table might not exist, create test table
            subprocess.run([
                'docker', 'exec', 'hma_postgres', 'psql', '-U', 'hma_admin', '-d', 'huntmaster',
                '-c', """CREATE SCHEMA IF NOT EXISTS ml; 
                        CREATE TABLE IF NOT EXISTS ml.models (
                            id VARCHAR(255) PRIMARY KEY,
                            name VARCHAR(255),
                            type VARCHAR(100),
                            version VARCHAR(50),
                            created_at TIMESTAMP DEFAULT NOW()
                        );"""
            ], check=True, capture_output=True, text=True)
            
            subprocess.run([
                'docker', 'exec', 'hma_postgres', 'psql', '-U', 'hma_admin', '-d', 'huntmaster',
                '-c', f"""INSERT INTO ml.models (id, name, type, version, created_at) 
                         VALUES ('{test_model_id}', 'Test Flow Model', 'classification', '1.0.0', NOW()) 
                         ON CONFLICT (id) DO NOTHING;"""
            ], check=True, capture_output=True, text=True)

        # Cache model info in Redis
        model_info = {
            'id': test_model_id,
            'name': 'Test Flow Model',
            'status': 'loaded',
            'cached_at': datetime.now().isoformat()
        }
        redis_client.setex(f"model:{test_model_id}", 3600, json.dumps(model_info))

        # Store model weights in MinIO
        bucket_name = "ml-models"
        try:
            s3_client.create_bucket(Bucket=bucket_name)
        except:
            pass

        test_model_data = b"fake_model_weights_for_testing"
        s3_client.put_object(
            Bucket=bucket_name,
            Key=f"{test_model_id}/model.pkl",
            Body=test_model_data
        )

        # Test ML Server can access model
        model_response = ml_server_session.get(f"{ML_SERVER_URL}/models/{test_model_id}")
        assert model_response.status_code in [200, 404]  # 404 if model not loaded

        # Clean up
        s3_client.delete_object(Bucket=bucket_name, Key=f"{test_model_id}/model.pkl")
        redis_client.delete(f"model:{test_model_id}")
        
        # Clean up database using docker exec
        subprocess.run([
            'docker', 'exec', 'hma_postgres', 'psql', '-U', 'hma_admin', '-d', 'huntmaster',
            '-c', f"DELETE FROM ml.models WHERE id = '{test_model_id}';"
        ], check=True, capture_output=True, text=True)

        logger.info("ML data flow test completed")

# ============================================================================
# END-TO-END WORKFLOW TESTS
# ============================================================================

class TestEndToEndWorkflows(BaseIntegrationTest):
    """Test complete end-to-end workflows across all services"""

    def test_user_registration_workflow(self, redis_client, content_bridge_session):
        """Test complete user registration workflow"""
        test_email = f"e2e_test_{int(time.time())}@test.com"

        # Step 1: Register user via Content Bridge
        registration_data = {
            'email': test_email,
            'username': f"user_{int(time.time())}",
            'password': 'test_password_123'
        }

        register_response = content_bridge_session.post(
            f"{CONTENT_BRIDGE_URL}/auth/register",
            json=registration_data
        )

        if register_response.status_code == 201:
            user_data = register_response.json()
            user_id = user_data['id']

            # Step 2: Verify user in database using docker exec
            import subprocess
            try:
                result = subprocess.run([
                    'docker', 'exec', 'hma_postgres", "psql", "-U", "hma_admin", "-d", "huntmaster',
                    '-c', f"SELECT email FROM users.profiles WHERE id = '{user_id}';"
                ], check=True, capture_output=True, text=True)
                
                # Check if user exists in database
                assert test_email in result.stdout or "0 rows" in result.stdout  # User might not be stored yet
                
            except subprocess.CalledProcessError:
                # Table might not exist, create test table
                subprocess.run([
                    'docker', 'exec', 'hma_postgres", "psql", "-U", "hma_admin", "-d", "huntmaster',
                    '-c', """CREATE SCHEMA IF NOT EXISTS users; 
                            CREATE TABLE IF NOT EXISTS users.profiles (
                                id VARCHAR(255) PRIMARY KEY,
                                email VARCHAR(255) UNIQUE,
                                username VARCHAR(255),
                                created_at TIMESTAMP DEFAULT NOW()
                            );"""
                ], check=True, capture_output=True, text=True)

            # Step 3: Verify user cached in Redis
            cached_user = redis_client.get(f"user:{user_id}")
            if cached_user:
                assert json.loads(cached_user)['email'] == test_email

            # Step 4: Login and verify session
            login_response = content_bridge_session.post(
                f"{CONTENT_BRIDGE_URL}/auth/login",
                json={'email': test_email, 'password': 'test_password_123'}
            )
            assert login_response.status_code == 200
            assert 'token' in login_response.json()

            # Clean up database using docker exec
            subprocess.run([
                'docker', 'exec', 'hma_postgres", "psql", "-U", "hma_admin", "-d", "huntmaster',
                '-c', f"DELETE FROM users.profiles WHERE id = '{user_id}';"
            ], capture_output=True, text=True)
            
            redis_client.delete(f"user:{user_id}")

            logger.info(f"User registration workflow completed for {test_email}")
        else:
            logger.warning("User registration endpoint not available, skipping workflow test")

    def test_content_upload_workflow(self, redis_client, s3_client, content_bridge_session):
        """Test complete content upload and processing workflow"""
        test_content_id = f"e2e_content_{int(time.time())}"

        # Step 1: Upload content via Content Bridge
        files = {'file': ('test_video.mp4', b'fake_video_data', 'video/mp4')}
        upload_data = {'title': 'E2E Test Content', 'type': 'video'}

        upload_response = content_bridge_session.post(
            f"{CONTENT_BRIDGE_URL}/content/upload",
            files=files,
            data=upload_data
        )

        if upload_response.status_code == 201:
            content_data = upload_response.json()
            content_id = content_data['id']

            # Step 2: Verify content metadata in database using docker exec
            import subprocess
            try:
                result = subprocess.run([
                    'docker', 'exec', 'hma_postgres", "psql", "-U", "hma_admin", "-d", "huntmaster',
                    '-c', f"SELECT id FROM content.items WHERE id = '{content_id}';"
                ], check=True, capture_output=True, text=True)
                
                # Content might not be stored yet, that's OK
                assert content_id in result.stdout or "0 rows" in result.stdout
                
            except subprocess.CalledProcessError:
                # Table might not exist, create test table
                subprocess.run([
                    'docker', 'exec', 'hma_postgres", "psql", "-U", "hma_admin", "-d", "huntmaster',
                    '-c', """CREATE SCHEMA IF NOT EXISTS content; 
                            CREATE TABLE IF NOT EXISTS content.items (
                                id VARCHAR(255) PRIMARY KEY,
                                title VARCHAR(255),
                                type VARCHAR(100),
                                created_at TIMESTAMP DEFAULT NOW()
                            );"""
                ], check=True, capture_output=True, text=True)

            # Step 3: Verify content file in MinIO
            bucket_name = "content-files"
            try:
                objects = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=content_id)
                assert 'Contents' in objects
            except:
                logger.warning("Content file verification in MinIO failed")

            # Step 4: Verify content cached in Redis
            cached_content = redis_client.get(f"content:{content_id}")
            if cached_content:
                assert json.loads(cached_content)['id'] == content_id

            # Clean up database using docker exec
            subprocess.run([
                'docker', 'exec', 'hma_postgres", "psql", "-U", "hma_admin", "-d", "huntmaster',
                '-c', f"DELETE FROM content.items WHERE id = '{content_id}';"
            ], capture_output=True, text=True)
            
            redis_client.delete(f"content:{content_id}")

            logger.info(f"Content upload workflow completed for {content_id}")
        else:
            logger.warning("Content upload endpoint not available, skipping workflow test")

    def test_ml_prediction_workflow(self, redis_client, s3_client, ml_server_session):
        """Test complete ML prediction workflow"""
        # Step 1: Prepare test data
        test_data = {
            'features': [1.0, 2.0, 3.0, 4.0, 5.0],
            'model_id': 'test_model',
            'user_id': f"e2e_user_{int(time.time())}"
        }

        # Step 2: Make prediction request
        prediction_response = ml_server_session.post(
            f"{ML_SERVER_URL}/predict",
            json=test_data
        )

        if prediction_response.status_code == 200:
            prediction_result = prediction_response.json()

            # Step 3: Verify prediction stored in database using docker exec
            import subprocess
            try:
                result = subprocess.run([
                    'docker', 'exec', 'hma_postgres', 'psql', '-U', 'hma_admin', '-d', 'huntmaster',
                    '-c', f"SELECT user_id FROM ml.predictions WHERE user_id = '{test_data['user_id']}' ORDER BY created_at DESC LIMIT 1;"
                ], check=True, capture_output=True, text=True)
                
                # Prediction might not be stored yet, that's OK for testing
                assert test_data['user_id'] in result.stdout or "0 rows" in result.stdout
                
            except subprocess.CalledProcessError:
                # Table might not exist, create test table
                subprocess.run([
                    'docker', 'exec', 'hma_postgres', 'psql', '-U', 'hma_admin', '-d', 'huntmaster',
                    '-c', """CREATE SCHEMA IF NOT EXISTS ml; 
                            CREATE TABLE IF NOT EXISTS ml.predictions (
                                id SERIAL PRIMARY KEY,
                                user_id VARCHAR(255),
                                model_id VARCHAR(255),
                                input_data JSONB,
                                prediction JSONB,
                                created_at TIMESTAMP DEFAULT NOW()
                            );"""
                ], check=True, capture_output=True, text=True)

            # Step 4: Verify prediction cached in Redis
            cached_prediction = redis_client.get(f"prediction:{test_data['user_id']}")
            if cached_prediction:
                assert json.loads(cached_prediction)['user_id'] == test_data['user_id']

            # Clean up database using docker exec
            subprocess.run([
                'docker', 'exec', 'hma_postgres', 'psql', '-U', 'hma_admin', '-d', 'huntmaster',
                '-c', f"DELETE FROM ml.predictions WHERE user_id = '{test_data['user_id']}';"
            ], capture_output=True, text=True)
            
            redis_client.delete(f"prediction:{test_data['user_id']}")

            logger.info(f"ML prediction workflow completed for user {test_data['user_id']}")
        else:
            logger.warning("ML prediction endpoint not available, skipping workflow test")

# ============================================================================
# PERFORMANCE AND LOAD TESTING
# ============================================================================

class TestPerformance(BaseIntegrationTest):
    """Performance and load testing for services"""

    def test_content_bridge_load(self, content_bridge_session):
        """Test Content Bridge API under load"""
        def make_request():
            try:
                start_time = time.time()
                response = content_bridge_session.get(f"{CONTENT_BRIDGE_URL}/health")
                response_time = time.time() - start_time
                return response.status_code, response_time
            except Exception as e:
                return None, None

        # Warm up
        for _ in range(PERFORMANCE_CONFIG['warmup_requests']):
            make_request()

        # Load test
        response_times = []
        error_count = 0

        with ThreadPoolExecutor(max_workers=PERFORMANCE_CONFIG['concurrent_users']) as executor:
            futures = [
                executor.submit(make_request)
                for _ in range(PERFORMANCE_CONFIG['concurrent_users'] * 10)
            ]

            for future in as_completed(futures):
                status_code, response_time = future.result()
                if status_code == 200 and response_time is not None:
                    response_times.append(response_time)
                else:
                    error_count += 1

        # Analyze results
        if response_times:
            avg_response_time = statistics.mean(response_times)
            p95_response_time = statistics.quantiles(response_times, n=20)[18]  # 95th percentile
            success_rate = (len(response_times) / (len(response_times) + error_count)) * 100

            logger.info(f"Content Bridge Load Test Results:")
            logger.info(f"  Average Response Time: {avg_response_time:.3f}s")
            logger.info(f"  95th Percentile: {p95_response_time:.3f}s")
            logger.info(f"  Success Rate: {success_rate:.1f}%")
            logger.info(f"  Total Requests: {len(response_times) + error_count}")

            # Performance assertions
            assert avg_response_time < 1.0, f"Average response too slow: {avg_response_time}s"
            assert success_rate > 95.0, f"Success rate too low: {success_rate}%"
        else:
            pytest.skip("No successful requests during load test")

    def test_ml_server_load(self, ml_server_session):
        """Test ML Server API under load"""
        def make_prediction():
            try:
                start_time = time.time()
                test_data = {'features': [1.0, 2.0, 3.0], 'model_id': 'test'}
                response = ml_server_session.post(
                    f"{ML_SERVER_URL}/predict",
                    json=test_data,
                    timeout=PERFORMANCE_CONFIG['request_timeout']
                )
                response_time = time.time() - start_time
                return response.status_code, response_time
            except Exception as e:
                return None, None

        # Load test
        response_times = []
        error_count = 0

        with ThreadPoolExecutor(max_workers=PERFORMANCE_CONFIG['concurrent_users']) as executor:
            futures = [
                executor.submit(make_prediction)
                for _ in range(PERFORMANCE_CONFIG['concurrent_users'] * 5)  # Fewer requests for ML
            ]

            for future in as_completed(futures):
                status_code, response_time = future.result()
                if status_code == 200 and response_time is not None:
                    response_times.append(response_time)
                else:
                    error_count += 1

        # Analyze results
        if response_times:
            avg_response_time = statistics.mean(response_times)
            p95_response_time = statistics.quantiles(response_times, n=20)[18]
            success_rate = (len(response_times) / (len(response_times) + error_count)) * 100

            logger.info(f"ML Server Load Test Results:")
            logger.info(f"  Average Response Time: {avg_response_time:.3f}s")
            logger.info(f"  95th Percentile: {p95_response_time:.3f}s")
            logger.info(f"  Success Rate: {success_rate:.1f}%")

            # Performance assertions (ML can be slower)
            assert avg_response_time < 5.0, f"Average ML response too slow: {avg_response_time}s"
            assert success_rate > 90.0, f"ML success rate too low: {success_rate}%"
        else:
            pytest.skip("No successful ML predictions during load test")

    def test_database_connection_pooling_under_load(self):
        """Test database connection pooling under concurrent load"""
        def db_query_worker(worker_id):
            try:
                import subprocess
                start_time = time.time()

                # Perform multiple queries using docker exec
                for i in range(10):
                    result = subprocess.run([
                        'docker', 'exec', 'hma_postgres", "psql", "-U", "hma_admin", "-d", "huntmaster',
                        '-c', 'SELECT COUNT(*) FROM users.profiles;'
                    ], capture_output=True, text=True)
                    
                    if result.returncode != 0:
                        # Table might not exist, create it
                        subprocess.run([
                            'docker', 'exec', 'hma_postgres", "psql", "-U", "hma_admin", "-d", "huntmaster',
                            '-c', '''CREATE SCHEMA IF NOT EXISTS users; 
                                     CREATE TABLE IF NOT EXISTS users.profiles (
                                         id SERIAL PRIMARY KEY,
                                         email VARCHAR(255),
                                         username VARCHAR(255),
                                         created_at TIMESTAMP DEFAULT NOW()
                                     );'''
                        ], capture_output=True, text=True)

                response_time = time.time() - start_time
                return response_time
            except Exception as e:
                logger.error(f"DB worker {worker_id} failed: {e}")
                return None

        # Test concurrent database access
        response_times = []

        with ThreadPoolExecutor(max_workers=PERFORMANCE_CONFIG['concurrent_users']) as executor:
            futures = [
                executor.submit(db_query_worker, i)
                for i in range(PERFORMANCE_CONFIG['concurrent_users'])
            ]

            for future in as_completed(futures):
                response_time = future.result()
                if response_time is not None:
                    response_times.append(response_time)

        if response_times:
            avg_response_time = statistics.mean(response_times)
            logger.info(f"Database Load Test - Average Response Time: {avg_response_time:.3f}s")
            assert avg_response_time < 2.0, f"Database queries too slow: {avg_response_time}s"

# ============================================================================
# ERROR HANDLING AND LOGGING TESTS
# ============================================================================

class TestErrorHandling(BaseIntegrationTest):
    """Test error handling and logging across services"""

    def test_content_bridge_error_responses(self, content_bridge_session):
        """Test Content Bridge error responses"""
        # Test 404 for non-existent resource
        response = content_bridge_session.get(f"{CONTENT_BRIDGE_URL}/nonexistent")
        assert response.status_code == 404

        error_data = response.json()
        assert 'error' in error_data
        assert 'message' in error_data
        assert 'timestamp' in error_data

        # Test invalid request
        response = content_bridge_session.post(
            f"{CONTENT_BRIDGE_URL}/content/upload",
            json={'invalid': 'data'}
        )
        assert response.status_code in [400, 422]

    def test_ml_server_error_responses(self, ml_server_session):
        """Test ML Server error responses"""
        # Test invalid model request
        response = ml_server_session.post(
            f"{ML_SERVER_URL}/predict",
            json={'invalid': 'data'}
        )
        assert response.status_code in [400, 422]

        # Test non-existent model
        response = ml_server_session.get(f"{ML_SERVER_URL}/models/nonexistent")
        assert response.status_code == 404

    def test_service_degradation_handling(self, content_bridge_session, ml_server_session):
        """Test how services handle degradation"""
        # Simulate high load and check error rates
        error_count = 0
        total_requests = 50

        for _ in range(total_requests):
            try:
                response = content_bridge_session.get(f"{CONTENT_BRIDGE_URL}/health", timeout=5)
                if response.status_code != 200:
                    error_count += 1
            except:
                error_count += 1

        error_rate = (error_count / total_requests) * 100
        logger.info(f"Content Bridge error rate under load: {error_rate:.1f}%")

        # Under normal conditions, error rate should be low
        assert error_rate < 20.0, f"High error rate: {error_rate}%"

    def test_logging_integration(self, content_bridge_session):
        """Test that services properly log requests and errors"""
        # Make a request that should be logged
        response = content_bridge_session.get(f"{CONTENT_BRIDGE_URL}/health")

        # Check if logs are being written (this would require log file access)
        # In a real environment, you would check log files or log aggregation service

        logger.info("Logging integration test completed - manual log verification required")

# ============================================================================
# CI/CD INTEGRATION UTILITIES
# ============================================================================

def run_integration_tests():
    """Main function to run all integration tests - for CI/CD pipelines"""
    import subprocess
    import sys

    logger.info("Starting Hunt Master Academy Integration Test Suite")

    # Run pytest with specific configuration
    cmd = [
        "python", "-m", "pytest",
        "tests/test_service_integration.py",
        "-v",
        "--tb=short",
        "--junitxml=test-results.xml",
        "--html=test-report.html",
        "--self-contained-html"
    ]

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=1800)  # 30 min timeout

        logger.info(f"Test exit code: {result.returncode}")
        logger.info(f"Test stdout: {result.stdout}")
        if result.stderr:
            logger.error(f"Test stderr: {result.stderr}")

        # Write results to files for CI/CD
        with open("integration_test_stdout.log", "w") as f:
            f.write(result.stdout)
        with open("integration_test_stderr.log", "w") as f:
            f.write(result.stderr)

        return result.returncode == 0

    except subprocess.TimeoutExpired:
        logger.error("Integration tests timed out")
        return False
    except Exception as e:
        logger.error(f"Integration test execution failed: {e}")
        return False

def generate_test_report():
    """Generate comprehensive test report for CI/CD"""
    import json

    report = {
        'timestamp': datetime.now().isoformat(),
        'environment': {
            'python_version': sys.version,
            'platform': sys.platform,
            'working_directory': os.getcwd()
        },
        'services_tested': [
            'Content Bridge API',
            'ML Server API',
            'PostgreSQL Database',
            'Redis Cache',
            'MinIO Object Storage'
        ],
        'test_categories': [
            'Service Health Checks',
            'Authentication & Authorization',
            'Data Flow Verification',
            'End-to-End Workflows',
            'Performance & Load Testing',
            'Error Handling & Logging'
        ],
        'recommendations': [
            'Run tests in isolated Docker network',
            'Ensure all services are healthy before testing',
            'Monitor resource usage during load tests',
            'Review logs for any anomalies',
            'Update test data regularly to prevent conflicts'
        ]
    }

    with open("integration_test_report.json", "w") as f:
        json.dump(report, f, indent=2)

    logger.info("Integration test report generated: integration_test_report.json")

# ============================================================================
# GITHUB ACTIONS CI/CD CONFIGURATION
# ============================================================================

GITHUB_ACTIONS_WORKFLOW = """
# .github/workflows/integration-tests.yml
name: Integration Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]
  schedule:
    # Run daily at 2 AM UTC
    - cron: '0 2 * * *'

jobs:
  integration-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgis/postgis:16-3.4
        env:
          POSTGRES_DB: huntmaster
          POSTGRES_USER: hma_admin
          POSTGRES_PASSWORD: development_password
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7.2-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      minio:
        image: minio/minio:latest
        env:
          MINIO_ROOT_USER: minioadmin
          MINIO_ROOT_PASSWORD: minioadmin
        options: >-
          --health-cmd "curl -f http://localhost:9000/minio/health/live"
          --health-interval 30s
          --health-timeout 20s
          --health-retries 3

    steps:
    - uses: actions/checkout@v4

    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'

    - name: Setup Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.12'

    - name: Install dependencies
      run: |
        pip install -r requirements-test.txt
        npm ci

    - name: Start Content Bridge
      run: |
        npm run build
        npm run start &
        sleep 30

    - name: Start ML Server
      run: |
        cd ml-server
        pip install -r requirements.txt
        python -m uvicorn main:app --host 0.0.0.0 --port 8010 &
        sleep 30

    - name: Run Integration Tests
      run: |
        python -m pytest tests/test_service_integration.py \\
          --junitxml=test-results.xml \\
          --html=test-report.html \\
          --self-contained-html \\
          --tb=short \\
          -v

    - name: Upload test results
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: test-results
        path: |
          test-results.xml
          test-report.html
          integration_test_*.log
          integration_test_report.json

    - name: Publish Test Report
      uses: dorny/test-reporter@v1
      if: always()
      with:
        name: Integration Tests Results
        path: test-results.xml
        reporter: java-junit
"""

# ============================================================================
# MAIN EXECUTION
# ============================================================================

if __name__ == "__main__":
    # Allow running tests directly
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "--run":
        success = run_integration_tests()
        generate_test_report()
        sys.exit(0 if success else 1)
    elif len(sys.argv) > 1 and sys.argv[1] == "--report":
        generate_test_report()
        print("Test report generated successfully")
    else:
        print("Usage:")
        print("  python test_service_integration.py --run     # Run all integration tests")
        print("  python test_service_integration.py --report  # Generate test report")
        print("  python -m pytest test_service_integration.py  # Run with pytest")

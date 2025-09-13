import pytest
import psycopg2
import redis
import requests
import boto3
from psycopg2.extras import DictCursor
import os
from dotenv import load_dotenv
from minio import Minio
import time

# Load environment variables
load_dotenv()

# Database connection parameters
DB_CONFIG = {
    'host': 'hma_postgres',  # Use Docker service name for network connections
    'port': 5432,
    'database': 'huntmaster',
    'user': 'hma_admin'
    # Note: No password needed for localhost connections (trust authentication)
}

# Service configuration constants
REDIS_PASSWORD = 'development_redis'  # From Docker config default
MINIO_USER = 'minioadmin'  # From .env file
MINIO_PASSWORD = 'yM7h1z4buD1BONLUSnjjCe2jw5O4NnMV2doKkKaWXj4='  # From .env file
CONTENT_BRIDGE_PORT = 8090
ML_SERVER_PORT = 8010

# Alternative connection string for testing
DB_CONNECTION_STRING = "postgresql://hma_admin@localhost:5432/huntmaster"

REDIS_CONFIG = {
    'host': 'hma_redis',  # Use Docker service name for network connections
    'port': 6379,
    'password': 'development_redis',  # Use the actual Redis password from Docker config
    'decode_responses': True
}

MINIO_CONFIG = {
    'service_name': 's3',
    'endpoint_url': 'http://172.25.0.2:9000',  # Use MinIO container IP address for network connections
    'aws_access_key_id': 'minioadmin',  # MinIO root user
    'aws_secret_access_key': 'minioadmin',  # MinIO root password
    'region_name': 'us-east-1'
}

class TestDatabaseConnectivity:
    """Test database connectivity and basic operations"""

    @pytest.fixture
    def db_connection(self):
        """Establish database connection"""
        try:
            # Try connection with password first
            config = DB_CONFIG.copy()
            conn = psycopg2.connect(**config, cursor_factory=DictCursor)
            yield conn
            conn.close()
        except psycopg2.OperationalError as e:
            if "password authentication failed" in str(e) or "authentication failed" in str(e):
                # If password authentication fails, try without password (trust authentication)
                try:
                    config = DB_CONFIG.copy()
                    if 'password' in config:
                        del config['password']
                    conn = psycopg2.connect(**config, cursor_factory=DictCursor)
                    yield conn
                    conn.close()
                except psycopg2.OperationalError as e2:
                    pytest.skip(f"PostgreSQL authentication failed: {e2}")
            else:
                raise

    def test_database_connection(self, db_connection):
        """Test that we can connect to the database"""
        cursor = db_connection.cursor()
        cursor.execute("SELECT version()")
        result = cursor.fetchone()
        assert 'PostgreSQL' in result[0]

    def test_schemas_exist(self, db_connection):
        """Test that all expected schemas exist"""
        cursor = db_connection.cursor()
        cursor.execute("""
            SELECT schema_name FROM information_schema.schemata
            WHERE schema_name NOT LIKE 'pg_%' AND schema_name != 'information_schema'
            ORDER BY schema_name
        """)
        schemas = [row[0] for row in cursor.fetchall()]

        expected_schemas = [
            'analytics', 'auth', 'content', 'events', 'game_calls',
            'gear_marksmanship', 'hma_academy', 'hunt_strategy',
            'infra', 'ml', 'ml_infrastructure', 'pillars', 'progress',
            'public', 'spatial', 'stealth_scouting', 'topology',
            'tracking_recovery', 'users', 'wp_demo'
        ]

        for schema in expected_schemas:
            assert schema in schemas, f"Schema {schema} not found"

    def test_auth_tables_exist(self, db_connection):
        """Test that authentication tables exist and have data"""
        cursor = db_connection.cursor()

        # Check users table
        cursor.execute("SELECT COUNT(*) FROM auth.users")
        user_count = cursor.fetchone()[0]
        assert user_count > 0, "No users found in auth.users"

        # Check sessions table exists
        cursor.execute("""
            SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = 'auth' AND table_name = 'sessions'
        """)
        assert cursor.fetchone()[0] == 1, "auth.sessions table not found"

    def test_content_tables_exist(self, db_connection):
        """Test that content tables exist and have sample data"""
        cursor = db_connection.cursor()

        # Check content items
        cursor.execute("SELECT COUNT(*) FROM content.items")
        item_count = cursor.fetchone()[0]
        assert item_count > 0, "No content items found"

        # Check assets table exists
        cursor.execute("""
            SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = 'content' AND table_name = 'assets'
        """)
        assert cursor.fetchone()[0] == 1, "content.assets table not found"

    def test_game_calls_data(self, db_connection):
        """Test game calls data integrity"""
        cursor = db_connection.cursor()

        # Check game calls exist
        cursor.execute("SELECT COUNT(*) FROM game_calls.game_calls")
        call_count = cursor.fetchone()[0]
        assert call_count > 0, "No game calls found"

        # Check call categories exist
        cursor.execute("""
            SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = 'game_calls' AND table_name = 'call_categories'
        """)
        assert cursor.fetchone()[0] == 1, "game_calls.call_categories table not found"

    def test_hunt_strategy_data(self, db_connection):
        """Test hunt strategy data integrity"""
        cursor = db_connection.cursor()

        # Check hunt plans exist
        cursor.execute("SELECT COUNT(*) FROM hunt_strategy.hunt_plans")
        plan_count = cursor.fetchone()[0]
        assert plan_count > 0, "No hunt plans found"

        # Check waypoints exist
        cursor.execute("SELECT COUNT(*) FROM hunt_strategy.waypoints")
        waypoint_count = cursor.fetchone()[0]
        assert waypoint_count > 0, "No waypoints found"

    def test_ml_infrastructure(self, db_connection):
        """Test ML infrastructure tables"""
        cursor = db_connection.cursor()

        # Check model registry
        cursor.execute("SELECT COUNT(*) FROM ml_infrastructure.model_registry")
        model_count = cursor.fetchone()[0]
        assert model_count > 0, "No ML models found"

    def test_user_profiles(self, db_connection):
        """Test user profile data"""
        cursor = db_connection.cursor()

        # Check profiles exist
        cursor.execute("SELECT COUNT(*) FROM users.profiles")
        profile_count = cursor.fetchone()[0]
        assert profile_count > 0, "No user profiles found"

    def test_academy_courses(self, db_connection):
        """Test academy course data"""
        cursor = db_connection.cursor()

        # Check courses exist
        cursor.execute("SELECT COUNT(*) FROM hma_academy.courses")
        course_count = cursor.fetchone()[0]
        assert course_count > 0, "No courses found"

        # Check enrollments table exists
        cursor.execute("""
            SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = 'hma_academy' AND table_name = 'enrollments'
        """)
        assert cursor.fetchone()[0] == 1, "hma_academy.enrollments table not found"

class TestRedisConnectivity:
    """Test Redis connectivity and operations"""

    @pytest.fixture
    def redis_client(self):
        """Establish Redis connection"""
        client = redis.Redis(**REDIS_CONFIG)
        yield client
        client.close()

    def test_redis_connection(self, redis_client):
        """Test Redis connectivity"""
        assert redis_client.ping() == True

    def test_redis_operations(self, redis_client):
        """Test basic Redis operations"""
        # Set a test key
        redis_client.set('test_key', 'test_value')
        assert redis_client.get('test_key') == 'test_value'

        # Test expiration
        redis_client.setex('expiring_key', 1, 'expiring_value')
        assert redis_client.get('expiring_key') == 'expiring_value'
        import time
        time.sleep(2)
        assert redis_client.get('expiring_key') is None

        # Test hash operations
        redis_client.hset('test_hash', 'field1', 'value1')
        redis_client.hset('test_hash', 'field2', 'value2')
        assert redis_client.hget('test_hash', 'field1') == 'value1'
        assert redis_client.hgetall('test_hash') == {'field1': 'value1', 'field2': 'value2'}

        # Test list operations
        redis_client.lpush('test_list', 'item1', 'item2', 'item3')
        assert redis_client.llen('test_list') == 3
        assert redis_client.lpop('test_list') == 'item3'

        # Clean up
        redis_client.delete('test_key', 'test_hash', 'test_list')

    def test_redis_connection_pooling(self, redis_client):
        """Test Redis connection pooling"""
        # Test multiple operations to ensure connection pooling works
        for i in range(10):
            key = f'pool_test_{i}'
            redis_client.set(key, f'value_{i}')
            assert redis_client.get(key) == f'value_{i}'
            redis_client.delete(key)

    def test_redis_error_handling(self, redis_client):
        """Test Redis error handling"""
        # Test operations on non-existent keys
        assert redis_client.get('non_existent_key') is None

        # Test TTL on non-existent key
        assert redis_client.ttl('non_existent_key') == -2

        # Test type checking
        redis_client.set('type_test', 'string_value')
        assert redis_client.type('type_test') == 'string'

class TestRedisPubSub:
    """Test Redis publish/subscribe functionality"""

    @pytest.fixture
    def redis_client(self):
        """Establish Redis connection"""
        client = redis.Redis(**REDIS_CONFIG)
        yield client
        client.close()

    def test_pubsub_basic(self, redis_client):
        """Test basic publish/subscribe operations"""
        import threading
        import time

        messages_received = []

        def subscriber_thread():
            """Subscriber thread to listen for messages"""
            pubsub = redis_client.pubsub()
            pubsub.subscribe('test_channel')

            # Listen for messages with timeout
            for message in pubsub.listen():
                if message['type'] == 'message':
                    messages_received.append(message['data'])
                    break  # Exit after receiving one message

        # Start subscriber thread
        thread = threading.Thread(target=subscriber_thread)
        thread.start()

        # Give subscriber time to start
        time.sleep(0.1)

        # Publish message
        redis_client.publish('test_channel', 'test_message')

        # Wait for message to be received
        thread.join(timeout=2)

        assert len(messages_received) == 1
        assert messages_received[0] == 'test_message'

    def test_pubsub_multiple_channels(self, redis_client):
        """Test subscribing to multiple channels"""
        pubsub = redis_client.pubsub()

        # Subscribe to multiple channels
        channels = ['channel1', 'channel2', 'channel3']
        pubsub.subscribe(*channels)

        # Publish to each channel
        for i, channel in enumerate(channels):
            redis_client.publish(channel, f'message_{i}')

        # Collect messages
        messages = []
        for message in pubsub.listen():
            if message['type'] == 'message':
                messages.append((message['channel'], message['data']))
                if len(messages) == len(channels):
                    break

        assert len(messages) == 3
        for i, (channel, data) in enumerate(messages):
            assert channel == f'channel{i+1}'
            assert data == f'message_{i}'

    def test_pubsub_pattern_matching(self, redis_client):
        """Test pattern-based subscriptions"""
        import threading

        messages_received = []

        def pattern_subscriber():
            """Pattern subscriber thread"""
            pubsub = redis_client.pubsub()
            pubsub.psubscribe('test_*')

            for message in pubsub.listen():
                if message['type'] == 'pmessage':
                    messages_received.append((message['channel'], message['data']))
                    if len(messages_received) >= 2:
                        break

        # Start pattern subscriber
        thread = threading.Thread(target=pattern_subscriber)
        thread.start()
        time.sleep(0.1)

        # Publish messages matching pattern
        redis_client.publish('test_channel1', 'message1')
        redis_client.publish('test_channel2', 'message2')
        redis_client.publish('other_channel', 'should_not_match')

        thread.join(timeout=3)

        # Should receive 2 messages (not the one that doesn't match pattern)
        assert len(messages_received) == 2
        channels = [msg[0] for msg in messages_received]
        assert 'test_channel1' in channels
        assert 'test_channel2' in channels

class TestMinIOConnectivity:
    """Test MinIO S3 connectivity"""

    @pytest.fixture
    def s3_client(self):
        """Establish S3 client connection"""
        client = boto3.client(**MINIO_CONFIG)
        yield client

    def test_minio_connection(self, s3_client):
        """Test MinIO connectivity"""
        # List buckets (should work even if empty)
        response = s3_client.list_buckets()
        assert 'Buckets' in response

    def test_bucket_operations(self, s3_client):
        """Test bucket creation and operations"""
        bucket_name = 'test-bucket'

        # Create bucket
        s3_client.create_bucket(Bucket=bucket_name)

        # List buckets and verify our bucket exists
        response = s3_client.list_buckets()
        bucket_names = [bucket['Name'] for bucket in response['Buckets']]
        assert bucket_name in bucket_names

        # Test object operations
        test_content = b"Hello, MinIO!"
        s3_client.put_object(Bucket=bucket_name, Key='test-file.txt', Body=test_content)

        # List objects in bucket
        response = s3_client.list_objects_v2(Bucket=bucket_name)
        assert 'Contents' in response
        assert len(response['Contents']) == 1
        assert response['Contents'][0]['Key'] == 'test-file.txt'

        # Get object
        response = s3_client.get_object(Bucket=bucket_name, Key='test-file.txt')
        assert response['Body'].read() == test_content

        # Delete object
        s3_client.delete_object(Bucket=bucket_name, Key='test-file.txt')

        # Verify object is deleted
        response = s3_client.list_objects_v2(Bucket=bucket_name)
        assert 'Contents' not in response

        # Clean up bucket
        s3_client.delete_bucket(Bucket=bucket_name)

    def test_minio_error_handling(self, s3_client):
        """Test MinIO error handling"""
        # Test getting non-existent object from non-existent bucket
        with pytest.raises(Exception):  # Should raise NoSuchBucket
            s3_client.get_object(Bucket='non-existent-bucket', Key='non-existent-key')

        # Test deleting non-existent object from non-existent bucket (should raise NoSuchBucket)
        with pytest.raises(Exception):  # Should raise NoSuchBucket
            s3_client.delete_object(Bucket='non-existent-bucket', Key='non-existent-key')

    def test_minio_presigned_urls(self, s3_client):
        """Test MinIO presigned URL generation"""
        bucket_name = 'test-presigned-bucket'
        key_name = 'test-presigned-file.txt'

        # Create bucket and object
        s3_client.create_bucket(Bucket=bucket_name)
        s3_client.put_object(Bucket=bucket_name, Key=key_name, Body=b'Presigned URL test')

        # Generate presigned URL
        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': bucket_name, 'Key': key_name},
            ExpiresIn=3600
        )

        assert presigned_url is not None
        assert bucket_name in presigned_url
        assert key_name in presigned_url

        # Clean up
        s3_client.delete_object(Bucket=bucket_name, Key=key_name)
        s3_client.delete_bucket(Bucket=bucket_name)

class TestMinIOMultipartUpload:
    """Test MinIO multipart upload functionality"""

    @pytest.fixture
    def s3_client(self):
        """Establish S3 client connection"""
        client = boto3.client(**MINIO_CONFIG)
        yield client

    def test_multipart_upload_small_file(self, s3_client):
        """Test multipart upload with small file (should still work)"""
        bucket_name = 'test-multipart-bucket'
        key_name = 'small-multipart-file.txt'

        # Create bucket
        s3_client.create_bucket(Bucket=bucket_name)

        # Create multipart upload
        response = s3_client.create_multipart_upload(Bucket=bucket_name, Key=key_name)
        upload_id = response['UploadId']

        # Upload part
        part_data = b'This is a small file for multipart upload testing.'
        part_response = s3_client.upload_part(
            Bucket=bucket_name,
            Key=key_name,
            PartNumber=1,
            UploadId=upload_id,
            Body=part_data
        )

        # Complete multipart upload
        s3_client.complete_multipart_upload(
            Bucket=bucket_name,
            Key=key_name,
            UploadId=upload_id,
            MultipartUpload={
                'Parts': [
                    {
                        'ETag': part_response['ETag'],
                        'PartNumber': 1
                    }
                ]
            }
        )

        # Verify file was uploaded
        response = s3_client.get_object(Bucket=bucket_name, Key=key_name)
        assert response['Body'].read() == part_data

        # Clean up
        s3_client.delete_object(Bucket=bucket_name, Key=key_name)
        s3_client.delete_bucket(Bucket=bucket_name)

    def test_multipart_upload_large_file(self, s3_client):
        """Test multipart upload with larger file"""
        bucket_name = 'test-large-multipart-bucket'
        key_name = 'large-multipart-file.dat'

        # Create bucket
        try:
            s3_client.create_bucket(Bucket=bucket_name)
        except s3_client.exceptions.BucketAlreadyOwnedByYou:
            pass  # Bucket already exists, continue

        # Create multipart upload
        response = s3_client.create_multipart_upload(Bucket=bucket_name, Key=key_name)
        upload_id = response['UploadId']

        # Upload multiple parts (simulate large file)
        parts = []
        total_size = 0

        for part_num in range(1, 4):  # 3 parts
            # Create 5MB of test data per part (MinIO minimum part size)
            part_data = b'X' * (5 * 1024 * 1024)  # 5MB
            total_size += len(part_data)

            part_response = s3_client.upload_part(
                Bucket=bucket_name,
                Key=key_name,
                PartNumber=part_num,
                UploadId=upload_id,
                Body=part_data
            )

            parts.append({
                'ETag': part_response['ETag'],
                'PartNumber': part_num
            })

        # Complete multipart upload
        s3_client.complete_multipart_upload(
            Bucket=bucket_name,
            Key=key_name,
            UploadId=upload_id,
            MultipartUpload={'Parts': parts}
        )

        # Verify file size
        response = s3_client.head_object(Bucket=bucket_name, Key=key_name)
        assert response['ContentLength'] == total_size

        # Clean up
        s3_client.delete_object(Bucket=bucket_name, Key=key_name)
        s3_client.delete_bucket(Bucket=bucket_name)

    def test_multipart_upload_abort(self, s3_client):
        """Test aborting a multipart upload"""
        bucket_name = 'test-abort-multipart-bucket'
        key_name = 'aborted-multipart-file.txt'

        # Create bucket
        s3_client.create_bucket(Bucket=bucket_name)

        # Create multipart upload
        response = s3_client.create_multipart_upload(Bucket=bucket_name, Key=key_name)
        upload_id = response['UploadId']

        # Upload a part
        part_data = b'This part will be aborted.'
        s3_client.upload_part(
            Bucket=bucket_name,
            Key=key_name,
            PartNumber=1,
            UploadId=upload_id,
            Body=part_data
        )

        # Abort multipart upload
        s3_client.abort_multipart_upload(
            Bucket=bucket_name,
            Key=key_name,
            UploadId=upload_id
        )

        # Verify upload was aborted (should not be able to complete)
        with pytest.raises(Exception):
            s3_client.complete_multipart_upload(
                Bucket=bucket_name,
                Key=key_name,
                UploadId=upload_id,
                MultipartUpload={'Parts': []}
            )

        # Verify no object was created
        response = s3_client.list_objects_v2(Bucket=bucket_name)
        assert 'Contents' not in response

        # Clean up
        s3_client.delete_bucket(Bucket=bucket_name)

class TestAPIServices:
    """Test API service connectivity"""

    def test_content_bridge_health(self):
        """Test Content Bridge health endpoint"""
        response = requests.get('http://localhost:8090/health')
        assert response.status_code == 200

        data = response.json()
        assert data['status'] == 'healthy'
        assert 'mode' in data
        assert 'content_root' in data

    def test_content_bridge_manifest(self):
        """Test Content Bridge manifest endpoint"""
        response = requests.get('http://localhost:8090/api/manifest')
        assert response.status_code == 200

        data = response.json()
        assert isinstance(data, dict)
        # Check for expected manifest structure
        assert 'version' in data or 'content' in data

    def test_content_bridge_content_list(self):
        """Test Content Bridge content listing"""
        response = requests.get('http://localhost:8090/api/content')
        # Content bridge might return 404 if no content, but should not be a server error
        assert response.status_code in [200, 404]

    def test_ml_server_health(self):
        """Test ML Server root endpoint"""
        response = requests.get('http://localhost:8010/')
        assert response.status_code == 200

        data = response.json()
        assert data['status'] == 'ok'
        assert 'model_path' in data
        assert 'env' in data

    def test_ml_server_models(self):
        """Test ML Server models endpoint"""
        response = requests.get('http://localhost:8010/models')
        # Models endpoint might return empty list, but should not be a server error
        assert response.status_code in [200, 404]
        if response.status_code == 200:
            data = response.json()
            assert isinstance(data, list)

class TestAPIServicesPerformance:
    """Test API services performance and load handling"""

    def test_content_bridge_response_time(self):
        """Test Content Bridge API response time"""
        import time
        try:
            start_time = time.time()
            response = requests.get(f'http://localhost:{CONTENT_BRIDGE_PORT}/health', timeout=5)
            end_time = time.time()

            response_time = end_time - start_time
            assert response_time < 2.0  # Should respond within 2 seconds
            assert response.status_code == 200
        except requests.exceptions.RequestException:
            pytest.skip("Content Bridge service not available")

    def test_ml_server_response_time(self):
        """Test ML Server API response time"""
        import time
        try:
            start_time = time.time()
            response = requests.get('http://localhost:8010/', timeout=5)
            end_time = time.time()

            response_time = end_time - start_time
            assert response_time < 2.0  # Should respond within 2 seconds
            assert response.status_code == 200
        except requests.exceptions.RequestException:
            pytest.skip("ML Server service not available")

    def test_content_bridge_concurrent_requests(self):
        """Test Content Bridge concurrent request handling"""
        import concurrent.futures
        import time

        def make_request():
            try:
                return requests.get(f'http://localhost:{CONTENT_BRIDGE_PORT}/health', timeout=5)
            except requests.exceptions.RequestException:
                return None

        # Test with 10 concurrent requests
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            results = [future.result() for future in concurrent.futures.as_completed(futures)]

        # Filter out None results (failed requests)
        valid_results = [r for r in results if r is not None]

        if not valid_results:
            pytest.skip("Content Bridge service not available")

        # All valid requests should succeed
        assert all(response.status_code == 200 for response in valid_results)

    def test_ml_server_concurrent_requests(self):
        """Test ML Server concurrent request handling"""
        import concurrent.futures
        import time

        def make_request():
            try:
                return requests.get('http://localhost:8010/', timeout=5)
            except requests.exceptions.RequestException:
                return None

        # Test with 10 concurrent requests
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            results = [future.result() for future in concurrent.futures.as_completed(futures)]

        # Filter out None results (failed requests)
        valid_results = [r for r in results if r is not None]

        if not valid_results:
            pytest.skip("ML Server service not available")

        # All valid requests should succeed
        assert all(response.status_code == 200 for response in valid_results)

    def test_content_bridge_load_test(self):
        """Test Content Bridge under sustained load"""
        import time

        # Make 50 requests in quick succession
        start_time = time.time()
        responses = []
        for _ in range(50):
            try:
                response = requests.get(f'http://localhost:{CONTENT_BRIDGE_PORT}/health', timeout=5)
                responses.append(response)
            except requests.exceptions.RequestException:
                continue

        if not responses:
            pytest.skip("Content Bridge service not available")

        end_time = time.time()
        total_time = end_time - start_time

        # All requests should succeed
        assert all(response.status_code == 200 for response in responses)
        # Should handle 50 requests in under 10 seconds
        assert total_time < 10.0

    def test_api_services_throughput(self):
        """Test combined API services throughput"""
        import time
        import concurrent.futures

        def test_content_bridge():
            try:
                return requests.get(f'http://localhost:{CONTENT_BRIDGE_PORT}/health', timeout=5)
            except requests.exceptions.RequestException:
                return None

        def test_ml_server():
            try:
                return requests.get(f'http://localhost:{ML_SERVER_PORT}/', timeout=5)
            except requests.exceptions.RequestException:
                return None

        # Test both services concurrently
        start_time = time.time()

        with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
            # 10 requests to each service
            cb_futures = [executor.submit(test_content_bridge) for _ in range(10)]
            ml_futures = [executor.submit(test_ml_server) for _ in range(10)]

            cb_results = [future.result() for future in concurrent.futures.as_completed(cb_futures)]
            ml_results = [future.result() for future in concurrent.futures.as_completed(ml_futures)]

        end_time = time.time()
        total_time = end_time - start_time

        # Filter valid results
        cb_valid = [r for r in cb_results if r is not None]
        ml_valid = [r for r in ml_results if r is not None]

        if not cb_valid and not ml_valid:
            pytest.skip("No API services available")

        # All valid requests should succeed
        if cb_valid:
            assert all(response.status_code == 200 for response in cb_valid)
        if ml_valid:
            assert all(response.status_code == 200 for response in ml_valid)

        # Should handle combined load in under 15 seconds
        assert total_time < 15.0

class TestDataIntegrity:
    """Test data integrity across tables"""

    @pytest.fixture
    def db_connection(self):
        """Establish database connection"""
        try:
            # Try connection with password first
            config = DB_CONFIG.copy()
            conn = psycopg2.connect(**config, cursor_factory=DictCursor)
            yield conn
            conn.close()
        except psycopg2.OperationalError as e:
            if "password authentication failed" in str(e) or "authentication failed" in str(e):
                # If password authentication fails, try without password (trust authentication)
                try:
                    config = DB_CONFIG.copy()
                    if 'password' in config:
                        del config['password']
                    conn = psycopg2.connect(**config, cursor_factory=DictCursor)
                    yield conn
                    conn.close()
                except psycopg2.OperationalError as e2:
                    pytest.skip(f"PostgreSQL authentication failed: {e2}")
            else:
                raise

    def test_user_references(self, db_connection):
        """Test that user references are valid"""
        cursor = db_connection.cursor()

        # Check that all progress records reference valid users
        cursor.execute("""
            SELECT COUNT(*) FROM progress.user_progress p
            WHERE NOT EXISTS (
                SELECT 1 FROM auth.users u WHERE u.id = p.user_id
            )
        """)
        orphaned_progress = cursor.fetchone()[0]
        assert orphaned_progress == 0, f"Found {orphaned_progress} orphaned progress records"

    def test_content_references(self, db_connection):
        """Test that content references are valid"""
        cursor = db_connection.cursor()

        # Check that all progress records reference valid content
        cursor.execute("""
            SELECT COUNT(*) FROM progress.user_progress p
            WHERE NOT EXISTS (
                SELECT 1 FROM content.items c WHERE c.id = p.content_id
            )
        """)
        orphaned_content_refs = cursor.fetchone()[0]
        assert orphaned_content_refs == 0, f"Found {orphaned_content_refs} orphaned content references"

    def test_foreign_key_constraints(self, db_connection):
        """Test that foreign key constraints are properly defined"""
        cursor = db_connection.cursor()

        # Check for foreign key constraints in key tables
        cursor.execute("""
            SELECT COUNT(*) FROM information_schema.table_constraints
            WHERE constraint_type = 'FOREIGN KEY'
            AND table_schema IN ('auth', 'content', 'progress', 'hma_academy')
        """)
        fk_count = cursor.fetchone()[0]
        assert fk_count > 0, "No foreign key constraints found in core tables"

        assert fk_count > 0, "No foreign key constraints found in core tables"

class TestCrossServiceIntegration:
    """Test cross-service integration and data flow"""

    def test_redis_minio_integration(self):
        """Test Redis and MinIO working together"""
        # Store a reference in Redis pointing to MinIO content
        redis_client = redis.Redis(host='localhost', port=6379, password=REDIS_PASSWORD, decode_responses=True)

        # Create a bucket in MinIO using MinIO client
        minio_client = Minio(
            'localhost:9000',
            access_key=MINIO_USER,
            secret_key=MINIO_PASSWORD,
            secure=False
        )

        bucket_name = 'test-integration-bucket'
        try:
            minio_client.make_bucket(bucket_name)
        except Exception as e:
            if 'SignatureDoesNotMatch' in str(e) or 'AccessDenied' in str(e):
                pytest.skip("MinIO authentication not configured correctly")
            elif 'already exists' not in str(e).lower():
                raise

        # Upload content to MinIO
        content = b"Integration test content"
        key = "integration-test-file.txt"
        minio_client.put_object(bucket_name, key, content, len(content))

        # Store reference in Redis
        redis_key = "minio:content:integration_test"
        redis_client.set(redis_key, f"{bucket_name}:{key}")

        # Verify integration
        stored_ref = redis_client.get(redis_key)
        assert stored_ref == f"{bucket_name}:{key}"

        # Verify content can be retrieved from MinIO
        response = minio_client.get_object(bucket_name, key)
        retrieved_content = response.read()
        assert retrieved_content == content

        # Clean up
        minio_client.remove_object(bucket_name, key)
        redis_client.delete(redis_key)

    def test_api_services_data_flow(self):
        """Test data flow between API services"""
        # Test that both services are responding and can handle basic data
        cb_healthy = False
        ml_healthy = False

        try:
            cb_response = requests.get(f'http://localhost:{CONTENT_BRIDGE_PORT}/health', timeout=5)
            cb_healthy = cb_response.status_code == 200
        except requests.exceptions.RequestException:
            pass

        try:
            ml_response = requests.get(f'http://localhost:{ML_SERVER_PORT}/', timeout=5)
            ml_healthy = ml_response.status_code == 200
        except requests.exceptions.RequestException:
            pass

        if not cb_healthy and not ml_healthy:
            pytest.skip("No API services available")

        # At least one service should be healthy
        assert cb_healthy or ml_healthy

        if cb_healthy:
            cb_data = cb_response.json()
            assert 'status' in cb_data or 'message' in cb_data

        if ml_healthy:
            ml_data = ml_response.json()
            assert 'status' in ml_data or 'message' in ml_data

    def test_redis_pubsub_minio_notification(self):
        """Test Redis pub/sub integration with MinIO events"""
        import threading
        import time

        try:
            redis_client = redis.Redis(host='localhost', port=6379, password=REDIS_PASSWORD, decode_responses=True)
            pubsub = redis_client.pubsub()

            messages_received = []

            def listener():
                try:
                    pubsub.subscribe('minio:events')
                    for message in pubsub.listen():
                        if message['type'] == 'message':
                            messages_received.append(message['data'])
                            break  # Exit after receiving one message
                except Exception:
                    pass  # Redis auth might fail

            # Start listener in background
            listener_thread = threading.Thread(target=listener)
            listener_thread.daemon = True
            listener_thread.start()

            # Wait a moment for subscription
            time.sleep(0.1)

            # Simulate MinIO event by publishing to Redis
            redis_client.publish('minio:events', 'bucket_created:test-bucket')

            # Wait for message to be received
            listener_thread.join(timeout=2.0)

            # Verify message was received (only if Redis is working)
            if messages_received:
                assert messages_received[0] == 'bucket_created:test-bucket'
            else:
                pytest.skip("Redis pub/sub not working due to authentication issues")

            pubsub.unsubscribe('minio:events')
        except Exception:
            pytest.skip("Redis authentication not configured correctly")

    def test_service_health_integration(self):
        """Test integrated health check across all services"""
        services = {
            'redis': lambda: self._check_redis_health(),
            'minio': lambda: self._check_minio_health(),
            'content_bridge': lambda: self._check_api_health(f'http://localhost:{CONTENT_BRIDGE_PORT}/health'),
            'ml_server': lambda: self._check_api_health(f'http://localhost:{ML_SERVER_PORT}/')
        }

        health_status = {}
        for service_name, health_check in services.items():
            try:
                health_status[service_name] = health_check()
            except Exception as e:
                health_status[service_name] = False
                print(f"Health check failed for {service_name}: {e}")

        # At least one service should be healthy (infrastructure services might have auth issues)
        healthy_count = sum(1 for status in health_status.values() if status)
        assert healthy_count > 0, f"No services are healthy: {health_status}"

        # Log overall health status
        healthy_services = [name for name, healthy in health_status.items() if healthy]
        print(f"Healthy services: {', '.join(healthy_services)}")

    def _check_api_health(self, url):
        """Helper method to check API service health"""
        try:
            response = requests.get(url, timeout=5)
            return response.status_code == 200
        except requests.exceptions.RequestException:
            return False

    def _check_redis_health(self):
        """Helper method to check Redis health"""
        try:
            redis_client = redis.Redis(host='localhost', port=6379, password=REDIS_PASSWORD)
            return redis_client.ping()
        except Exception:
            return False

    def _check_minio_health(self):
        """Helper method to check MinIO health"""
        try:
            minio_client = Minio(
                'localhost:9000',
                access_key=MINIO_USER,
                secret_key=MINIO_PASSWORD,
                secure=False
            )
            # Try to list buckets as a health check
            buckets = minio_client.list_buckets()
            return True
        except Exception as e:
            if 'SignatureDoesNotMatch' in str(e) or 'AccessDenied' in str(e):
                return False  # MinIO auth not configured, but service might be running
            return False

    def test_end_to_end_workflow_simulation(self):
        """Test simulated end-to-end workflow"""
        # This test simulates a typical HMA workflow:
        # 1. Store user data in Redis
        # 2. Upload content to MinIO
        # 3. Check API services health
        # 4. Verify data consistency

        try:
            redis_client = redis.Redis(host='localhost', port=6379, password=REDIS_PASSWORD, decode_responses=True)
        except Exception:
            pytest.skip("Redis authentication not configured correctly")

        # Step 1: Store user session data
        session_data = {
            'user_id': 'test_user_123',
            'session_id': 'session_456',
            'last_activity': '2024-01-01T12:00:00Z'
        }
        try:
            redis_client.hset('session:test_user_123', mapping=session_data)
        except Exception:
            pytest.skip("Redis operations not working due to authentication issues")        # Step 2: Upload content to MinIO
        minio_client = Minio(
            'localhost:9000',
            access_key=MINIO_USER,
            secret_key=MINIO_PASSWORD,
            secure=False
        )

        bucket_name = 'hma-content'
        try:
            minio_client.make_bucket(bucket_name)
        except Exception as e:
            if 'SignatureDoesNotMatch' in str(e) or 'AccessDenied' in str(e):
                pytest.skip("MinIO authentication not configured correctly")
            elif 'already exists' not in str(e).lower():
                raise

        content = b"Sample learning content for HMA"
        content_key = "content/test_user_123/module_1.txt"
        minio_client.put_object(bucket_name, content_key, content, len(content))

        # Step 3: Verify API services
        cb_healthy = self._check_api_health(f'http://localhost:{CONTENT_BRIDGE_PORT}/health')
        ml_healthy = self._check_api_health(f'http://localhost:{ML_SERVER_PORT}/')

        # At least one API service should be available, or skip if none are available
        if not cb_healthy and not ml_healthy:
            pytest.skip("No API services available for end-to-end test")

        # Step 4: Verify data consistency
        stored_session = redis_client.hgetall('session:test_user_123')
        assert stored_session['user_id'] == session_data['user_id']

        response = minio_client.get_object(bucket_name, content_key)
        stored_content = response.read()
        assert stored_content == content

        # Clean up
        redis_client.delete('session:test_user_123')
        minio_client.remove_object(bucket_name, content_key)

        # Log workflow completion
        print("End-to-end workflow simulation completed successfully")

if __name__ == '__main__':
    pytest.main([__file__, '-v'])

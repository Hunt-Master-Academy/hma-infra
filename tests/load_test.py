"""
Hunt Master Academy - Performance Load Testing
Locust-based load testing for Content Bridge API and ML Server API

Usage:
    locust -f tests/load_test.py --host=http://localhost:8090
    # Then open http://localhost:8089 for web interface

Or run programmatically:
    python tests/load_test.py
"""

import time
import json
import random
from locust import HttpUser, task, between, constant, tag
from locust.exception import StopUser
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Test data
TEST_USERS = [
    {"email": f"user_{i}@test.com", "password": "test123", "role": "student"}
    for i in range(100)
]

CONTENT_TYPES = ["video", "document", "image", "audio"]
ML_MODELS = ["classification", "detection", "recommendation"]

class ContentBridgeUser(HttpUser):
    """Load testing user for Content Bridge API"""

    wait_time = between(1, 3)  # Random wait between 1-3 seconds
    host = "http://hma-content-bridge:8090"

    def on_start(self):
        """Initialize user session"""
        self.token = None
        self.user_data = random.choice(TEST_USERS)

        # Attempt login (may fail if user doesn't exist - that's ok for load testing)
        try:
            response = self.client.post("/auth/login", json={
                "email": self.user_data["email"],
                "password": self.user_data["password"]
            }, timeout=10)

            if response.status_code == 200:
                self.token = response.json().get("token")
                self.client.headers.update({"Authorization": f"Bearer {self.token}"})
                logger.info(f"User {self.user_data['email']} logged in successfully")
        except Exception as e:
            logger.warning(f"Login failed for {self.user_data['email']}: {e}")

    @task(3)  # 30% of requests
    def health_check(self):
        """Health check endpoint"""
        with self.client.get("/health", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Health check failed: {response.status_code}")

    @task(2)  # 20% of requests
    def get_content(self):
        """Get content listing"""
        with self.client.get("/content", catch_response=True) as response:
            if response.status_code in [200, 401, 403]:  # 401/403 expected if not authenticated
                response.success()
            else:
                response.failure(f"Content listing failed: {response.status_code}")

    @task(1)  # 10% of requests
    def upload_content(self):
        """Upload content (simulated)"""
        if not self.token:
            return  # Skip if not authenticated

        content_data = {
            "title": f"Load Test Content {random.randint(1, 1000)}",
            "type": random.choice(CONTENT_TYPES),
            "description": "Load testing content upload"
        }

        # Simulate file upload (without actual file for load testing)
        with self.client.post("/content/upload",
                            json=content_data,
                            catch_response=True) as response:
            if response.status_code in [201, 400, 401, 403]:
                response.success()
            else:
                response.failure(f"Content upload failed: {response.status_code}")

    @task(1)  # 10% of requests
    def user_profile(self):
        """Get user profile"""
        if not self.token:
            return

        with self.client.get("/user/profile", catch_response=True) as response:
            if response.status_code in [200, 401, 403]:
                response.success()
            else:
                response.failure(f"Profile request failed: {response.status_code}")

    @task(1)  # 10% of requests
    def search_content(self):
        """Search content"""
        search_terms = ["hunting", "safety", "technique", "equipment", "wildlife"]
        query = random.choice(search_terms)

        with self.client.get(f"/content/search?q={query}", catch_response=True) as response:
            if response.status_code in [200, 401, 403]:
                response.success()
            else:
                response.failure(f"Search failed: {response.status_code}")

    @task(1)  # 10% of requests
    def get_progress(self):
        """Get user progress"""
        if not self.token:
            return

        with self.client.get("/user/progress", catch_response=True) as response:
            if response.status_code in [200, 401, 403]:
                response.success()
            else:
                response.failure(f"Progress request failed: {response.status_code}")


class MLServerUser(HttpUser):
    """Load testing user for ML Server API"""

    wait_time = constant(2)  # Constant 2 second wait
    host = "http://hma-ml-server:8000"

    def on_start(self):
        """Initialize ML user session"""
        self.api_key = "test-api-key"  # Simplified for load testing
        self.client.headers.update({"Authorization": f"Bearer {self.api_key}"})

    @task(2)  # 40% of requests
    def health_check(self):
        """ML Server health check"""
        with self.client.get("/health", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"ML health check failed: {response.status_code}")

    @task(3)  # 30% of requests
    def make_prediction(self):
        """Make ML prediction"""
        # Generate random prediction data
        prediction_data = {
            "model_id": random.choice(ML_MODELS),
            "features": [random.random() for _ in range(random.randint(10, 50))],
            "user_id": f"load_test_user_{random.randint(1, 1000)}",
            "context": {
                "session_id": f"session_{random.randint(1, 10000)}",
                "timestamp": time.time()
            }
        }

        with self.client.post("/predict",
                            json=prediction_data,
                            catch_response=True) as response:
            if response.status_code == 200:
                response.success()
                # Validate response structure
                try:
                    result = response.json()
                    if "prediction" in result and "confidence" in result:
                        response.success()
                    else:
                        response.failure("Invalid prediction response structure")
                except json.JSONDecodeError:
                    response.failure("Invalid JSON response")
            elif response.status_code in [400, 422]:  # Validation errors
                response.success()
            else:
                response.failure(f"Prediction failed: {response.status_code}")

    @task(1)  # 20% of requests
    def get_models(self):
        """Get available models"""
        with self.client.get("/models", catch_response=True) as response:
            if response.status_code == 200:
                response.success()
            else:
                response.failure(f"Models listing failed: {response.status_code}")

    @task(1)  # 10% of requests
    def get_user_models(self):
        """Get user-specific models"""
        user_id = f"load_test_user_{random.randint(1, 1000)}"

        with self.client.get(f"/user/{user_id}/models", catch_response=True) as response:
            if response.status_code in [200, 404]:  # 404 if user has no models
                response.success()
            else:
                response.failure(f"User models request failed: {response.status_code}")


# ============================================================================
# PROGRAMMATIC LOAD TESTING
# ============================================================================

def run_load_test(duration_seconds=60, users=10, spawn_rate=2):
    """
    Run load test programmatically

    Args:
        duration_seconds: How long to run the test
        users: Number of concurrent users
        spawn_rate: Users to spawn per second
    """
    from locust import events
    from locust.runners import LocalRunner, STATE_STOPPED, STATE_STOPPING

    # Import the user classes
    from tests.load_test import ContentBridgeUser, MLServerUser

    # Setup logging
    logging.basicConfig(level=logging.INFO)

    # Create runner
    runner = LocalRunner([
        ContentBridgeUser,
        MLServerUser
    ])

    # Start test
    runner.start(users, spawn_rate=spawn_rate)
    logger.info(f"Started load test with {users} users at {spawn_rate} users/second")

    # Run for specified duration
    time.sleep(duration_seconds)

    # Stop test
    runner.stop()
    logger.info("Load test completed")

    # Get results
    stats = runner.stats

    # Print summary
    print("\n" + "="*60)
    print("LOAD TEST RESULTS SUMMARY")
    print("="*60)

    for name, stats_data in stats.entries.items():
        print(f"\n{name}:")
        print(f"  Requests: {stats_data.num_requests}")
        print(f"  Failures: {stats_data.num_failures}")
        print(f"  Average response time: {stats_data.avg_response_time:.2f}ms")
        print(f"  95th percentile: {stats_data.get_response_time_percentile(0.95):.2f}ms")
        print(f"  Requests/second: {stats_data.total_rps:.2f}")

    print("\n" + "="*60)

    return stats


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1:
        if sys.argv[1] == "--run":
            # Run programmatic load test
            duration = int(sys.argv[2]) if len(sys.argv) > 2 else 60
            users = int(sys.argv[3]) if len(sys.argv) > 3 else 10
            spawn_rate = float(sys.argv[4]) if len(sys.argv) > 4 else 2.0

            print(f"Running load test: {users} users, {duration}s duration, {spawn_rate} spawn rate")
            run_load_test(duration, users, spawn_rate)
        else:
            print("Usage: python load_test.py [--run [duration] [users] [spawn_rate]]")
            print("  --run: Run programmatic load test")
            print("  duration: Test duration in seconds (default: 60)")
            print("  users: Number of concurrent users (default: 10)")
            print("  spawn_rate: Users to spawn per second (default: 2.0)")
            print("")
            print("For Locust web interface:")
            print("  locust -f tests/load_test.py --host=http://localhost:8090")
            print("  Then open http://localhost:8089")
    else:
        print("Load Test Configuration:")
        print("- Content Bridge API: http://hma-content-bridge:8090")
        print("- ML Server API: http://hma-ml-server:8000")
        print("- Test Users: 100 simulated users")
        print("- Content Types: video, document, image, audio")
        print("- ML Models: classification, detection, recommendation")
        print("")
        print("Run with: locust -f tests/load_test.py --host=http://hma-content-bridge:8090")

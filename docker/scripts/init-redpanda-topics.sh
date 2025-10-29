#!/bin/bash
# Initialize Redpanda Topics for HMA Event Streaming
# Run after Redpanda container is healthy

set -e

CONTAINER_NAME="hma_redpanda"
PARTITIONS=3
REPLICAS=1

echo "🚀 Initializing Redpanda topics for HMA..."
echo ""

# Wait for Redpanda to be ready
echo "⏳ Waiting for Redpanda to be healthy..."
timeout=60
elapsed=0
while ! docker exec "$CONTAINER_NAME" rpk cluster health > /dev/null 2>&1; do
    if [ $elapsed -ge $timeout ]; then
        echo "❌ Timeout waiting for Redpanda to be healthy"
        exit 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    echo -n "."
done
echo ""
echo "✅ Redpanda is healthy!"
echo ""

# Function to create topic if it doesn't exist
create_topic() {
    local topic_name=$1
    local description=$2
    
    echo "📝 Creating topic: $topic_name"
    echo "   Description: $description"
    
    if docker exec "$CONTAINER_NAME" rpk topic create "$topic_name" \
        --partitions $PARTITIONS \
        --replicas $REPLICAS 2>&1 | grep -q "TOPIC_ALREADY_EXISTS"; then
        echo "   ⚠️  Topic already exists, skipping..."
    else
        echo "   ✅ Topic created successfully"
    fi
    echo ""
}

# Core event topics
create_topic "user-events" "User lifecycle events (signup, login, profile updates)"
create_topic "credit-events" "Credit system events (purchases, adjustments, usage)"
create_topic "audit-events" "Security and compliance audit trail"
create_topic "email-queue" "Email notification queue for async delivery"

# Learning system topics
create_topic "enrollment-events" "Course enrollment and subscription events"
create_topic "assessment-events" "Quiz/assessment submission and grading events"
create_topic "progress-events" "Learning progress tracking events"
create_topic "achievement-events" "Badge/achievement unlock events"

# Business workflow topics
create_topic "payment-events" "Stripe payment processing events"
create_topic "subscription-events" "Subscription lifecycle events (renewal, cancel)"
create_topic "refund-events" "Refund and credit adjustment workflow events"

# Integration topics
create_topic "wordpress-sync-events" "WordPress user/course synchronization events"
create_topic "engine-request-events" "Computational engine request/response events"

# Dead letter queues
create_topic "dlq-user-events" "Failed user events for retry"
create_topic "dlq-credit-events" "Failed credit events for retry"
create_topic "dlq-email-queue" "Failed email deliveries for retry"

echo "📊 Topic Summary:"
docker exec "$CONTAINER_NAME" rpk topic list
echo ""

echo "🔍 Cluster Info:"
docker exec "$CONTAINER_NAME" rpk cluster info
echo ""

echo "✅ Redpanda initialization complete!"
echo ""
echo "🌐 Access Redpanda Console: http://localhost:9091"
echo ""

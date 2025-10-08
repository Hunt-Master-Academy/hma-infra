#!/bin/bash
# Create test buckets in MinIO using the MinIO client inside the container

echo "Creating test buckets in MinIO..."

# Create buckets
docker exec hma_minio mkdir -p /data/user-uploads
docker exec hma_minio mkdir -p /data/course-content
docker exec hma_minio mkdir -p /data/media-assets
docker exec hma_minio mkdir -p /data/student-submissions

echo "✅ Created test buckets:"
echo "  - user-uploads"
echo "  - course-content"
echo "  - media-assets"
echo "  - student-submissions"

# Create some test files in the buckets
docker exec hma_minio sh -c 'echo "Test upload file" > /data/user-uploads/test.txt'
docker exec hma_minio sh -c 'echo "Sample course content" > /data/course-content/lesson-1.txt'
docker exec hma_minio sh -c 'echo "Media asset placeholder" > /data/media-assets/video-thumbnail.jpg'

echo "✅ Added sample files to buckets"
echo ""
echo "You can now view these buckets in MinIO Console at http://localhost:9001"
echo "Login: minioadmin / minioadmin"

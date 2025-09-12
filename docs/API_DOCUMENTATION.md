# Hunt Master Academy - API Documentation

## Content Bridge API (Port 8090)

### Base URL
```
http://localhost:8090
```

---

## Authentication Endpoints

### POST /auth/login
Authenticate user and retrieve access token.

**Request Body:**
```json
{
  "email": "user@example.com",
  "password": "user_password"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "id": "user_12345",
    "email": "user@example.com",
    "role": "user"
  }
}
```

**Error Responses:**
- `401 Unauthorized`: Invalid credentials
- `400 Bad Request`: Missing required fields

### POST /auth/token
Validate and refresh access token.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "valid": true,
  "user_id": "user_12345",
  "expires_at": "2025-09-12T15:30:00Z"
}
```

### POST /auth/register
Register new user account.

**Request Body:**
```json
{
  "email": "newuser@example.com",
  "username": "newuser123",
  "password": "secure_password"
}
```

**Response (201 Created):**
```json
{
  "id": "user_67890",
  "email": "newuser@example.com",
  "username": "newuser123",
  "created_at": "2025-09-12T14:30:00Z"
}
```

---

## User Management Endpoints

### GET /admin/users
List all users (admin access required).

**Headers:**
```
Authorization: Bearer <admin_token>
```

**Response (200 OK):**
```json
{
  "users": [
    {
      "id": "user_12345",
      "email": "user@example.com",
      "username": "user123",
      "role": "user",
      "created_at": "2025-09-10T10:00:00Z",
      "last_login": "2025-09-12T14:00:00Z"
    }
  ],
  "total": 1,
  "page": 1,
  "per_page": 50
}
```

**Error Responses:**
- `403 Forbidden`: Insufficient permissions
- `401 Unauthorized`: Invalid or missing token

### GET /user/profile
Get current user profile.

**Headers:**
```
Authorization: Bearer <access_token>
```

**Response (200 OK):**
```json
{
  "id": "user_12345",
  "email": "user@example.com",
  "username": "user123",
  "profile": {
    "first_name": "John",
    "last_name": "Doe",
    "avatar_url": "https://example.com/avatar.jpg",
    "preferences": {
      "language": "en",
      "notifications": true
    }
  },
  "statistics": {
    "courses_completed": 5,
    "total_time_spent": 12.5,
    "last_activity": "2025-09-12T14:00:00Z"
  }
}
```

---

## Content Management Endpoints

### POST /content/upload
Upload content file (video, image, document).

**Headers:**
```
Authorization: Bearer <access_token>
Content-Type: multipart/form-data
```

**Form Data:**
```
file: [binary file data]
title: "Lesson 1: Introduction to Hunting"
type: "video"
course_id: "course_123"
```

**Response (201 Created):**
```json
{
  "id": "content_98765",
  "title": "Lesson 1: Introduction to Hunting",
  "type": "video",
  "file_url": "https://storage.example.com/content/content_98765.mp4",
  "thumbnail_url": "https://storage.example.com/thumbnails/content_98765.jpg",
  "duration": 300,
  "file_size": 1048576,
  "upload_status": "completed",
  "created_at": "2025-09-12T14:30:00Z"
}
```

**Error Responses:**
- `413 Payload Too Large`: File exceeds size limit
- `415 Unsupported Media Type`: Invalid file format
- `400 Bad Request`: Missing required fields

### GET /api/manifest
Get content manifest for offline access.

**Response (200 OK):**
```json
{
  "version": "1.0.0",
  "last_updated": "2025-09-12T14:30:00Z",
  "content": [
    {
      "id": "content_98765",
      "title": "Lesson 1: Introduction to Hunting",
      "type": "video",
      "file_url": "https://storage.example.com/content/content_98765.mp4",
      "checksum": "sha256:abcd1234...",
      "size": 1048576
    }
  ]
}
```

---

## Error Simulation Endpoints

### GET /bad-request
Simulate 400 Bad Request error.

**Response (400 Bad Request):**
```json
{
  "error": "Bad Request",
  "message": "This is a simulated 400 error for testing purposes",
  "timestamp": "2025-09-12T14:30:00Z"
}
```

### GET /unprocessable
Simulate 422 Unprocessable Entity error.

**Response (422 Unprocessable Entity):**
```json
{
  "error": "Unprocessable Entity",
  "message": "This is a simulated 422 error for testing purposes",
  "details": {
    "field": "example_field",
    "issue": "validation_failed"
  },
  "timestamp": "2025-09-12T14:30:00Z"
}
```

### GET /server-error
Simulate 500 Internal Server Error.

**Response (500 Internal Server Error):**
```json
{
  "error": "Internal Server Error",
  "message": "This is a simulated 500 error for testing purposes",
  "timestamp": "2025-09-12T14:30:00Z"
}
```

---

## ML Server API (Port 8010)

### Base URL
```
http://localhost:8010
```

---

## Authentication Endpoints

### POST /auth/login
Authenticate for ML service access.

**Request Body:**
```json
{
  "api_key": "ml_api_key_12345",
  "service": "ml_server"
}
```

**Response (200 OK):**
```json
{
  "access_token": "ml_token_abcd1234",
  "expires_in": 7200,
  "permissions": ["model_access", "prediction_create"]
}
```

---

## Model Management Endpoints

### GET /models
List available ML models.

**Headers:**
```
Authorization: Bearer <ml_token>
```

**Response (200 OK):**
```json
{
  "models": [
    {
      "id": "hunting_skill_classifier",
      "name": "Hunting Skill Classifier",
      "version": "1.2.0",
      "type": "classification",
      "status": "active",
      "accuracy": 0.92,
      "last_trained": "2025-09-10T08:00:00Z",
      "input_features": ["experience_years", "practice_hours", "course_completion"],
      "output_classes": ["beginner", "intermediate", "advanced", "expert"]
    },
    {
      "id": "course_recommender",
      "name": "Course Recommendation Engine",
      "version": "2.1.0",
      "type": "recommendation",
      "status": "active",
      "performance_score": 0.88,
      "last_updated": "2025-09-11T10:30:00Z"
    }
  ]
}
```

### GET /models/{model_id}
Get specific model details.

**Response (200 OK):**
```json
{
  "id": "hunting_skill_classifier",
  "name": "Hunting Skill Classifier",
  "version": "1.2.0",
  "type": "classification",
  "description": "Classifies user hunting skill level based on experience and course completion",
  "status": "active",
  "metrics": {
    "accuracy": 0.92,
    "precision": 0.89,
    "recall": 0.94,
    "f1_score": 0.91
  },
  "input_schema": {
    "experience_years": "integer",
    "practice_hours": "float",
    "course_completion": "float"
  },
  "output_schema": {
    "predicted_class": "string",
    "confidence": "float",
    "probabilities": "object"
  },
  "training_data": {
    "samples": 10000,
    "last_training": "2025-09-10T08:00:00Z",
    "data_version": "v3.1"
  }
}
```

---

## Prediction Endpoints

### POST /predict
Generate ML predictions.

**Request Body:**
```json
{
  "model_id": "hunting_skill_classifier",
  "features": {
    "experience_years": 3,
    "practice_hours": 120.5,
    "course_completion": 0.75
  },
  "user_id": "user_12345"
}
```

**Response (200 OK):**
```json
{
  "prediction_id": "pred_abc123",
  "model_id": "hunting_skill_classifier",
  "model_version": "1.2.0",
  "predicted_class": "intermediate",
  "confidence": 0.87,
  "probabilities": {
    "beginner": 0.05,
    "intermediate": 0.87,
    "advanced": 0.08,
    "expert": 0.00
  },
  "timestamp": "2025-09-12T14:30:00Z",
  "processing_time_ms": 45
}
```

**Error Responses:**
- `404 Not Found`: Model not found
- `400 Bad Request`: Invalid input features
- `503 Service Unavailable`: Model temporarily unavailable

---

## Analytics Endpoints

### GET /admin/analytics
Get ML performance analytics (admin access required).

**Headers:**
```
Authorization: Bearer <admin_token>
```

**Response (200 OK):**
```json
{
  "summary": {
    "total_predictions": 15672,
    "predictions_today": 234,
    "active_models": 3,
    "average_response_time_ms": 67
  },
  "model_performance": [
    {
      "model_id": "hunting_skill_classifier",
      "predictions_count": 8934,
      "average_confidence": 0.84,
      "accuracy": 0.92,
      "last_24h_predictions": 145
    }
  ],
  "usage_trends": {
    "hourly_predictions": [12, 8, 15, 23, 34, 45, 56, 67, 78, 89, 56, 34],
    "daily_predictions": [234, 198, 267, 189, 223, 245, 234]
  }
}
```

---

## Health & Status Endpoints

### GET /
Service health check.

**Response (200 OK):**
```json
{
  "service": "ml_server",
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": "2025-09-12T14:30:00Z",
  "uptime_seconds": 3600,
  "models_loaded": 3,
  "memory_usage_mb": 512,
  "cpu_usage_percent": 15.2
}
```

### GET /health
Detailed health status.

**Response (200 OK):**
```json
{
  "status": "healthy",
  "checks": {
    "database_connection": "healthy",
    "redis_connection": "healthy",
    "model_loading": "healthy",
    "storage_access": "healthy"
  },
  "version": "1.0.0",
  "environment": "development"
}
```

---

## Error Simulation Endpoints

Similar to Content Bridge API, includes:
- `GET /bad-request` - 400 error simulation
- `GET /unprocessable` - 422 error simulation  
- `GET /server-error` - 500 error simulation

---

## Common Response Patterns

### Success Responses
All successful responses include:
- Appropriate HTTP status code (200, 201, etc.)
- JSON response body
- Timestamp field in ISO 8601 format

### Error Responses
All error responses follow this pattern:
```json
{
  "error": "Error Type",
  "message": "Human-readable error description",
  "details": {},
  "timestamp": "2025-09-12T14:30:00Z",
  "request_id": "req_12345"
}
```

### Authentication
- All protected endpoints require `Authorization: Bearer <token>` header
- Tokens expire after specified time (varies by endpoint)
- Invalid tokens return 401 Unauthorized
- Insufficient permissions return 403 Forbidden

### Rate Limiting
- Current implementation: No rate limiting (development)
- Production recommendation: 1000 requests/hour per user
- ML predictions: 100 requests/minute per user

### Data Formats
- All dates/times in ISO 8601 format (UTC)
- File sizes in bytes
- Durations in seconds
- Percentages as decimals (0.0 to 1.0)

---

## Integration Examples

### User Authentication Flow
```python
import requests

# 1. Login
login_response = requests.post('http://localhost:8090/auth/login', json={
    'email': 'user@example.com',
    'password': 'password123'
})
token = login_response.json()['access_token']

# 2. Access protected resource
profile_response = requests.get(
    'http://localhost:8090/user/profile',
    headers={'Authorization': f'Bearer {token}'}
)
```

### ML Prediction Flow
```python
import requests

# 1. Authenticate with ML service
ml_auth = requests.post('http://localhost:8010/auth/login', json={
    'api_key': 'ml_api_key_12345',
    'service': 'ml_server'
})
ml_token = ml_auth.json()['access_token']

# 2. Make prediction
prediction = requests.post(
    'http://localhost:8010/predict',
    headers={'Authorization': f'Bearer {ml_token}'},
    json={
        'model_id': 'hunting_skill_classifier',
        'features': {
            'experience_years': 3,
            'practice_hours': 120.5,
            'course_completion': 0.75
        },
        'user_id': 'user_12345'
    }
)
result = prediction.json()
```

### Content Upload Flow
```python
import requests

# Upload file with metadata
files = {'file': ('lesson1.mp4', open('lesson1.mp4', 'rb'), 'video/mp4')}
data = {
    'title': 'Lesson 1: Introduction',
    'type': 'video',
    'course_id': 'course_123'
}

upload_response = requests.post(
    'http://localhost:8090/content/upload',
    headers={'Authorization': f'Bearer {token}'},
    files=files,
    data=data
)
```

---

## Testing & Validation

### API Testing Commands
```bash
# Health checks
curl http://localhost:8090/
curl http://localhost:8010/

# Authentication test
curl -X POST http://localhost:8090/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'

# Error simulation test
curl http://localhost:8090/bad-request
curl http://localhost:8010/unprocessable
```

### Integration Test Coverage
- All endpoints covered in integration test suite
- Authentication flows validated
- Error conditions tested
- Performance benchmarks established

---

*This API documentation reflects the current alpha implementation. All endpoints are functional and tested as of September 12, 2025.*
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import os

app = FastAPI(title="HMA ML Server (stub)")

class LoginRequest(BaseModel):
    username: str
    password: str

class TokenRequest(BaseModel):
    refresh_token: str

@app.get("/")
def read_root():
    return {
        "status": "ok",
        "model_path": os.getenv("MODEL_PATH", "/models"),
        "env": {
            "redis": os.getenv("REDIS_URL"),
            "postgres": os.getenv("POSTGRES_URL"),
            "minio": os.getenv("MINIO_ENDPOINT"),
        },
    }

# Authentication Endpoints
@app.post("/auth/login")
async def login(credentials: LoginRequest):
    """Mock login endpoint"""
    if credentials.username == "admin@test.com" and credentials.password == "admin123":
        return {
            "access_token": "mock_ml_admin_token_12345",
            "token_type": "bearer",
            "user": {"id": 1, "username": credentials.username, "role": "admin"}
        }
    elif credentials.username == "user@test.com" and credentials.password == "user123":
        return {
            "access_token": "mock_ml_user_token_67890",
            "token_type": "bearer",
            "user": {"id": 2, "username": credentials.username, "role": "user"}
        }
    else:
        raise HTTPException(status_code=401, detail="Invalid credentials")

@app.post("/auth/token")
async def token_refresh(token_data: TokenRequest):
    """Mock token refresh endpoint"""
    if token_data.refresh_token in ["mock_ml_admin_token_12345", "mock_ml_user_token_67890"]:
        return {
            "access_token": "mock_ml_refreshed_token_99999",
            "token_type": "bearer"
        }
    raise HTTPException(status_code=401, detail="Invalid refresh token")

@app.get("/auth/me")
async def get_current_user():
    """Mock current user endpoint"""
    return {"id": 1, "username": "admin@test.com", "role": "admin"}

# Role-based Access Endpoints
@app.get("/admin/models")
async def admin_models():
    """Admin-only endpoint for model management"""
    return {
        "message": "ML Models dashboard",
        "models": [
            {"id": "model_1", "name": "Species Classifier", "status": "active"},
            {"id": "model_2", "name": "Audio Processor", "status": "training"}
        ]
    }

@app.get("/user/predictions")
async def user_predictions():
    """User endpoint for predictions"""
    return {
        "message": "User predictions data",
        "predictions": [
            {"audio_id": "audio_123", "species": "deer", "confidence": 0.95},
            {"audio_id": "audio_456", "species": "turkey", "confidence": 0.87}
        ]
    }

@app.get("/models")
async def get_models():
    """Mock models endpoint for ML Server"""
    return {
        "models": [
            {"id": "model_1", "name": "Species Classifier", "status": "active", "accuracy": 0.95},
            {"id": "model_2", "name": "Audio Processor", "status": "training", "accuracy": 0.87}
        ]
    }

@app.post("/predict")
async def predict(data: dict):
    """Mock prediction endpoint for ML Server"""
    if 'invalid' in data:
        raise HTTPException(status_code=400, detail="Invalid prediction data")
    return {"prediction": "deer", "confidence": 0.95}

@app.get("/models/{model_id}")
async def get_model(model_id: str):
    """Mock get model endpoint"""
    if model_id == "nonexistent":
        raise HTTPException(status_code=404, detail="Model not found")
    return {"id": model_id, "name": f"Model {model_id}", "status": "active"}

# Error Simulation Endpoints
@app.get("/bad-request")
async def simulate_bad_request():
    """Simulate 400 Bad Request error"""
    raise HTTPException(status_code=400, detail="Bad request - invalid parameters")

@app.get("/unprocessable")
async def simulate_unprocessable():
    """Simulate 422 Unprocessable Entity error"""
    raise HTTPException(status_code=422, detail="Unprocessable entity - validation failed")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
import os
import json
import hashlib
from pathlib import Path
from typing import Optional, List, Dict

import numpy as np
from pydub import AudioSegment
import redis

try:
    import boto3
except Exception:  # optional in local mode
    boto3 = None

app = FastAPI(title="HMA Content Bridge", version="1.0.0")

# Configuration
CONTENT_ROOT = Path(os.getenv("CONTENT_ROOT", "/content"))
CACHE_DIR = Path(os.getenv("CACHE_DIR", "/cache"))
CONTENT_MODE = os.getenv("CONTENT_MODE", "local")  # local, hybrid, s3
S3_BUCKET = os.getenv("S3_BUCKET", "hma-content-alpha")
CDN_URL = os.getenv("CDN_URL", "http://localhost:8090")

# Redis cache for metadata
redis_client = redis.Redis(host='redis', port=6379, password=os.getenv('REDIS_PASSWORD'), decode_responses=True)

# S3 client for hybrid mode
if CONTENT_MODE in ["hybrid", "s3"] and boto3 is not None:
    s3_client = boto3.client('s3')
else:
    s3_client = None

class ContentService:
    async def get_audio_file(self, category: str, species: str, filename: str,
                             format: Optional[str] = None, sample_rate: Optional[int] = None):
        cache_key = f"audio:{category}:{species}:{filename}:{format}:{sample_rate}"
        cached_path = CACHE_DIR / hashlib.md5(cache_key.encode()).hexdigest()

        if cached_path.exists():
            return FileResponse(cached_path)

        source_path = CONTENT_ROOT / "audio" / category / species / filename
        if not source_path.exists():
            if CONTENT_MODE == "hybrid" and s3_client:
                raise HTTPException(status_code=501, detail="S3 fallback not implemented in this stub")
            raise HTTPException(status_code=404, detail="Audio file not found")

        if format or sample_rate:
            processed = await self.process_audio(source_path, format, sample_rate)
            processed.export(cached_path, format=format or "wav")
            return FileResponse(cached_path)

        return FileResponse(source_path)

    async def process_audio(self, path: Path, format: Optional[str], sample_rate: Optional[int]):
        audio = AudioSegment.from_file(path)
        if sample_rate:
            audio = audio.set_frame_rate(sample_rate)
        return audio

    async def get_icon(self, category: str, name: str, size: Optional[str] = None):
        base_path = CONTENT_ROOT / "media" / "icons" / category
        if size:
            icon_path = base_path / f"{name}{size}.png"
            if icon_path.exists():
                return FileResponse(icon_path)
        svg_path = base_path / f"{name}.svg"
        if svg_path.exists():
            return FileResponse(svg_path, media_type="image/svg+xml")
        png_path = base_path / f"{name}.png"
        if png_path.exists():
            return FileResponse(png_path)
        raise HTTPException(status_code=404, detail="Icon not found")

    async def get_research_paper(self, category: str, paper_id: str, extract: Optional[str] = None):
        paper_path = CONTENT_ROOT / "documents" / "research-papers" / category / f"{paper_id}.pdf"
        if extract:
            extract_path = paper_path.parent / "extracted" / extract
            if extract_path.exists():
                return FileResponse(extract_path)
        if paper_path.exists():
            return FileResponse(paper_path, media_type="application/pdf")
        raise HTTPException(status_code=404, detail="Paper not found")

    async def get_ml_features(self, audio_id: str):
        ro_features_path = CONTENT_ROOT / "audio" / "processed" / f"{audio_id}-features.npy"
        rw_features_path = CACHE_DIR / "features" / f"{audio_id}-features.npy"
        if ro_features_path.exists():
            features = np.load(ro_features_path)
            return {"audio_id": audio_id, "features": features.tolist(), "shape": features.shape, "dtype": str(features.dtype)}
        if rw_features_path.exists():
            features = np.load(rw_features_path)
            return {"audio_id": audio_id, "features": features.tolist(), "shape": features.shape, "dtype": str(features.dtype)}

        # Try generating features from available audio on-the-fly (dev only)
        audio_path = self.find_audio_file(audio_id)
        if audio_path and audio_path.exists():
            features = await self.extract_features(audio_path)
            rw_features_path.parent.mkdir(parents=True, exist_ok=True)
            np.save(rw_features_path, features)
            return {"audio_id": audio_id, "features": features.tolist(), "shape": features.shape, "dtype": str(features.dtype)}

        raise HTTPException(status_code=404, detail="Features not found")

    def find_audio_file(self, audio_id: str) -> Optional[Path]:
        # Search recursively under /content/audio for matching basename
        audio_root = CONTENT_ROOT / "audio"
        if not audio_root.exists():
            return None
        for ext in (".wav", ".mp3"):
            try:
                match = next((p for p in audio_root.rglob(f"**/{audio_id}{ext}") if p.is_file()), None)
                if match:
                    return match
            except StopIteration:
                pass
        return None

    async def extract_features(self, path: Path) -> np.ndarray:
        # Minimal placeholder feature extraction: return mean/std of frames
        try:
            audio = AudioSegment.from_file(path)
            samples = np.array(audio.get_array_of_samples()).astype(np.float32)
            # Simple windowed stats as a placeholder
            window = 2048
            if samples.size == 0:
                return np.zeros((1, 2), dtype=np.float32)
            num = max(1, samples.size // window)
            feats = []
            for i in range(num):
                seg = samples[i*window:(i+1)*window]
                if seg.size == 0:
                    seg = samples
                feats.append([float(seg.mean()), float(seg.std())])
            return np.array(feats, dtype=np.float32)
        except Exception:
            # Fallback deterministic features for corrupt/placeholder files
            return np.zeros((8, 2), dtype=np.float32)

    def load_audio_index(self) -> Dict:
        manifest_path = CONTENT_ROOT / "manifests" / "audio-index.json"
        if manifest_path.exists():
            try:
                with open(manifest_path) as f:
                    data = json.load(f)
                    items = data.get("items") if isinstance(data, dict) else None
                    if items and isinstance(items, list) and len(items) > 0:
                        return data
            except Exception:
                pass
        # Build minimal index by scanning when manifest is missing or empty
        base = CONTENT_ROOT / "audio" / "game-calls"
        items: List[Dict] = []
        for ext in (".wav", ".mp3"):
            for p in base.rglob(f"*{ext}"):
                try:
                    rel = p.relative_to(CONTENT_ROOT)
                except ValueError:
                    rel = p
                parts = rel.parts
                # Expect: audio/game-calls/<category>/[species]/filename
                category = parts[2] if len(parts) > 2 else None
                species = parts[3] if len(parts) > 3 and category in ("master", "processed") else None
                items.append({
                    "id": p.stem,
                    "ext": ext.lstrip('.'),
                    "category": category,
                    "species": species,
                    "path": str(rel).replace('\\', '/'),
                    "size": p.stat().st_size,
                })
        return {"count": len(items), "items": items}

content_service = ContentService()

# API Endpoints
@app.get("/health")
async def health():
    return {"status": "healthy", "mode": CONTENT_MODE, "content_root": str(CONTENT_ROOT), "cdn_url": CDN_URL}

@app.get("/api/audio/{category}/{species}/{filename}")
async def get_audio(category: str, species: str, filename: str, format: Optional[str] = None, sample_rate: Optional[int] = None):
    return await content_service.get_audio_file(category, species, filename, format, sample_rate)

@app.get("/api/icons/{category}/{name}")
async def get_icon(category: str, name: str, size: Optional[str] = None):
    return await content_service.get_icon(category, name, size)

@app.get("/api/research/{category}/{paper_id}")
async def get_research(category: str, paper_id: str, extract: Optional[str] = None):
    return await content_service.get_research_paper(category, paper_id, extract)

@app.get("/api/ml/features/{audio_id}")
async def get_ml_features(audio_id: str):
    return await content_service.get_ml_features(audio_id)

@app.get("/api/manifest")
async def get_content_manifest():
    manifest_path = CONTENT_ROOT / "manifests" / "content-registry.json"
    if manifest_path.exists():
        with open(manifest_path) as f:
            return json.load(f)
    return {"error": "Manifest not found"}

# Static file serving for development
app.mount("/static", StaticFiles(directory=str(CONTENT_ROOT)), name="static")

@app.get("/api/audio/index")
async def audio_index():
    return content_service.load_audio_index()

@app.get("/api/audio/ids")
async def audio_ids():
    idx = content_service.load_audio_index()
    return sorted({item.get("id") for item in idx.get("items", [])})

# Authentication Endpoints
@app.post("/auth/login")
async def login(credentials: dict):
    """Mock login endpoint"""
    username = credentials.get("username")
    password = credentials.get("password")

    if username == "admin@test.com" and password == "admin123":
        return {
            "access_token": "mock_admin_token_12345",
            "token_type": "bearer",
            "user": {"id": 1, "username": username, "role": "admin"}
        }
    elif username == "user@test.com" and password == "user123":
        return {
            "access_token": "mock_user_token_67890",
            "token_type": "bearer",
            "user": {"id": 2, "username": username, "role": "user"}
        }
    else:
        raise HTTPException(status_code=401, detail="Invalid credentials")

@app.post("/auth/token")
async def token_refresh(token_data: dict):
    """Mock token refresh endpoint"""
    refresh_token = token_data.get("refresh_token")
    if refresh_token in ["mock_admin_token_12345", "mock_user_token_67890"]:
        return {
            "access_token": "mock_refreshed_token_99999",
            "token_type": "bearer"
        }
    raise HTTPException(status_code=401, detail="Invalid refresh token")

@app.get("/auth/me")
async def get_current_user():
    """Mock current user endpoint"""
    return {"id": 1, "username": "admin@test.com", "role": "admin"}

# Role-based Access Endpoints
@app.get("/admin/dashboard")
async def admin_dashboard():
    """Admin-only endpoint"""
    return {"message": "Admin dashboard data", "stats": {"users": 150, "content": 2500}}

@app.get("/admin/users")
async def admin_users():
    """Admin-only endpoint for user management"""
    return {
        "message": "Admin users management",
        "users": [
            {"id": 1, "username": "admin@test.com", "role": "admin", "status": "active"},
            {"id": 2, "username": "user@test.com", "role": "user", "status": "active"}
        ]
    }

@app.get("/instructor/courses")
async def instructor_courses():
    """Instructor-only endpoint for course management"""
    return {
        "message": "Instructor courses management",
        "courses": [
            {"id": 1, "title": "Hunting Basics", "students": 25, "status": "active"},
            {"id": 2, "title": "Advanced Tracking", "students": 15, "status": "draft"}
        ]
    }

@app.get("/student/progress")
async def student_progress():
    """Student endpoint for progress tracking"""
    return {
        "message": "Student progress tracking",
        "progress": [
            {"course_id": 1, "course_title": "Hunting Basics", "completion": 75, "grade": "B+"},
            {"course_id": 2, "course_title": "Advanced Tracking", "completion": 45, "grade": "A-"}
        ]
    }

# Error Simulation Endpoints
@app.get("/bad-request")
async def simulate_bad_request():
    """Simulate 400 Bad Request error"""
    raise HTTPException(status_code=400, detail="Bad request - invalid parameters")

@app.get("/unprocessable")
async def simulate_unprocessable():
    """Simulate 422 Unprocessable Entity error"""
    raise HTTPException(status_code=422, detail="Unprocessable entity - validation failed")

@app.post("/content/upload")
async def upload_content(data: dict):
    """Mock content upload endpoint"""
    if 'invalid' in data:
        raise HTTPException(status_code=400, detail="Invalid content data")
    return {"message": "Content uploaded successfully", "content_id": "12345"}

@app.get("/nonexistent")
async def nonexistent_endpoint():
    """Mock nonexistent endpoint that returns custom error"""
    from fastapi.responses import JSONResponse
    return JSONResponse(
        status_code=404,
        content={
            "error": "Resource not found",
            "message": "The requested resource does not exist",
            "timestamp": "2025-09-11T12:00:00Z"
        }
    )

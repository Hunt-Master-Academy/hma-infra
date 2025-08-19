from fastapi import FastAPI
import os

app = FastAPI(title="HMA ML Server (stub)")

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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

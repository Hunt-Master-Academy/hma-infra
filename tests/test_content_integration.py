import requests
import numpy as np

BASE_URL = "http://localhost:8090"

def test_health():
    r = requests.get(f"{BASE_URL}/health")
    assert r.status_code == 200
    data = r.json()
    assert data.get("status") == "healthy"

# Additional tests require local content presence; placeholders for now.

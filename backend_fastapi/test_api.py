import requests
try:
    r = requests.get("http://localhost:8000/api/v1/risk-map")
    print(f"Status: {r.status_code}")
    print(f"Body: {r.text}")
except Exception as e:
    print(f"Connection error: {e}")

#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Quick test: Trigger emergency warning via curl
# ═══════════════════════════════════════════════════════════════════════════

# STEP 1: GET YOUR AUTH TOKEN
# ─────────────────────────────────────────────────────────────────────────
# You need a valid JWT token from Supabase. Get it by:
# 
# A) Login from the Flutter app → Check localStorage for token
# B) Or use test credentials if you have Supabase email/password
#
# For NOW, uncomment the line below and paste your real JWT token:

export AUTH_TOKEN="your-jwt-token-here"
# Example: export AUTH_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

if [ "$AUTH_TOKEN" = "your-jwt-token-here" ]; then
    echo "❌ ERROR: Please set your JWT token first!"
    echo ""
    echo "Get token by:"
    echo "  1. Login to the Flutter app"
    echo "  2. Open DevTools > Application > Local Storage"
    echo "  3. Find 'supabase.auth.token' or check response headers"
    echo ""
    echo "Then run:"
    echo "  export AUTH_TOKEN=\"<your-token-here>\""
    echo "  bash test_warning.sh"
    exit 1
fi

# STEP 2: Test backend connectivity
echo "🔍 Checking backend..."
if ! curl -s http://localhost:8000/docs > /dev/null; then
    echo "❌ Backend not running!"
    echo ""
    echo "Start it with:"
    echo "  cd backend_fastapi"
    echo "  .venv\\Scripts\\Activate.ps1  # Windows"
    echo "  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
    exit 1
fi
echo "✓ Backend is running"

# STEP 3: Send test warning
echo ""
echo "=================================================="
echo "🚨 Sending TEST FLOOD WARNING..."
echo "=================================================="

curl -X POST "http://localhost:8000/api/v1/warnings" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d '{
    "title": "🚨 FLOOD ALERT TEST - Cyberjaya",
    "description": "TEST WARNING: Heavy flooding reported. This is a test of the emergency warning system. Water level rising rapidly.",
    "hazard_type": "flood",
    "alert_level": "warning",
    "location": {
      "latitude": 3.1390,
      "longitude": 101.6869
    },
    "radius_km": 5.0,
    "source": "test-system"
  }' | python -m json.tool

echo ""
echo "=================================================="
echo "✓ Check your app for notifications!"
echo "=================================================="

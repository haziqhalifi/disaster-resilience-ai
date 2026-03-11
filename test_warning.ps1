# ═══════════════════════════════════════════════════════════════════════════
# Quick test: Trigger emergency warning via PowerShell
# ═══════════════════════════════════════════════════════════════════════════

# STEP 1: SET YOUR AUTH TOKEN
# ─────────────────────────────────────────────────────────────────────────
# Get your JWT token from:
#   1. Login to the Flutter app
#   2. Check browser DevTools > Application > Local Storage > supabase key
#   3. Copy the token and paste it below:

$AUTH_TOKEN = "your-jwt-token-here"

if ($AUTH_TOKEN -eq "your-jwt-token-here") {
    Write-Host "❌ ERROR: Please set your JWT token first!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Steps to get token:" -ForegroundColor Yellow
    Write-Host "  1. Open Flutter app in web browser"
    Write-Host "  2. Right-click → Inspect → Local Storage"
    Write-Host "  3. Find your JWT token and copy it"
    Write-Host ""
    Write-Host "Example:" -ForegroundColor Cyan
    Write-Host '  $AUTH_TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."' 
    exit 1
}

# STEP 2: Check backend
Write-Host "🔍 Checking backend..." -ForegroundColor Cyan
try {
    $health = Invoke-WebRequest -Uri "http://localhost:8000/docs" -ErrorAction Stop
    Write-Host "✓ Backend is running" -ForegroundColor Green
} catch {
    Write-Host "❌ Backend not running!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Start it with:" -ForegroundColor Yellow
    Write-Host "  cd backend_fastapi"
    Write-Host "  .\.venv\Scripts\Activate.ps1"
    Write-Host "  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000"
    exit 1
}

# STEP 3: Send test warning
Write-Host ""
Write-Host "=================================================="
Write-Host "🚨 Sending TEST FLOOD WARNING..." -ForegroundColor Red
Write-Host "=================================================="
Write-Host ""

$url = "http://localhost:8000/api/v1/warnings"

$headers = @{
    "Content-Type"  = "application/json"
    "Authorization" = "Bearer $AUTH_TOKEN"
}

$body = @{
    title       = "🚨 FLOOD ALERT TEST - Cyberjaya"
    description = "TEST WARNING: Heavy flooding reported. This is a test of the emergency warning system. Evacuate to higher ground!"
    hazard_type = "flood"
    alert_level = "warning"
    location    = @{
        latitude  = 3.1390
        longitude = 101.6869
    }
    radius_km = 5.0
    source    = "test-system"
} | ConvertTo-Json

Write-Host "Request:" -ForegroundColor Cyan
Write-Host $body
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body
    
    Write-Host ""
    Write-Host "✓ SUCCESS! Warning created and broadcasted!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Results:" -ForegroundColor Cyan
    Write-Host "  • Warning ID: $($response.warning_id)"
    Write-Host "  • Push Notifications Sent: $($response.push_sent)"
    Write-Host "  • SMS Alerts Sent: $($response.sms_sent)"
    Write-Host "  • Total Affected Users: $($response.total_affected)"
    
    Write-Host ""
    Write-Host "=================================================="
    Write-Host "✓ Check your Flutter app for notifications!" -ForegroundColor Green
    Write-Host "=================================================="
    
} catch {
    Write-Host ""
    Write-Host "❌ ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    
    if ($_.Exception.Response) {
        $result = $_.Exception.Response.Content.ReadAsStringAsync().Result
        Write-Host ""
        Write-Host "Response:" -ForegroundColor Yellow
        Write-Host $result
    }
}

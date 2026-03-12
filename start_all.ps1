# ============================================================
#  START ALL — Disaster Resilience AI
#  Opens 4 PowerShell windows (backend, admin, flutter, ngrok)
# ============================================================

$root = $PSScriptRoot

Write-Host ""
Write-Host "======================================"
Write-Host " Disaster Resilience AI — Start All"
Write-Host "======================================"
Write-Host ""

# Kill anything already on ports 8000, 3000, 5000
foreach ($port in @(8000, 3000, 5000)) {
    $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($conn) {
        Write-Host "Freeing port $port (PID $($conn.OwningProcess))..."
        Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
    }
}
Start-Sleep -Seconds 1

# Window 1 — Backend
Write-Host "Starting Backend (port 8000)..."
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$root'; .\start_backend.ps1"
Start-Sleep -Seconds 3

# Window 2 — Admin website
Write-Host "Starting Admin Website (port 3000)..."
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$root'; .\start_admin.ps1"

# Window 3 — Flutter web
Write-Host "Starting Flutter Web (port 5000)..."
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$root'; .\start_flutter_web.ps1"

# Window 4 — ngrok
Write-Host "Starting ngrok tunnel (port 8000)..."
Start-Process powershell -ArgumentList "-NoExit", "-Command", "ngrok http 8000"

Write-Host ""
Write-Host "======================================"
Write-Host "All services launching in new windows!"
Write-Host ""
Write-Host "  Backend:       http://localhost:8000"
Write-Host "  Admin panel:   http://localhost:3000"
Write-Host "  Flutter app:   http://localhost:5000"
Write-Host ""
Write-Host "After ngrok starts, get your webhook URL:"
Write-Host "  (Invoke-RestMethod http://localhost:4040/api/tunnels).tunnels[0].public_url"
Write-Host "======================================"
Write-Host ""

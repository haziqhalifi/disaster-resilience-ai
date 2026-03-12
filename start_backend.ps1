# Start the FastAPI backend (kills any existing process on port 8000 first)
$conn = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
if ($conn) {
    $procId = $conn.OwningProcess
    Write-Host "Freeing port 8000 (PID $procId)..."
    Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# CRITICAL: Must run from backend_fastapi so Python finds the 'app' module
$backendDir = Join-Path $PSScriptRoot "backend_fastapi"
if (-not (Test-Path $backendDir)) {
    Write-Host "ERROR: backend_fastapi not found at $backendDir"
    exit 1
}
$backendDir = (Resolve-Path $backendDir).Path
Set-Location $backendDir

# Try .venv first, then venv (common names)
$venv = Join-Path $backendDir ".venv\Scripts\Activate.ps1"
if (-not (Test-Path $venv)) { $venv = Join-Path $backendDir "venv\Scripts\Activate.ps1" }
if (Test-Path $venv) { & $venv } else { Write-Host "WARNING: venv not found, using system Python" }

Write-Host "Starting backend on http://localhost:8000 ..."
Write-Host "  (Running from: $backendDir)"
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

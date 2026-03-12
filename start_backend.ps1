# Start the FastAPI backend (kills any existing process on port 8000 first)
$conn = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue
if ($conn) {
    Write-Host "Freeing port 8000 (PID $($conn.OwningProcess))..."
    Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

Set-Location "$PSScriptRoot\backend_fastapi"

$venv = "$PSScriptRoot\backend_fastapi\.venv\Scripts\Activate.ps1"
if (Test-Path $venv) { & $venv } else { Write-Host "WARNING: .venv not found, using system Python" }

Write-Host "Starting backend on http://localhost:8000 ..."
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

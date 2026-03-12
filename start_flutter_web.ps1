# Run Flutter web app in Chrome debug mode on port 5000 (kills any existing process first)
$conn = Get-NetTCPConnection -LocalPort 5000 -State Listen -ErrorAction SilentlyContinue
if ($conn) {
    $procId = $conn.OwningProcess
    Write-Host "Freeing port 5000 (PID $procId)..."
    Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

Set-Location "$PSScriptRoot\frontend_flutter\disaster_resilience_ai"
Write-Host "Starting Flutter web on http://localhost:5000 ..."
flutter run -d chrome --web-port 5000

# Serve the admin website on port 3000 (kills any existing process first)
$conn = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
if ($conn) {
    $procId = $conn.OwningProcess
    Write-Host "Freeing port 3000 (PID $procId)..."
    Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# Use absolute path so the server always serves from the correct directory
$adminDir = (Resolve-Path (Join-Path $PSScriptRoot "admin_website")).Path
Write-Host "Serving admin website on http://localhost:3000 ..."
python -m http.server 3000 --directory $adminDir

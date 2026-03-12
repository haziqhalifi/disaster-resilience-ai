# Serve the admin website on port 3000 (kills any existing process first)
$conn = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
if ($conn) {
    Write-Host "Freeing port 3000 (PID $($conn.OwningProcess))..."
    Stop-Process -Id $conn.OwningProcess -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

Write-Host "Serving admin website on http://localhost:3000 ..."
python -m http.server 3000 --directory "$PSScriptRoot\admin_website"

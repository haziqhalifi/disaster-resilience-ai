# Run Flutter on a physical device (Android/iOS) with backend reachable via your PC's IP.
# Use this when "Cannot reach backend at localhost" appears on a real device.
#
# 1. Start the backend first: .\start_backend.ps1
# 2. Ensure your phone and PC are on the same Wi-Fi
# 3. Run this script (it will show your IP and run the app)

$root = $PSScriptRoot
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
    $_.InterfaceAlias -match '^Wi-Fi$'
} | Select-Object -First 1).IPAddress

if (-not $ip) {
    $ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
        $_.InterfaceAlias -notmatch 'Loopback|Bluetooth|vEthernet|Ethernet [23]|Local Area' -and
        $_.IPAddress -notmatch '^169\.254\.|^127\.'
    } | Select-Object -First 1).IPAddress
}

if (-not $ip) {
    Write-Host "Could not detect local IP. Use: ipconfig to find your IPv4 address."
    $ip = Read-Host "Enter your PC's IP (e.g. 192.168.1.100)"
}

$apiUrl = "http://${ip}:8000"
Write-Host ""
Write-Host "Using API_BASE_URL=$apiUrl"
Write-Host "Ensure backend is running: .\start_backend.ps1"
Write-Host ""

Set-Location "$root\frontend_flutter\disaster_resilience_ai"
flutter run --dart-define=API_BASE_URL=$apiUrl

# Start ngrok tunnel to expose the backend (port 8000) to the internet
# After starting, get your public URL: (Invoke-RestMethod http://localhost:4040/api/tunnels).tunnels[0].public_url

Write-Host "Starting ngrok tunnel for http://localhost:8000 ..."
Write-Host "Public URL will be available at http://localhost:4040 (ngrok dashboard)"
Write-Host ""
ngrok http 8000

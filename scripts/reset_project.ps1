Write-Host "=============================="
Write-Host "Restarting data platform"
Write-Host "=============================="

docker compose down

Write-Host ""
Write-Host "=============================="
Write-Host "Starting services"
Write-Host "=============================="

docker compose up -d --build

Write-Host ""
Write-Host "Waiting for services to initialize..."
Start-Sleep -Seconds 25

Write-Host ""
Write-Host "=============================="
Write-Host "Running smoke test"
Write-Host "=============================="

.\scripts\smoke_test.ps1
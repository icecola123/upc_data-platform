Write-Host "=============================="
Write-Host "Safe Redeploy"
Write-Host "=============================="

Write-Host "This script rebuilds and restarts services without deleting runtime data."

docker compose up -d --build

Start-Sleep -Seconds 90

.\scripts\check_airflow.ps1
.\scripts\check_superset.ps1

Write-Host ""
Write-Host "Safe redeploy finished."
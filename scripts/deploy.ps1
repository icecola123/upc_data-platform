Write-Host "=============================="
Write-Host "Data Platform Deployment"
Write-Host "=============================="

if (-not (Test-Path ".env")) {
    Write-Host ".env file not found. Creating it from .env.example..."
    Copy-Item ".env.example" ".env"
    Write-Host "Please review .env values before using this deployment in production."
}

Write-Host ""
Write-Host "=============================="
Write-Host "Pull latest Git changes"
Write-Host "=============================="

git status

Write-Host ""
Write-Host "If this is a deployment machine, make sure the working tree is clean before pulling."
Write-Host "Pulling latest changes..."
git pull

Write-Host ""
Write-Host "=============================="
Write-Host "Build and start Docker services"
Write-Host "=============================="

docker compose up -d --build

Write-Host ""
Write-Host "Waiting for services to initialize..."
Start-Sleep -Seconds 120

Write-Host ""
Write-Host "=============================="
Write-Host "Run validation checks"
Write-Host "=============================="

.\scripts\check_airflow.ps1
.\scripts\check_superset.ps1

Write-Host ""
Write-Host "=============================="
Write-Host "Deployment finished"
Write-Host "=============================="

Write-Host "Open services:"
Write-Host "Streamlit: http://localhost:8501"
Write-Host "Airflow:   http://localhost:8080"
Write-Host "Superset:  http://localhost:8088"
Write-Host "MinIO:     http://localhost:9001"
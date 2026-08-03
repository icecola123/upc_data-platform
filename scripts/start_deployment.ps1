Write-Host "=============================="
Write-Host "Start Data Platform Deployment"
Write-Host "=============================="

if (-not (Test-Path ".env")) {
    Write-Host ".env not found. Creating .env from .env.example..."
    Copy-Item ".env.example" ".env"
    Write-Host "Please review .env before using the platform."
}

Write-Host ""
Write-Host "=============================="
Write-Host "Build custom Airflow image"
Write-Host "=============================="

docker build -t data-platform-airflow:2.8.1-local .\airflow

Write-Host ""
Write-Host "=============================="
Write-Host "Build Docker Compose images"
Write-Host "=============================="

docker compose build data-portal astro-frontend

Write-Host ""
Write-Host "=============================="
Write-Host "Start Docker Compose services"
Write-Host "=============================="

docker compose up -d --no-build

Write-Host ""
Write-Host "Waiting for services to initialize..."
Start-Sleep -Seconds 120

Write-Host ""
Write-Host "Checking Airflow..."
.\scripts\check_airflow.ps1

Write-Host ""
Write-Host "Checking Superset..."
.\scripts\check_superset.ps1

Write-Host ""
Write-Host "Deployment started."
Write-Host "Streamlit: http://localhost:8501"
Write-Host "Airflow:   http://localhost:8080"
Write-Host "Superset:  http://localhost:8088"
Write-Host "Astro:     http://localhost:4321"
Write-Host "MinIO:     http://localhost:9001"

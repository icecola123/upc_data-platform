# Deployment Notes

## Local deployment on another machine

1. Install Docker Desktop and Git.
2. Copy or clone the repository.
3. Create `.env` from `.env.example`.

```powershell
Copy-Item .env.example .env

Start services.
docker compose up -d --build

Wait for initialization.
Start-Sleep -Seconds 120

Run checks.
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\check_airflow.ps1
.\scripts\check_superset.ps1

Open Streamlit and upload an Excel file.
http://localhost:8501

Run the full smoke test.
.\scripts\smoke_test.ps1



Service URLs
Streamlit: http://localhost:8501
Airflow:   http://localhost:8080
Superset:  http://localhost:8088
MinIO:     http://localhost:9001

Superset PostgreSQL URI
postgresql+psycopg2://project_user:project_pass@postgres:5432/project_db

Notes
Do not use localhost inside container-to-container connection strings.
Use postgres as the PostgreSQL hostname from Superset and Airflow containers.
Do not expose PostgreSQL publicly in a real deployment.
For cloud deployment, prefer a VPS with Docker Compose.
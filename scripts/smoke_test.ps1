function Get-EnvValue {
    param (
        [string]$Key
    )

    $envFile = ".env"

    if (-not (Test-Path $envFile)) {
        Write-Host "ERROR: .env file not found. Please create it from .env.example."
        exit 1
    }

    $line = Get-Content $envFile | Where-Object {
        $_ -match "^\s*$Key\s*="
    } | Select-Object -First 1

    if (-not $line) {
        Write-Host "ERROR: Missing required environment variable: $Key"
        exit 1
    }

    $value = ($line -split "=", 2)[1].Trim()

    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-Host "ERROR: Environment variable $Key is empty."
        exit 1
    }

    return $value
}

$MINIO_ROOT_USER = Get-EnvValue "MINIO_ROOT_USER"
$MINIO_ROOT_PASSWORD = Get-EnvValue "MINIO_ROOT_PASSWORD"

$MINIO_PORTAL_USER = Get-EnvValue "MINIO_PORTAL_USER"
$MINIO_PORTAL_PASSWORD = Get-EnvValue "MINIO_PORTAL_PASSWORD"

$MINIO_AIRFLOW_USER = Get-EnvValue "MINIO_AIRFLOW_USER"
$MINIO_AIRFLOW_PASSWORD = Get-EnvValue "MINIO_AIRFLOW_PASSWORD"

$PROJECT_DB_USER = Get-EnvValue "PROJECT_DB_USER"
$PROJECT_DB_PASSWORD = Get-EnvValue "PROJECT_DB_PASSWORD"
$PROJECT_DB_NAME = Get-EnvValue "PROJECT_DB_NAME"

Write-Host "=============================="
Write-Host "Smoke Test: Docker services"
Write-Host "=============================="

docker compose ps

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: Superset health"
Write-Host "=============================="

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8088/health" -UseBasicParsing -TimeoutSec 10
    if ($response.StatusCode -eq 200) {
        Write-Host "OK: Superset health endpoint is reachable."
    } else {
        Write-Host "ERROR: Superset health endpoint returned status code $($response.StatusCode)."
        exit 1
    }
} catch {
    Write-Host "ERROR: Superset health endpoint is not reachable."
    Write-Host $_.Exception.Message
    exit 1
}

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: Airflow DAG import errors"
Write-Host "=============================="

docker compose exec airflow-scheduler airflow dags list-import-errors

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: Airflow DAG list"
Write-Host "=============================="

docker compose exec airflow-scheduler airflow dags list

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: data-portal non-root user"
Write-Host "=============================="

docker compose exec data-portal whoami
docker compose exec data-portal id

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: data-portal MinIO env"
Write-Host "=============================="

$portalEnv = docker compose exec data-portal env 2>&1

if ($portalEnv -match "MINIO_PORTAL_USER=$MINIO_PORTAL_USER" -and $portalEnv -notmatch "MINIO_ROOT_USER") {
    Write-Host "OK: data-portal uses MINIO_PORTAL_USER and does not expose MINIO_ROOT_USER."
} else {
    Write-Host "ERROR: data-portal MinIO environment is not configured as expected."
    exit 1
}

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: Airflow MinIO connection"
Write-Host "=============================="

$minioConn = docker compose exec airflow-scheduler airflow connections get minio_conn 2>&1

if ($minioConn -match "minio_conn" -and $minioConn -match $MINIO_AIRFLOW_USER) {
    Write-Host "OK: Airflow minio_conn exists and uses airflow_reader."
} else {
    Write-Host "ERROR: Airflow minio_conn is missing or does not use airflow_reader."
    exit 1
}

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: MinIO bucket, users, policies"
Write-Host "=============================="

docker run --rm --network data-platform_default --entrypoint /bin/sh minio/mc -c "mc alias set local http://minio:9000 '$MINIO_ROOT_USER' '$MINIO_ROOT_PASSWORD' && mc ls local && mc admin user list local && mc admin policy list local"

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: MinIO portal upload permission"
Write-Host "=============================="

$testObject = "smoke_permission_test_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

docker run --rm --network data-platform_default --entrypoint /bin/sh minio/mc -c "echo test > /tmp/permission_test.txt && mc alias set portal http://minio:9000 '$MINIO_PORTAL_USER' '$MINIO_PORTAL_PASSWORD' && mc cp /tmp/permission_test.txt portal/client-raw-data/$testObject"

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: MinIO airflow read permission"
Write-Host "=============================="

docker run --rm --network data-platform_default --entrypoint /bin/sh minio/mc -c "mc alias set reader http://minio:9000 '$MINIO_AIRFLOW_USER' '$MINIO_AIRFLOW_PASSWORD' && mc cat reader/client-raw-data/$testObject"

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: PostgreSQL raw tables"
Write-Host "=============================="

docker compose exec -e PGPASSWORD=$PROJECT_DB_PASSWORD postgres psql -U $PROJECT_DB_USER -d $PROJECT_DB_NAME -c "\dt public.raw_*"

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: PostgreSQL row counts"
Write-Host "=============================="

docker compose exec -e PGPASSWORD=$PROJECT_DB_PASSWORD postgres psql -U $PROJECT_DB_USER -d $PROJECT_DB_NAME -c "
select 'raw_cases' as table_name, count(*) from public.raw_cases
union all
select 'raw_patents' as table_name, count(*) from public.raw_patents
union all
select 'raw_parties' as table_name, count(*) from public.raw_parties;
"

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test finished"
Write-Host "=============================="
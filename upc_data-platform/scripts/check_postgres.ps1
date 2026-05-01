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

$PROJECT_DB_USER = Get-EnvValue "PROJECT_DB_USER"
$PROJECT_DB_PASSWORD = Get-EnvValue "PROJECT_DB_PASSWORD"
$PROJECT_DB_NAME = Get-EnvValue "PROJECT_DB_NAME"

Write-Host "=============================="
Write-Host "PostgreSQL raw tables"
Write-Host "=============================="

docker compose exec -e PGPASSWORD=$PROJECT_DB_PASSWORD postgres psql -U $PROJECT_DB_USER -d $PROJECT_DB_NAME -c "\dt public.raw_*"

Write-Host ""
Write-Host "=============================="
Write-Host "PostgreSQL raw table row counts"
Write-Host "=============================="

docker compose exec -e PGPASSWORD=$PROJECT_DB_PASSWORD postgres psql -U $PROJECT_DB_USER -d $PROJECT_DB_NAME -c "
select 'raw_cases' as table_name, count(*) from public.raw_cases
union all
select 'raw_patents' as table_name, count(*) from public.raw_patents
union all
select 'raw_parties' as table_name, count(*) from public.raw_parties;
"
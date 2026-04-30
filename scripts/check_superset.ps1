Write-Host "=============================="
Write-Host "Superset service status"
Write-Host "=============================="

docker compose ps superset

Write-Host ""
Write-Host "=============================="
Write-Host "Superset health check"
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
Write-Host "Superset dashboard import asset"
Write-Host "=============================="

$assetCheck = docker compose exec superset bash -lc "ls -1 /app/superset_assets/*.zip 2>/dev/null" 2>&1

if ($assetCheck -match ".zip") {
    Write-Host "OK: Superset dashboard export zip is mounted."
    Write-Host $assetCheck
} else {
    Write-Host "ERROR: No Superset dashboard export zip found in /app/superset_assets."
    exit 1
}

Write-Host ""
Write-Host "=============================="
Write-Host "Superset dashboard import log"
Write-Host "=============================="

$logs = docker compose logs superset --tail=500 2>&1

if ($logs -match "Importing dashboard assets from patched zip" -or $logs -match "Importing dashboard assets") {
    Write-Host "OK: Superset dashboard import was attempted during initialization."
} else {
    Write-Host "WARNING: No dashboard import attempt found in recent Superset logs."
    Write-Host "If Superset was started long ago, this may be normal. Recreate Superset to re-check import logs."
}

if ($logs -match "Command failed validation" -or $logs -match "Error importing dashboard") {
    Write-Host "ERROR: Superset dashboard import failed according to logs."
    exit 1
}

Write-Host ""
Write-Host "Superset check finished."
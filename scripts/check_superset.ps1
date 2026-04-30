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
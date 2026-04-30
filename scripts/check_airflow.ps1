Write-Host "=============================="
Write-Host "Airflow DAG list"
Write-Host "=============================="

docker compose exec airflow-scheduler airflow dags list

Write-Host ""
Write-Host "=============================="
Write-Host "Airflow DAG import errors"
Write-Host "=============================="

docker compose exec airflow-scheduler airflow dags list-import-errors
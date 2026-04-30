Write-Host "=============================="
Write-Host "Smoke Test: Docker services"
Write-Host "=============================="

docker compose ps

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

docker compose exec data-portal env | Select-String "MINIO"

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: Airflow MinIO connection"
Write-Host "=============================="

$minioConn = docker compose exec airflow-scheduler airflow connections get minio_conn 2>&1

if ($minioConn -match "minio_conn" -and $minioConn -match "airflow_reader") {
    Write-Host "OK: Airflow minio_conn exists and uses airflow_reader."
} else {
    Write-Host "ERROR: Airflow minio_conn is missing or does not use airflow_reader."
    exit 1
}

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: MinIO bucket, users, policies"
Write-Host "=============================="

docker run --rm --network data-platform_default --entrypoint /bin/sh minio/mc -c "mc alias set local http://minio:9000 admin MinioSecurePass_2026 && mc ls local && mc admin user list local && mc admin policy list local"

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: MinIO portal upload permission"
Write-Host "=============================="

docker run --rm --network data-platform_default --entrypoint /bin/sh minio/mc -c "echo test > /tmp/permission_test.txt && mc alias set portal http://minio:9000 portal_uploader PortalUploadPass_2026 && mc cp /tmp/permission_test.txt portal/client-raw-data/smoke_permission_test.txt"

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: MinIO airflow read permission"
Write-Host "=============================="

docker run --rm --network data-platform_default --entrypoint /bin/sh minio/mc -c "mc alias set reader http://minio:9000 airflow_reader AirflowReadPass_2026 && mc cat reader/client-raw-data/smoke_permission_test.txt"

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: PostgreSQL raw tables"
Write-Host "=============================="

docker compose exec -e PGPASSWORD=project_pass postgres psql -U project_user -d project_db -c "\dt public.raw_*"

Write-Host ""
Write-Host "=============================="
Write-Host "Smoke Test: PostgreSQL row counts"
Write-Host "=============================="

docker compose exec -e PGPASSWORD=project_pass postgres psql -U project_user -d project_db -c "
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
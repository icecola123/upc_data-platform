Write-Host "=============================="
Write-Host "PostgreSQL raw tables"
Write-Host "=============================="

docker compose exec -e PGPASSWORD=project_pass postgres psql -U project_user -d project_db -c "\dt public.raw_*"

Write-Host ""
Write-Host "=============================="
Write-Host "PostgreSQL raw table row counts"
Write-Host "=============================="

docker compose exec -e PGPASSWORD=project_pass postgres psql -U project_user -d project_db -c "
select 'raw_cases' as table_name, count(*) from public.raw_cases
union all
select 'raw_patents' as table_name, count(*) from public.raw_patents
union all
select 'raw_parties' as table_name, count(*) from public.raw_parties;
"
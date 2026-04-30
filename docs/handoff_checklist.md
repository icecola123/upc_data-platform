This checklist is used to validate that the local data platform can be started, tested, and handed over successfully.

## 1. Repository Check

- [ ] The repository contains `README.md`.
- [ ] The repository contains `.env.example`.
- [ ] The repository contains `.gitignore`.
- [ ] The repository contains `docker-compose.yml`.
- [ ] The repository contains `airflow/dags/process_new_data_dag.py`.
- [ ] The repository contains `data_portal/`.
- [ ] The repository contains `init_scripts/`.
- [ ] The repository contains `scripts/`.
- [ ] The repository contains `superset/sql/`.
- [ ] The repository does not contain `.env`.
- [ ] The repository does not contain `postgres_data/`.
- [ ] The repository does not contain `minio_data/`.
- [ ] The repository does not contain `airflow/logs/`.
- [ ] The repository does not contain uploaded Excel files.

## 2. Environment Setup

- [ ] Copy `.env.example` to `.env`.

```powershell
Copy-Item .env.example .env
 Review .env values.
 Confirm MinIO variables exist:
MINIO_ROOT_USER
MINIO_ROOT_PASSWORD
MINIO_PORTAL_USER
MINIO_PORTAL_PASSWORD
MINIO_AIRFLOW_USER
MINIO_AIRFLOW_PASSWORD
 Confirm Airflow variables exist:
AIRFLOW_DB_USER
AIRFLOW_DB_PASSWORD
AIRFLOW_WEB_USER
AIRFLOW_WEB_PASSWORD
 Confirm Superset variables exist:
SUPERSET_DB_USER
SUPERSET_DB_PASSWORD
SUPERSET_WEB_USER
SUPERSET_WEB_PASSWORD
SUPERSET_SECRET_KEY
3. Start Services
 Start the platform.
docker compose up -d --build
 Check services.
docker compose ps

Expected services:

postgres
minio
minio-init
airflow-webserver
airflow-scheduler
data-portal
superset

Some init containers may exit after completing their setup. This is normal.

4. Airflow Validation
 Run Airflow check.
.\scripts\check_airflow.ps1

Expected result:

process_new_data_dag
No data found
paused = False
 Open Airflow:
http://localhost:8080
 Login using:
AIRFLOW_WEB_USER
AIRFLOW_WEB_PASSWORD
 Confirm process_new_data_dag is visible.
 Confirm process_new_data_dag is not paused.
 
 
5. Streamlit Upload Test
 Open Streamlit data portal:
http://localhost:8501
 Login using:
PORTAL_ACCESS_PASSWORD
 Upload a valid Excel file.
 Confirm the file is uploaded to MinIO.
 Confirm Airflow DAG is triggered.
 Confirm the DAG run succeeds.
 
 
6. PostgreSQL Validation
 Run PostgreSQL check.
.\scripts\check_postgres.ps1

Expected raw tables:

public.raw_cases
public.raw_patents
public.raw_parties
 Confirm row counts are greater than zero.

Optional manual check:

docker compose exec -e PGPASSWORD=project_pass postgres psql -U project_user -d project_db -c "\dt public.raw_*"


7. MinIO Validation
 Run full smoke test.
.\scripts\smoke_test.ps1

Expected MinIO results:

portal_uploader can upload
airflow_reader can read
Airflow minio_conn uses airflow_reader
 Confirm business services do not use MinIO root credentials.


8. Superset Validation
 Open Superset:
http://localhost:8088
 Login using:
SUPERSET_WEB_USER
SUPERSET_WEB_PASSWORD
 Add PostgreSQL database connection if needed:
postgresql+psycopg2://project_user:project_pass@postgres:5432/project_db
 Confirm Superset can access:
raw_cases
raw_patents
raw_parties
 Use SQL files from:
superset/sql/

to recreate analytical datasets if needed.

- [ ] Run Superset health check.

  `.\scripts\check_superset.ps1`

- [ ] Superset automatically imports the dashboard export from `superset/assets/`.
- [ ] The imported `project_db` database connection points to `postgres:5432/project_db`.



9. Utility Scripts
 Airflow check works.
.\scripts\check_airflow.ps1
 PostgreSQL check works.
.\scripts\check_postgres.ps1
 Full smoke test works.
.\scripts\smoke_test.ps1
 Safe restart works.
.\scripts\reset_project.ps1

If PowerShell blocks script execution, run:

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass


10. Git Validation
 Run:
git status

Expected result:

nothing to commit, working tree clean
 Confirm .env is ignored.
 Confirm runtime data directories are ignored.
 Confirm uploaded data files are ignored.


11. Known Limitations
 Superset dashboards may need to be manually rebuilt or rebound to datasets.
 Railway deployment is not implemented.
 Astro frontend work is currently out of scope.
 MinIO image is not pinned because downgrading caused storage compatibility issues.
 Full production CI/CD is not implemented yet.
 Some script outputs can be further improved to avoid displaying sensitive values.


12. Handoff Result

The project is ready for handoff if all of the following are true:

 Docker services start successfully.
 Airflow DAG is visible and unpaused.
 Streamlit upload works.
 Airflow processes the uploaded file.
 PostgreSQL raw tables are created and populated.
 MinIO dedicated users work correctly.
 Superset can connect to PostgreSQL.
 Smoke test passes.
 Git working tree is clean.
 

- [ ] Streamlit data portal is displayed in English.
- [ ] Superset dashboard appears after automatic import.

- [ ] Replace the current test dashboard export with the final Superset dashboard export.
- [ ] Re-run Superset initialization.
- [ ] Confirm the final dashboard is imported automatically.
- [ ] Confirm all final charts and filters render correctly.
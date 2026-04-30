# Project Status

## Current Status

The project currently provides a working local Docker-based data platform.

The stable data flow is:

```text
Streamlit Data Portal
→ MinIO
→ Airflow DAG
→ PostgreSQL raw tables
→ dbt transformation layer
→ Superset connection / SQL datasets
Completed Components
Docker Compose orchestration
PostgreSQL service with initialization script
MinIO object storage
Dedicated MinIO users for Streamlit upload and Airflow read access
Streamlit data upload portal
Airflow DAG for Excel ingestion
Metadata columns added during import:
import_date
source_file
Historical import strategy using append mode
PostgreSQL raw output tables:
public.raw_cases
public.raw_patents
public.raw_parties
dbt project preserved and running
Superset connected to PostgreSQL
Superset SQL files stored under superset/sql/
Superset admin initialization automated
.env.example provided
Runtime data excluded from Git
Local smoke test script
Basic CI validation workflow
Validation

The following checks currently pass:

process_new_data_dag is visible in Airflow
Airflow DAG import errors return No data found
data-portal runs as non-root user appuser
MinIO has dedicated users:
portal_uploader
airflow_reader
portal_uploader can upload to the bucket
airflow_reader can read from the bucket
PostgreSQL contains:
raw_cases
raw_patents
raw_parties
Raw tables contain data
Superset can connect to project_db
Utility Scripts
.\scripts\check_airflow.ps1
.\scripts\check_postgres.ps1
.\scripts\smoke_test.ps1
.\scripts\reset_project.ps1

If PowerShell blocks script execution:

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
Current Limitations
Superset dashboards may need to be rebuilt or manually rebound to new datasets.
Railway deployment is not implemented.
Astro frontend work is out of current scope.
MinIO image is not pinned because an earlier downgrade caused storage compatibility issues.
Full production CI/CD is not implemented yet.
Some script outputs can still be improved to avoid displaying sensitive values.
Suggested Next Steps
Keep Superset SQL datasets documented and versioned.
Rebuild or adjust dashboard charts only after the data platform is finalized.
Push the repository to GitHub when ready.
Enable the included GitHub Actions workflow.
Consider a future production deployment strategy.


## Superset Dashboard Import

Superset dashboard assets are stored under:

`superset/assets/upc_dashboard.zip`

During Superset initialization, the import script patches the exported database URI using the local `.env` project database credentials and imports the dashboard automatically.

The imported assets currently include:

- `project_db` database connection
- the virtual dataset used by the dashboard
- chart metadata
- dashboard metadata
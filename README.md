# Data Platform Pipeline

This project provides a local Docker-based data pipeline for uploading Excel data, storing raw files in MinIO, processing them with Airflow, and loading cleaned raw tables into PostgreSQL for later analysis in Superset.

## 1. Architecture

```text
Streamlit Data Portal
        |
        | Upload Excel file
        v
MinIO object storage
        |
        | Airflow reads uploaded file
        v
Airflow DAG
        |
        | Clean column names, add metadata, preserve history
        v
PostgreSQL project_db
        |
        | Superset connects to PostgreSQL
        v
Superset datasets / dashboards


2. Project Structure
.
├── airflow/
│   ├── dags/
│   │   └── process_new_data_dag.py
│   ├── logs/
│   └── plugins/
├── data_portal/
│   ├── app.py
│   ├── Dockerfile
│   └── requirements.txt
├── init_scripts/
│   ├── init.sh
│   └── init_superset.sh
├── scripts/
│   ├── check_superset.ps1
│   └── smoke_test.ps1
├── superset/
│   └── superset_config.py
├── docker-compose.yml
├── .env.example
├── .gitignore
└── README.md


3. Quick Start

Create the local environment file:

Copy-Item .env.example .env

Edit .env and replace placeholder passwords if needed.

Start all services:

docker compose up -d --build

Check service status:

docker compose ps

Run the smoke test:

.\scripts\smoke_test.ps1


4. Main URLs
Service	URL
Streamlit data portal	http://localhost:8501

Airflow	http://localhost:8080

MinIO Console	http://localhost:9001

Superset	http://localhost:8088

PostgreSQL	localhost:5432

Credentials are defined in .env.


5. Data Flow
Open the Streamlit data portal.
Upload the Excel file.
Streamlit renames the file with a timestamp and uploads it to MinIO.
Streamlit triggers the Airflow DAG process_new_data_dag.
Airflow reads the Excel file from MinIO.
Airflow writes the cleaned raw tables to PostgreSQL.

Current PostgreSQL output tables:

public.raw_cases
public.raw_patents
public.raw_parties

The DAG adds these metadata columns:

import_date
source_file


6. PostgreSQL Check

Check one table quickly:

docker compose exec -e PGPASSWORD=project_pass postgres psql -U project_user -d project_db -c "select count(*) from public.raw_cases;"

Check all raw tables:

docker compose exec -e PGPASSWORD=project_pass postgres psql -U project_user -d project_db -c "\dt public.raw_*"


7. Superset Connection

Superset should connect to the project database with this SQLAlchemy URI:

postgresql+psycopg2://project_user:project_pass@postgres:5432/project_db

The raw tables can be used in Superset SQL Lab to build datasets such as:

ds_cases_enriched
ds_cases_geo
ds_cases_parties

Superset analytical datasets are created manually in SQL Lab using the SQL files stored in `superset/sql/`.

- `superset/sql/ds_cases_enriched.sql`
- `superset/sql/ds_cases_geo.sql`
- `superset/sql/ds_cases_parties.sql`


8. Important Notes

Do not commit:

.env
postgres_data/
minio_data/
airflow/logs/
uploaded Excel files

If Airflow does not load the DAG, run:

docker compose exec airflow-scheduler airflow dags list-import-errors



## Utility Scripts

- Full smoke test:

  `.\scripts\smoke_test.ps1`

- Check Airflow DAG status:

  `.\scripts\check_airflow.ps1`

- Check PostgreSQL raw tables:

  `.\scripts\check_postgres.ps1`

- Restart the platform and run smoke test:

  `.\scripts\reset_project.ps1`
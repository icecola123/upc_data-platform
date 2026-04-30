#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
DO
\$do\$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles WHERE rolname = '$AIRFLOW_DB_USER'
   ) THEN
      CREATE USER $AIRFLOW_DB_USER WITH PASSWORD '$AIRFLOW_DB_PASSWORD';
   END IF;

   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles WHERE rolname = '$SUPERSET_DB_USER'
   ) THEN
      CREATE USER $SUPERSET_DB_USER WITH PASSWORD '$SUPERSET_DB_PASSWORD';
   END IF;

   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles WHERE rolname = 'project_user'
   ) THEN
      CREATE USER project_user WITH PASSWORD 'project_pass';
   END IF;
END
\$do\$;

CREATE DATABASE airflow_db OWNER $AIRFLOW_DB_USER;
CREATE DATABASE superset_db OWNER $SUPERSET_DB_USER;
CREATE DATABASE project_db OWNER project_user;
EOSQL
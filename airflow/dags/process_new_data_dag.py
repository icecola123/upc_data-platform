import io
import os
from datetime import datetime

import pandas as pd
from sqlalchemy import text

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.bash import BashOperator
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.providers.postgres.hooks.postgres import PostgresHook


BUCKET_NAME = "client-raw-data"
DBT_PROJECT_DIR = "/opt/airflow/dbt_project"


def normalize_columns(df: pd.DataFrame) -> pd.DataFrame:
    df = df.loc[:, ~df.columns.astype(str).str.contains("^Unnamed")]
    df.columns = [
        str(c)
        .lower()
        .strip()
        .replace(" ", "_")
        .replace(".", "_")
        .replace("(", "")
        .replace(")", "")
        for c in df.columns
    ]
    return df


def transfer_minio_to_postgres(**context):
    dag_run = context.get("dag_run")
    target_file = dag_run.conf.get("target_file") if dag_run and dag_run.conf else None

    s3_hook = S3Hook(aws_conn_id="minio_conn")

    if not target_file:
        target_file = get_latest_excel_file_from_minio(s3_hook, BUCKET_NAME)

    print(f"开始从 MinIO 读取文件：{target_file}")

    file_obj = s3_hook.get_key(key=target_file, bucket_name=BUCKET_NAME)

    if file_obj is None:
        raise FileNotFoundError(f"MinIO bucket '{BUCKET_NAME}' 中找不到文件：{target_file}")

    file_content = file_obj.get()["Body"].read()

    excel_data = pd.read_excel(
        io.BytesIO(file_content),
        engine="openpyxl",
        sheet_name=["Cases", "Patents", "Parties"],
    )

    pg_hook = PostgresHook(postgres_conn_id="project_postgres")
    engine = pg_hook.get_sqlalchemy_engine()

    import_time = datetime.utcnow()

    with engine.begin() as conn:
        for sheet_name, df in excel_data.items():
            df = normalize_columns(df)

            df["import_date"] = import_time
            df["source_file"] = target_file

            table_name = f"raw_{sheet_name.lower()}"

            table_exists = conn.execute(
                text("""
                    SELECT EXISTS (
                        SELECT FROM information_schema.tables
                        WHERE table_schema = 'public'
                          AND table_name = :table_name
                    )
                """),
                {"table_name": table_name},
            ).scalar()

            if table_exists:
                conn.execute(
                    text(f"DELETE FROM public.{table_name} WHERE source_file = :source_file"),
                    {"source_file": target_file},
                )
            else:
                print(f"表 public.{table_name} 不存在，将自动创建。")

            df.to_sql(
                table_name,
                conn,
                schema="public",
                if_exists="append",
                index=False,
                chunksize=1000,
            )

            print(f"完成写入 public.{table_name}，行数：{len(df)}")

def get_latest_excel_file_from_minio(s3_hook, bucket_name: str) -> str:
    """
    当 DAG 不是由 Streamlit 触发，而是手动触发时，
    自动从 MinIO bucket 中寻找最后修改时间最新的 Excel 文件。
    """
    s3_client = s3_hook.get_conn()

    response = s3_client.list_objects_v2(Bucket=bucket_name)

    if "Contents" not in response:
        raise FileNotFoundError(f"MinIO bucket '{bucket_name}' 中没有任何文件。")

    excel_files = [
        obj for obj in response["Contents"]
        if obj["Key"].lower().endswith(".xlsx")
    ]

    if not excel_files:
        raise FileNotFoundError(f"MinIO bucket '{bucket_name}' 中没有 .xlsx 文件。")

    latest_obj = max(excel_files, key=lambda obj: obj["LastModified"])
    latest_file = latest_obj["Key"]

    print(f"未收到 target_file，自动选择 MinIO 中最新文件：{latest_file}")
    return latest_file

with DAG(
    dag_id="process_new_data_dag",
    start_date=datetime(2026, 1, 1),
    schedule_interval=None,
    catchup=False,
    is_paused_upon_creation=False,
    tags=["UPC_Project", "Streamlit_Triggered", "dbt_Integrated"],
) as dag:

    task_ingest = PythonOperator(
        task_id="ingest_minio_excel_to_project_postgres",
        python_callable=transfer_minio_to_postgres,
    )

    task_dbt = BashOperator(
        task_id="run_dbt_transform_and_test",
        bash_command=f"""
set -e

mkdir -p /tmp/dbt_profiles

cat <<EOF > /tmp/dbt_profiles/profiles.yml
my_upc_transformation:
  outputs:
    dev:
      type: postgres
      host: postgres
      user: $PROJECT_DB_USER
      pass: $PROJECT_DB_PASSWORD
      port: 5432
      dbname: $PROJECT_DB_NAME
      schema: public
      threads: 1
  target: dev
EOF

cd {DBT_PROJECT_DIR}

dbt run --profiles-dir /tmp/dbt_profiles
dbt test --profiles-dir /tmp/dbt_profiles
""",
    )

    task_ingest >> task_dbt
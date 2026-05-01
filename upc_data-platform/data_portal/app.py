import streamlit as st
import boto3
import pandas as pd
import requests
import os
from datetime import datetime
from io import BytesIO

# ================= 1. Load configuration from Docker environment variables =================
ACCESS_PASSWORD = os.environ.get("PORTAL_ACCESS_PASSWORD")

# 🔒 Use Docker internal network address. Do not change this to localhost.
MINIO_ENDPOINT = "http://minio:9000"
MINIO_ACCESS_KEY = os.environ.get("MINIO_PORTAL_USER")
MINIO_SECRET_KEY = os.environ.get("MINIO_PORTAL_PASSWORD")
BUCKET_NAME = "client-raw-data"

DAG_ID = "process_new_data_dag"

# 🔒 Use Docker internal network address.
AIRFLOW_URL = f"http://airflow-webserver:8080/api/v1/dags/{DAG_ID}/dagRuns"
AIRFLOW_USER = os.environ.get("AIRFLOW_WEB_USER")
AIRFLOW_PASS = os.environ.get("AIRFLOW_WEB_PASSWORD")

# ================= 2. Core functions =================

def upload_to_minio(file_bytes, original_name):
    # Force region_name to prevent boto3 from looking for external credentials inside Docker.
    s3 = boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
        region_name="us-east-1"
    )

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    new_filename = f"{timestamp}_{original_name}"

    try:
        s3.put_object(Bucket=BUCKET_NAME, Key=new_filename, Body=file_bytes)
        return True, new_filename
    except Exception as e:
        return False, str(e)

def trigger_airflow(filename):
    try:
        payload = {"conf": {"target_file": filename}}
        response = requests.post(
            AIRFLOW_URL,
            auth=(AIRFLOW_USER, AIRFLOW_PASS),
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )

        # If Airflow returns an error, show the raw response in the Streamlit UI.
        if response.status_code not in [200, 201]:
            st.error(f"Airflow returned status code: {response.status_code}")
            st.error(f"Error details: {response.text}")

        return response.status_code in [200, 201]

    except Exception as e:
        st.error(f"API call failed: {e}")
        return False

# ================= 3. Streamlit UI =================

st.set_page_config(page_title="Data Ingestion Portal", page_icon="📥")

# Simple session authentication
if "auth" not in st.session_state:
    st.session_state.auth = False

if not st.session_state.auth:
    st.title("🔒 Internal Data Portal")
    pwd = st.text_input("Enter access password", type="password")

    if st.button("Enter"):
        if pwd == ACCESS_PASSWORD:
            st.session_state.auth = True
            st.rerun()
        else:
            st.error("Incorrect password. Please contact the administrator.")

else:
    st.title("📥 UPC Data Upload and Automated Distribution")
    st.info("This upload will automatically trigger Airflow for data cleaning, append-mode loading, and dbt transformation.")

    # Only allow Excel files.
    uploaded_file = st.file_uploader("Choose an Excel file (.xlsx)", type=["xlsx"])

    if uploaded_file:
        try:
            # 1. Preview data to confirm that Pandas can read the file.
            df = pd.read_excel(uploaded_file, engine="openpyxl")
            st.write(f"### Data Preview ({len(df)} rows total, showing first 5 rows)")
            st.dataframe(df.head(5))

            # 2. Confirmation button
            if st.button("🚀 Confirm and start the automated pipeline"):
                with st.spinner("Uploading to MinIO and triggering Airflow..."):

                    # Reset file pointer and read bytes.
                    uploaded_file.seek(0)
                    file_bytes = uploaded_file.read()

                    # Step A: Upload and rename file.
                    success, final_name = upload_to_minio(file_bytes, uploaded_file.name)

                    if success:
                        st.success(f"📦 File safely stored in MinIO: {final_name}")

                        # Step B: Trigger Airflow.
                        if trigger_airflow(final_name):
                            st.balloons()
                            st.success("✅ Trigger successful. Airflow has started processing this batch in the background.")
                            st.markdown(
                                "You can open the [Airflow Console](http://localhost:8080) "
                                "to check the status of `process_new_data_dag`."
                            )
                        else:
                            st.error(
                                "⚠️ The file was stored in MinIO, but Airflow could not be triggered. "
                                "The Airflow API may not be ready, or authentication may have failed."
                            )
                    else:
                        st.error(f"❌ MinIO upload failed. Please check the MinIO service status. Error details: {final_name}")

        except Exception as e:
            st.error(f"Failed to parse the Excel file. Please check the file format. Error details: {e}")
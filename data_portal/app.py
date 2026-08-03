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

def get_minio_client():
    return boto3.client(
        "s3",
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
        region_name="us-east-1"
    )


def upload_to_minio(file_bytes, original_name):
    # Force region_name to prevent boto3 from looking for external credentials inside Docker.
    s3 = get_minio_client()

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


def parse_version_name(object_key):
    parts = object_key.split("_", 2)
    if len(parts) == 3 and len(parts[0]) == 8 and len(parts[1]) == 6:
        try:
            uploaded_at = datetime.strptime(
                f"{parts[0]}_{parts[1]}",
                "%Y%m%d_%H%M%S",
            )
            return uploaded_at.strftime("%Y-%m-%d %H:%M:%S"), parts[2]
        except ValueError:
            pass

    return "-", object_key


def format_size(size_bytes):
    if size_bytes is None:
        return "-"

    size = float(size_bytes)
    for unit in ["B", "KB", "MB", "GB"]:
        if size < 1024 or unit == "GB":
            if unit == "B":
                return f"{int(size)} {unit}"
            return f"{size:.1f} {unit}"
        size /= 1024


def list_uploaded_versions(limit=50):
    s3 = get_minio_client()
    versions = []
    continuation_token = None

    while True:
        kwargs = {"Bucket": BUCKET_NAME}
        if continuation_token:
            kwargs["ContinuationToken"] = continuation_token

        response = s3.list_objects_v2(**kwargs)

        for item in response.get("Contents", []):
            key = item.get("Key")
            if not key or not key.lower().endswith(".xlsx"):
                continue

            uploaded_at, original_name = parse_version_name(key)
            versions.append(
                {
                    "key": key,
                    "uploaded_at": uploaded_at,
                    "original_name": original_name,
                    "size": format_size(item.get("Size")),
                    "last_modified": item.get("LastModified"),
                }
            )

        if not response.get("IsTruncated"):
            break

        continuation_token = response.get("NextContinuationToken")

    versions.sort(
        key=lambda row: row["last_modified"] or datetime.min,
        reverse=True,
    )
    return versions[:limit]


def download_from_minio(object_key):
    s3 = get_minio_client()
    response = s3.get_object(Bucket=BUCKET_NAME, Key=object_key)
    return response["Body"].read()


def render_version_history():
    st.markdown("---")
    st.subheader("Data Version History")

    if st.button("Refresh history"):
        st.rerun()

    search_text = st.text_input("Search uploaded files", placeholder="File name")

    try:
        versions = list_uploaded_versions()
    except Exception as e:
        st.error(f"Failed to load upload history: {e}")
        return

    if search_text:
        needle = search_text.strip().lower()
        versions = [
            version for version in versions
            if needle in version["original_name"].lower()
            or needle in version["key"].lower()
        ]

    if not versions:
        st.info("No uploaded Excel files found yet.")
        return

    versions = versions[:20]
    st.caption("Showing up to 20 matching uploaded Excel files.")

    header = st.columns([2, 4, 1, 2])
    header[0].markdown("**Uploaded at**")
    header[1].markdown("**File name**")
    header[2].markdown("**Size**")
    header[3].markdown("**Download**")

    for version in versions:
        row = st.columns([2, 4, 1, 2])
        row[0].write(version["uploaded_at"])
        row[1].write(version["original_name"])
        row[2].write(version["size"])

        try:
            file_bytes = download_from_minio(version["key"])
            row[3].download_button(
                "Download",
                data=file_bytes,
                file_name=version["original_name"],
                mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                key=f"download_{version['key']}",
            )
        except Exception as e:
            row[3].caption(f"Unavailable: {e}")


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

    render_version_history()

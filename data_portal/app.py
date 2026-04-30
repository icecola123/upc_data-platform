import streamlit as st
import boto3
import pandas as pd
import requests
import os
from datetime import datetime
from io import BytesIO

# ================= 1. 从 Docker 环境变量加载配置 =================
ACCESS_PASSWORD = os.environ.get("PORTAL_ACCESS_PASSWORD")

# 🔒 锁定为 Docker 内部网络地址，绝对不要改成 localhost
MINIO_ENDPOINT = "http://minio:9000"
MINIO_ACCESS_KEY = os.environ.get("MINIO_PORTAL_USER")
MINIO_SECRET_KEY = os.environ.get("MINIO_PORTAL_PASSWORD")
BUCKET_NAME = "client-raw-data"

DAG_ID = "process_new_data_dag" 

# 🔒 锁定为 Docker 内部网络地址
AIRFLOW_URL = f"http://airflow-webserver:8080/api/v1/dags/{DAG_ID}/dagRuns"
AIRFLOW_USER = os.environ.get("AIRFLOW_WEB_USER")
AIRFLOW_PASS = os.environ.get("AIRFLOW_WEB_PASSWORD")

# ================= 2. 核心功能函数 =================================

def upload_to_minio(file_bytes, original_name):
    # 强制指定 region_name，防止 boto3 在 Docker 内部寻找外部凭据失败
    s3 = boto3.client(
        's3',
        endpoint_url=MINIO_ENDPOINT,
        aws_access_key_id=MINIO_ACCESS_KEY,
        aws_secret_access_key=MINIO_SECRET_KEY,
        region_name='us-east-1' 
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
        # 如果报错，在 Streamlit 页面直接显示 Airflow 的原文报错
        if response.status_code not in [200, 201]:
            st.error(f"Airflow 返回状态码: {response.status_code}")
            st.error(f"错误详情: {response.text}")
        return response.status_code in [200, 201]
    except Exception as e:
        st.error(f"API 呼叫异常: {e}")
        return False

# ================= 3. Streamlit UI 界面 =================

st.set_page_config(page_title="数据衔接门户", page_icon="📥")

# 简易会话鉴权
if "auth" not in st.session_state:
    st.session_state.auth = False

if not st.session_state.auth:
    st.title("🔒 内部数据门户")
    pwd = st.text_input("请输入访问密码", type="password")
    if st.button("进入系统"):
        if pwd == ACCESS_PASSWORD:
            st.session_state.auth = True
            st.rerun()
        else:
            st.error("密码错误，请联系管理员")
else:
    st.title("📥 UPC 数据上传与自动分发")
    st.info("此上传将自动触发 Airflow 进行数据清洗、追加(Append)与 dbt 转换。")

    # 仅允许上传 Excel 文件
    uploaded_file = st.file_uploader("选择 Excel 文件 (.xlsx)", type=['xlsx'])

    if uploaded_file:
        try:
            # 1. 预览数据 (确保 Pandas 能读)
            df = pd.read_excel(uploaded_file, engine='openpyxl')
            st.write(f"### 数据预览 (共 {len(df)} 行, 仅展示前 5 行)")
            st.dataframe(df.head(5))

            # 2. 确认按钮
            if st.button("🚀 确认为该数据启动自动化流水线"):
                with st.spinner("正在同步至 MinIO 并唤醒 Airflow..."):
                    
                    # 将文件指针归零并读取字节流
                    uploaded_file.seek(0)
                    file_bytes = uploaded_file.read()
                    
                    # 步骤 A：上传并重命名
                    success, final_name = upload_to_minio(file_bytes, uploaded_file.name)
                    
                    if success:
                        st.success(f"📦 文件已安全存入 MinIO: {final_name}")
                        
                        # 步骤 B：触发 Airflow
                        if trigger_airflow(final_name):
                            st.balloons()
                            st.success("✅ 触发成功！Airflow 已开始在后台处理该批次数据。")
                            st.markdown(f"您可以登录 [Airflow 控制台](http://localhost:8080) 查看 `process_new_data_dag` 的运行状态。")
                        else:
                            st.error("⚠️ 文件已存入 MinIO，但未能自动唤醒 Airflow。可能是 Airflow API 未就绪或认证失败。")
                    else:
                        st.error(f"❌ 上传 MinIO 失败，请检查 MinIO 服务状态。报错详情: {final_name}")
                        
        except Exception as e:
            st.error(f"解析 Excel 失败，请检查文件格式是否正确。错误详情: {e}")
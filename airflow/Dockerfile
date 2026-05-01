FROM apache/airflow:2.8.1-python3.10

USER root

RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        git \
        curl \
        ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER airflow

ENV PIP_DEFAULT_TIMEOUT=300
ENV PIP_RETRIES=10
ENV PIP_INDEX_URL=https://pypi.org/simple

RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

RUN python -m pip install --no-cache-dir --default-timeout=300 --retries=10 \
    pandas==2.0.3 \
    openpyxl==3.1.2 \
    dbt-postgres==1.7.0
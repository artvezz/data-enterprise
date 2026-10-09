# Airflow + dbt: a DAG executa `dbt build` dentro do proprio container do Airflow,
# entao o dbt-core precisa estar instalado aqui. Roda em Linux, entao nao sofre o
# bloqueio de DLL (AppLocker/WDAC) que afeta o Windows local.

FROM apache/airflow:2.9.3-python3.11

USER root
# `dbt debug` e `dbt deps` exigem git no PATH
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
USER airflow

COPY requirements.txt /tmp/airflow-requirements.txt
RUN pip install --no-cache-dir -r /tmp/airflow-requirements.txt

# O Airflow roda como UID 50000 e ./dbt/{logs,target} vem do bind mount como root.
# Desvia os artefatos do dbt para /tmp, gravavel pelo usuario do Airflow.
RUN mkdir -p /tmp/dbt-logs /tmp/dbt-target \
    && chmod 777 /tmp/dbt-logs /tmp/dbt-target

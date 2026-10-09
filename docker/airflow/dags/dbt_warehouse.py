"""Pipeline dbt do warehouse (Supabase).

Executa dbt dentro do container do Airflow (imagem docker/airflow/Dockerfile),
usando o perfil em /opt/dbt/profiles.yml. A senha vem de DBT_SUPABASE_PASSWORD,
injetada pelo env_file do compose.

Cadencia: diaria as 04:00 (America/Sao_Paulo).

Alertas: se qualquer task falhar, o on_failure_callback grava um relatorio
markdown em /opt/data/alerts (bind mount ./data, massa de dados versionada fora)
e, opcionalmente, POSTa em AIRFLOW_ALERT_WEBHOOK_URL (ex.: webhook do Slack).
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.empty import EmptyOperator

DBT_DIR = "/opt/dbt"
ALERT_DIR = "/opt/data/alerts"


def dbt(*args: str) -> str:
    # em dbt 1.8 as opcoes globais vem DEPOIS do subcomando, e o BashOperator
    # roda num temp dir - por isso o cd explicito para achar o dbt_project.yml.
    return " ".join(
        ("cd", DBT_DIR, "&&", "dbt", *args, "--profiles-dir", DBT_DIR)
    )


def alertar_falha(context: dict) -> None:
    """Avisa sobre falha de task: relatorio em disco + webhook (opcional)."""
    ti = context.get("task_instance")
    dai = context.get("dag_run")
    exc = context.get("exception") or "sem detalhe"
    mensagem = (
        "## ALERTA de falha - data enterprise\n\n"
        f"- **DAG:** `{dai.dag_id}`\n"
        f"- **DAG run:** `{dai.run_id}`\n"
        f"- **Task:** `{ti.task_id}`\n"
        f"- **Execucao:** `{context.get('execution_date')}`\n"
        f"- **Erro:** `{exc}`\n"
        f"- **Log:** {ti.log_url}\n"
    )

    # 1) relatorio em disco (persistente via bind mount ./data)
    caminho = None
    try:
        os.makedirs(ALERT_DIR, exist_ok=True)
        caminho = os.path.join(ALERT_DIR, f"{dai.run_id}_{ti.task_id}.md")
        with open(caminho, "w", encoding="utf-8") as fh:
            fh.write(mensagem)
        os.makedirs("/tmp/dbt-logs/alerts", exist_ok=True)
        with open(f"/tmp/dbt-logs/alerts/{dai.run_id}_{ti.task_id}.txt", "w") as fh:
            fh.write(mensagem)
    except OSError:
        pass

    # 2) webhook opcional (ex.: Slack). Sem dependencia externa: urllib.
    webhook = os.getenv("AIRFLOW_ALERT_WEBHOOK_URL")
    if webhook:
        import json
        from urllib.request import Request, urlopen

        payload = json.dumps({"text": mensagem}).encode("utf-8")
        try:
            req = Request(webhook, data=payload, headers={"Content-Type": "application/json"})
            urlopen(req, timeout=10)
        except Exception:
            pass


default_args = {
    "owner": "data-eng",
    "retries": 2,
    "retry_delay": timedelta(minutes=10),
    "execution_timeout": timedelta(minutes=60),
    "on_failure_callback": alertar_falha,
}

with DAG(
    dag_id="dbt_warehouse",
    description="Transforma raw.* em staging.* e mart_* no Supabase, com testes de qualidade",
    start_date=datetime(2025, 4, 1),
    schedule="0 4 * * *",
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["dbt", "warehouse", "supabase"],
) as dag:

    inicio = EmptyOperator(task_id="inicio")

    conexao = BashOperator(
        task_id="dbt_debug",
        bash_command=dbt("debug"),
    )

    # run + test num unico passo: se um model falhar, o teste correspondente
    # nao roda e o run falha antes de entregar dado quebrado ao BI.
    # Obs.: em dbt 1.8 o `build` ja inclui os snapshots (SCD2).
    build = BashOperator(
        task_id="dbt_build",
        bash_command=dbt("build", "--fail-fast"),
    )

    docs = BashOperator(
        task_id="dbt_docs",
        bash_command=dbt("docs", "generate"),
    )

    fim = EmptyOperator(task_id="fim", trigger_rule="all_done")

    inicio >> conexao >> build >> docs >> fim
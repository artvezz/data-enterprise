# ingest_supabase.py
# Conecta ao Supabase Postgres (Session Pooler) e carrega os CSVs da camada raw
# para schemas raw.* (criados previamente) com as tabelas por arquivo.

import os
import sys
from pathlib import Path

import pandas as pd
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

sys.path.insert(0, str(Path(__file__).resolve().parent))
from db_env import db_params  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"

# Mapa de arquivo CSV -> (schema, tabela)
MAPEAMENTO = {
    # comum
    "comum/dim_cliente.csv": ("raw", "dim_cliente"),
    "comum/dim_produto.csv": ("raw", "dim_produto"),
    "comum/dim_calendario.csv": ("raw", "dim_calendario"),
    "comum/dim_regiao.csv": ("raw", "dim_regiao"),
    # rh
    "rh/colaboradores.csv": ("raw", "colaboradores"),
    "rh/ferias.csv": ("raw", "ferias"),
    "rh/ponto_registros.csv": ("raw", "ponto_registros"),
    "rh/custos_rh.csv": ("raw", "custos_rh"),
    "rh/cargos.csv": ("raw", "cargos"),
    # vendas
    "vendas/pedidos_vendas.csv": ("raw", "pedidos_vendas"),
    "vendas/vendedores.csv": ("raw", "vendedores"),
    "vendas/metas_vendas.csv": ("raw", "metas_vendas"),
    # comercial
    "comercial/oportunidades_crm.csv": ("raw", "oportunidades_crm"),
    "comercial/atividades_crm.csv": ("raw", "atividades_crm"),
    # marketing
    "marketing/campanhas.csv": ("raw", "campanhas"),
    "marketing/trafego_diario.csv": ("raw", "trafego_diario"),
    # logistica
    "logistica/notas_fiscais_transporte.csv": ("raw", "notas_fiscais_transporte"),
    "logistica/inventario.csv": ("raw", "inventario"),
    # financeiro
    "financeiro/lancamentos_contabeis.csv": ("raw", "lancamentos_contabeis"),
    "financeiro/contas_pagar.csv": ("raw", "contas_pagar"),
    "financeiro/contas_receber.csv": ("raw", "contas_receber"),
    "financeiro/orcamento.csv": ("raw", "orcamento"),
}

# Leitura segura de numero (virgula brasileira)
NUM_HINTS = (
    "valor", "preco", "salario", "investimento", "receita", "leads", "conversoes",
    "meta", "custo", "peso", "prazo", "quantidade", "desconto", "debito", "credito",
    "horas", "dias", "cpa", "sessoes", "usuarios", "taxa", "probabilidade",
)


def limpar_numericos(df: pd.DataFrame) -> pd.DataFrame:
    df = df.copy()
    for c in df.columns:
        if not any(h in c for h in NUM_HINTS):
            continue
        s = df[c].astype("string").str.strip()
        s = s.str.replace(".", "", regex=False).str.replace(",", ".", regex=False)
        s = s.replace({"": None, "nan": None, "NaN": None})
        df[c] = pd.to_numeric(s, errors="coerce")
    return df


def _env_val(*names: str) -> str | None:
    for n in names:
        v = os.getenv(n)
        if v:
            return v
    return None


def conectar() -> Engine:
    """Conecta ao Supabase. Nunca ha credencial no codigo: usa SUPABASE_*
    (ambiente) e, na ausencia, as DBT_SUPABASE_* do .env (via db_env)."""
    url = _env_val("SUPABASE_DB_URL", "DATABASE_URL")
    if url:
        return create_engine(url, pool_pre_ping=True, future=True)

    p = db_params()
    user = _env_val("SUPABASE_USER") or p["user"]
    password = _env_val("SUPABASE_PASSWORD", "DBT_SUPABASE_PASSWORD") or p["password"]
    host = _env_val("SUPABASE_HOST") or p["host"]
    port = str(_env_val("SUPABASE_PORT") or p["port"])
    db = _env_val("SUPABASE_DB") or p["database"]

    if not user or not password or not host:
        raise RuntimeError(
            "Credenciais ausentes: defina SUPABASE_* (ou DBT_SUPABASE_* no .env)."
        )

    from urllib.parse import quote_plus

    url = (f"postgresql+psycopg://{quote_plus(user)}:{quote_plus(password)}"
           f"@{host}:{port}/{db}?sslmode=require")
    return create_engine(url, pool_pre_ping=True, future=True)


def garantir_schemas(engine: Engine) -> None:
    """Cria schemas raw/staging/intermediate/core/marts e por time (idempotente)."""
    with engine.begin() as conn:
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS raw;"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS staging;"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS intermediate;"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS core;"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS marts;"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS qualidade;"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS mart_financeiro;"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS mart_rh;"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS mart_vendas;"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS mart_comercial;"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS mart_marketing;"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS mart_logistica;"))
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS mart_bi;"))
    print("Schemas garantidos no Supabase.")


def carregar_csv(arquivo: str, schema: str, tabela: str, engine: Engine) -> None:
    caminho = RAW / arquivo
    if not caminho.exists():
        print(f"[AVISO] CSV nao encontrado: {caminho}")
        return

    df = pd.read_csv(caminho)
    df = limpar_numericos(df)

    # Adiciona coluna de ingestao (facilita deduplicacao depois)
    df["ingestion_timestamp"] = pd.Timestamp.utcnow()

    # Dropa e recria tabela (full refresh) para manter coerente com CSVs locais
    # Se quiser append, troque por if_exists="append"
    df.to_sql(
        name=tabela,
        schema=schema,
        con=engine,
        if_exists="replace",
        index=False,
        method="multi",
        chunksize=10000,
    )
    print(f"[OK] {arquivo:52} -> {schema}.{tabela}  ({len(df):,} linhas)".replace(",", "."))


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "--apenas-schemas":
        garantir_schemas(conectar())
        return

    print("Conectando ao Supabase...")
    engine = conectar()

    print("Garantindo schemas...")
    garantir_schemas(engine)

    print("Ingerindo CSVs para raw.* (replace)...")
    for arquivo, (schema, tabela) in MAPEAMENTO.items():
        carregar_csv(arquivo, schema, tabela, engine)

    print("\nIngestao concluida no Supabase.")


if __name__ == "__main__":
    main()
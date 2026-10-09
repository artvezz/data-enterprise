"""Carrega DBT_SUPABASE_* do .env (ou do ambiente) sem versionar credenciais.

Uso (scripts locais, python+pg8000):
    import sys, os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from db_env import db_params
    p = db_params()
"""

import os
from pathlib import Path

_ROOT = Path(__file__).resolve().parent.parent


def load_env(root: Path) -> dict:
    envfile = root / ".env"
    data: dict = {}
    if envfile.exists():
        for line in envfile.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            data[k.strip()] = v.strip().strip('"').strip("'")
    return data


def db_params() -> dict:
    """Parametros de conexao do warehouse (Supabase), priorizando o .env."""
    env = load_env(_ROOT)
    return {
        "user": env.get("DBT_SUPABASE_USER") or os.getenv("DBT_SUPABASE_USER"),
        "host": env.get("DBT_SUPABASE_HOST") or os.getenv("DBT_SUPABASE_HOST"),
        "port": int(env.get("DBT_SUPABASE_PORT", os.getenv("DBT_SUPABASE_PORT", "6543"))),
        "password": env.get("DBT_SUPABASE_PASSWORD") or os.getenv("DBT_SUPABASE_PASSWORD"),
        "database": env.get("DBT_SUPABASE_DB") or os.getenv("DBT_SUPABASE_DB", "postgres"),
    }
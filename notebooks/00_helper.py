"""
Helper de EDA para o projeto Data Enterprise.

Uso dentro de um notebook ou script:

    import sys
    sys.path.append("notebooks")
    from importlib import import_module
    helper = import_module("00_helper")

    helper.resumo()
    v = helper.carregar("vendas/pedidos_vendas.csv")
    helper.perfil(v)
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd

pd.set_option("display.max_columns", 60)
pd.set_option("display.width", 160)
pd.set_option("display.float_format", lambda x: f"{x:,.2f}".replace(",", "X").replace(".", ",").replace("X", "."))

def _descobrir_root() -> Path:
    """
    Acha a raiz do projeto tanto em script quanto em notebook.

    Em script, __file__ existe e parents[1] é a raiz.
    Em notebook, __file__ nao existe: procuramos subindo a partir do CWD,
    procurando um marcador do projeto (dbt_project.yml ou data/raw).
    """
    if "__file__" in globals():
        return Path(__file__).resolve().parents[1]

    atual = Path.cwd().resolve()
    for candidato in [atual, *atual.parents]:
        if (candidato / "data" / "raw").is_dir():
            return candidato
        if (candidato / "dbt_project.yml").is_file():
            return candidato
    return atual


ROOT = _descobrir_root()
RAW = ROOT / "data" / "raw"

if not RAW.is_dir():
    raise FileNotFoundError(
        f"Camada raw nao encontrada em {RAW}.\n"
        f"CWD: {Path.cwd()}\n"
        f"Rode o notebook a partir da raiz do projeto ou defina: helper.RAW = Path('...')"
    )

# ------------------------------------------------------------------ carga

def carregar(caminho: str, **kwargs) -> pd.DataFrame:
    """Le um CSV da camada raw e imprime a dimensao."""
    df = pd.read_csv(RAW / caminho, **kwargs)
    print(f"{caminho}  ->  {len(df):,} linhas x {df.shape[1]} colunas".replace(",", "."))
    return df


def resumo() -> pd.DataFrame:
    """Inventario de todos os CSVs da camada raw."""
    registros = []
    for arquivo in sorted(RAW.rglob("*.csv")):
        df = pd.read_csv(arquivo, nrows=5)
        registros.append({
            "arquivo": arquivo.relative_to(RAW).as_posix(),
            "linhas": sum(1 for _ in arquivo.open("rb")) - 1,
            "colunas": df.shape[1],
            "memoria_mb": round(arquivo.stat().st_size / 1e6, 2),
        })
    return pd.DataFrame(registros)


# ------------------------------------------------------- passo 1: perfil

def perfil(df: pd.DataFrame) -> pd.DataFrame:
    """Estrutura, tipos, nulos e duplicados."""
    print("=" * 70)
    print("SHAPE:", df.shape)
    print("=" * 70)

    print("\n--- TIPOS ---")
    print(df.dtypes.to_string())

    print("\n--- NULOS POR COLUNA ---")
    nulos = pd.DataFrame({
        "nulos": df.isna().sum(),
        "percentual": (df.isna().mean() * 100).round(2),
    }).sort_values("nulos", ascending=False)
    print(nulos[nulos["nulos"] > 0].to_string() or "nenhuma coluna com nulos")

    print("\n--- DUPLICADOS ---")
    print("linhas inteiras duplicadas:", df.duplicated().sum())
    print("memoria (MB):", round(df.memory_usage(deep=True).sum() / 1e6, 2))
    return nulos


def checar_chaves(df: pd.DataFrame, *chaves: str) -> None:
    """Chave duplicada quebra qualquer agregacao. Sempre verificar."""
    for chave in chaves:
        if chave not in df.columns:
            print(f"[AVISO] coluna '{chave}' nao existe")
            continue
        dup = df.duplicated(subset=[chave], keep=False).sum()
        print(f"{chave}: {df[chave].nunique():,} distintos | "
              f"{dup:,} linhas duplicadas | {dup / 2:,.0f} chaves duplicadas".replace(",", "."))
        if dup:
            print(df[df.duplicated(subset=[chave], keep=False)].sort_values(chave).head(10))


# ------------------------------------------------- passo 2: distribuicao

def numericas(df: pd.DataFrame, incluir: list[str] | None = None) -> pd.DataFrame:
    """Describe estendido das colunas numericas."""
    cols = incluir or list(df.select_dtypes(include="number").columns)
    cols = [c for c in cols if c in df.columns]
    if not cols:
        print("nenhuma coluna numerica")
        return pd.DataFrame()
    return df[cols].describe(percentiles=[.01, .25, .5, .75, .95, .99]).T.round(2)


def categoricas(df: pd.DataFrame, limite: int = 20, colunas: list[str] | None = None) -> None:
    """Value counts das categoricas, pulando as de cardinalidade alta."""
    cols = colunas or list(df.select_dtypes(include="object").columns)
    for coluna in cols:
        if coluna not in df.columns:
            continue
        n = df[coluna].nunique()
        print(f"\n[{coluna}] {n} valores distintos")
        if n <= limite:
            print(df[coluna].value_counts(dropna=False).to_string())
        else:
            print(df[coluna].value_counts(dropna=False).head(limite).to_string())
            print("  ... (mostrando os 25 mais frequentes)")


def cardinalidade(df: pd.DataFrame) -> pd.DataFrame:
    """Colunas com cardinalidade proxima do total de linhas costumam ser chave."""
    return (pd.DataFrame({
        "distintos": df.nunique(),
        "linhas": len(df),
    })
        .assign(razao=(df.nunique() / len(df)).round(3))
        .sort_values("razao", ascending=False))


# --------------------------------------------------------- passo 3: tempo

def tempo(df: pd.DataFrame, coluna: str) -> pd.Series:
    """Sanidade de serie temporal: buracos, datas invalidas, granularidade."""
    serie = pd.to_datetime(df[coluna], errors="coerce")
    invalidas = serie.isna().sum()
    print(f"[{coluna}] invalidas: {invalidas} | min: {serie.min()} | max: {serie.max()}")
    print("datas no futuro:", (serie > pd.Timestamp.now().normalize()).sum())

    por_mes = serie.dt.to_period("M").value_counts().sort_index()
    print("\nlinhas por mes:")
    print(por_mes.to_string())

    completos = pd.period_range(serie.min(), serie.max(), freq="M")
    faltando = completos.difference(por_mes.index)
    print("\nmeses sem nenhuma linha:", [str(m) for m in faltando] or "nenhum")
    return serie


def cobertura_diaria(df: pd.DataFrame, coluna: str) -> pd.Series:
    """Densidade de registros por dia: 0 significa dia sem dado."""
    serie = pd.to_datetime(df[coluna], errors="coerce")
    por_dia = serie.dt.normalize().value_counts().sort_index()
    completo = pd.date_range(serie.min(), serie.max(), freq="D")
    por_dia = por_dia.reindex(completo, fill_value=0)
    print(f"dias sem registro: {(por_dia == 0).sum()} de {len(por_dia)}")
    return por_dia


# ----------------------------------------------------- passo 4: relacoes

def correlacoes(df: pd.DataFrame, cols: list[str], metodo: str = "pearson") -> pd.DataFrame:
    """Correlacao entre metricas. Spearman quando ha cauda longa."""
    cols = [c for c in cols if c in df.columns]
    return df[cols].corr(numeric_only=True, method=metodo).round(2)


def dispersao(x: str, y: str, df: pd.DataFrame, log_y: bool = False):
    """Grafico de dispersao para Relationships no Vega-Lite."""
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(8, 5))
    ax.scatter(df[x], df[y], alpha=0.15, s=8, edgecolor="none")
    if log_y:
        ax.set_yscale("log")
    ax.set_xlabel(x)
    ax.set_ylabel(y)
    ax.grid(alpha=.2)
    fig.tight_layout()
    return fig


# ---------------------------------------------------- passo 5: outliers

def outliers_iqr(serie: pd.Series, nome: str = "", k: float = 1.5) -> pd.DataFrame:
    """Outliers pelo IQR, com o recorte superior e o total afetado."""
    s = pd.to_numeric(serie, errors="coerce").dropna()
    q1, q3 = s.quantile(.25), s.quantile(.75)
    iqr = q3 - q1
    limite_inf, limite_sup = q1 - k * iqr, q3 + k * iqr
    fora = s[(s < limite_inf) | (s > limite_sup)]
    faixa = f"[{limite_inf:,.2f}, {limite_sup:,.2f}]"
    q1s, q3s, iqrs = (f"{x:,.2f}" for x in (q1, q3, iqr))
    cabecalho = (f"{nome or serie.name}: {len(fora)} outliers "
                 f"({len(fora) / len(s):.1%}) | Q1={q1s} Q3={q3s} IQR={iqrs} | "
                 f"faixa normal {faixa}")
    print(cabecalho.replace(",", "X").replace(".", ",").replace("X", "."))
    return pd.DataFrame({"valor": fora.sort_values(ascending=False)})


def lacunas_reais(df: pd.DataFrame, coluna: str) -> pd.DataFrame:
    """Valores que violam regra de negocio detectada na analise."""
    violacoes = {
        "negativo": pd.to_numeric(df[coluna], errors="coerce") < 0,
        "nulo": df[coluna].isna(),
    }
    return pd.DataFrame({k: int(v.sum()) for k, v in violacoes.items()}).T


# --------------------------------------------------------- regras de BH

def validar_regras(df: pd.DataFrame, regras: dict[str, pd.Series]) -> pd.DataFrame:
    """
    Cada valor do dicionario e uma serie booleana onde True = quebra a regra.

        validar_regras(vendas, {
            "desconto acima de 100%": vendas["desconto_pct"] > 1,
            "valor negativo":          vendas["valor_liquido"] < 0,
        })
    """
    return (pd.DataFrame({nome: serie.fillna(False) for nome, serie in regras.items()})
            .sum().to_frame("linhas_quebradas")
            .assign(percentual=lambda t: (t["linhas_quebradas"] / len(df) * 100).round(2)))


def contexto_regras(df: pd.DataFrame, mascara: pd.Series, colunas: list[str], n: int = 10):
    """Mostra as linhas que quebram a regra, para entender a causa."""
    return df.loc[mascara, colunas].head(n)


def main() -> None:
    print(__doc__)
    print("\nINVENTARIO DA CAMADA RAW\n")
    print(resumo().to_string(index=False))


if __name__ == "__main__":
    sys.path.insert(0, str(ROOT / "notebooks"))
    main()
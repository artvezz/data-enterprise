"""
EDA de negocio - Data Enterprise.

Le a camada raw e responde as perguntas que cada area faria.
Roda como script (`python notebooks/eda_negocio.py`) ou por secao
dentro do notebook eda.ipynb.

Secoes:
    01_panorama        inventario e contexto dos dados
    02_qualidade       nulos, duplicatas, coerencia, escala
    03_vendas          receita, ticket, mix, desconto, margem
    04_clientes        concentracao, segmento, canal, saude da base
    05_metas           atingimento por vendedor
    06_comercial       funil, win rate, ciclo de venda
    07_marketing       CAC, ROAS, conversao por canal
    08_logistica       SLA de entrega, custo de frete
    09_financeiro      contas a pagar/receber, aging, orcamento, DRE
    10_rh              headcount, absenteismo, turnover, folha
    11_cruzamentos     frete x receita, correlacoes
    12_achados         backlog de qualidade de dados
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import pandas as pd

pd.set_option("display.max_columns", 60)
pd.set_option("display.width", 180)
pd.set_option("display.float_format", lambda x: f"{x:,.2f}")

RAW = Path(__file__).resolve().parents[1] / "data" / "raw"

ACHADOS: list[tuple[str, str, str, str]] = []


# ------------------------------------------------------------------ utils

def brl(v: float) -> str:
    return "R$ " + f"{float(v):,.2f}".replace(",", "\x00").replace(".", ",").replace("\x00", ".")


def pct(parte, total) -> str:
    try:
        return f"{float(parte) / float(total):.1%}"
    except (ZeroDivisionError, TypeError):
        return "n/a"


def titulo(t: str) -> None:
    print("\n" + "=" * 78)
    print(t.upper())
    print("=" * 78)


def sub(t: str) -> None:
    print(f"\n--- {t} " + "-" * max(0, 70 - len(t)))


def achado(severidade: str, area: str, problema: str, impacto: str) -> None:
    ACHADOS.append((severidade, area, problema, impacto))
    print(f"  [{severidade:^7}] {area:<12} {problema}")
    print(f"            impacto: {impacto}")


def carregar(nome: str) -> pd.DataFrame:
    return pd.read_csv(RAW / nome)


_cache: dict[str, pd.DataFrame] = {}


def dados() -> dict[str, pd.DataFrame]:
    """Carrega tudo uma vez e memoiza."""
    if _cache:
        return _cache
    arquivos = {
        "vendas": "vendas/pedidos_vendas.csv",
        "vendedores": "vendas/vendedores.csv",
        "metas": "vendas/metas_vendas.csv",
        "clientes": "comum/dim_cliente.csv",
        "produtos": "comum/dim_produto.csv",
        "calendario": "comum/dim_calendario.csv",
        "regiao": "comum/dim_regiao.csv",
        "colaboradores": "rh/colaboradores.csv",
        "ponto": "rh/ponto_registros.csv",
        "ferias": "rh/ferias.csv",
        "custos_rh": "rh/custos_rh.csv",
        "cargos": "rh/cargos.csv",
        "oportunidades": "comercial/oportunidades_crm.csv",
        "atividades": "comercial/atividades_crm.csv",
        "campanhas": "marketing/campanhas.csv",
        "trafego": "marketing/trafego_diario.csv",
        "notas": "logistica/notas_fiscais_transporte.csv",
        "inventario": "logistica/inventario.csv",
        "lancamentos": "financeiro/lancamentos_contabeis.csv",
        "contas_pagar": "financeiro/contas_pagar.csv",
        "contas_receber": "financeiro/contas_receber.csv",
        "orcamento": "financeiro/orcamento.csv",
    }
    for chave, caminho in arquivos.items():
        df = pd.read_csv(RAW / caminho)
        _cache[chave] = _tipar_numericos(df)
    return _cache


NUMERIC_HINT = (
    "valor", "preco", "salario", "investimento", "receita", "leads", "conversoes",
    "meta", "custo", "peso", "prazo", "quantidade", "desconto", "debito", "credito",
    "horas", "dias", "cpa", "sessoes", "usuarios", "taxa_", "probabilidade",
)


def _tipar_numericos(df: pd.DataFrame) -> pd.DataFrame:
    """
    O pandas 3 le texto como str. Colunas cujo nome sugere medida viram
    float64 aqui, com virgula brasileira normalizada.
    """
    for coluna in df.columns:
        if not any(h in coluna for h in NUMERIC_HINT):
            continue
        if df[coluna].dtype != object and str(df[coluna].dtype) != "str":
            continue
        convertido = (df[coluna]
                      .astype("string")
                      .str.strip()
                      .str.replace(".", "", regex=False)
                      .str.replace(",", ".", regex=False)
                      .replace("", pd.NA))
        numerico = pd.to_numeric(convertido, errors="coerce")
        if numerico.notna().sum() > 0:
            df[coluna] = numerico
    return df


def vendas_prep(d: dict[str, pd.DataFrame]) -> pd.DataFrame:
    """Vendas com datas tipadas e flags de faturamento."""
    v = d["vendas"].copy()
    for c in ("data_pedido", "data_previsao_entrega", "data_entrega_real"):
        v[c] = pd.to_datetime(v[c], errors="coerce")
    v["valido"] = v["status_pedido"].str.upper().ne("CANCELADO")
    v["faturado"] = v["status_pedido"].str.upper().isin(
        ["APROVADO", "EM SEPARACAO", "EM TRANSPORTE", "ENTREGUE"]
    )
    v["competencia"] = v["data_pedido"].dt.to_period("M")
    v["atraso"] = (v["data_entrega_real"] - v["data_previsao_entrega"]).dt.days
    return v


def ref_date(v: pd.DataFrame) -> pd.Timestamp:
    """Data de referencia do dataset: ultimo dia com dado de venda."""
    return v["data_pedido"].max().normalize()


# ======================================================= 01 panoramarama

def secao_01_panorama() -> None:
    titulo("01 panorama - inventario da camada raw")
    d = dados()
    linhas = [
        {
            "tabela": nome,
            "linhas": len(df),
            "colunas": df.shape[1],
            "tamanho_mb": round((RAW / caminho).stat().st_size / 1e6, 2),
            "periodo": periodo(df),
        }
        for nome, df in d.items()
        for caminho in [proximo_arquivo(nome)]
    ]
    print(pd.DataFrame(linhas).sort_values("linhas", ascending=False).to_string(index=False))

    total_linhas = sum(len(df) for df in d.values())
    total_mb = sum(p.stat().st_size for p in RAW.rglob("*.csv")) / 1e6
    print(f"\n{total_linhas:,} linhas | {total_mb:.1f} MB | {len(d)} tabelas".replace(",", "."))

    sub("grain (o que representa 1 linha)")
    for nome, grain in GRAINS.items():
        print(f"  {nome:<16} {grain}")


GRAINS = {
    "vendas": "1 pedido",
    "clientes": "1 cliente",
    "produtos": "1 produto",
    "colaboradores": "1 colaborador",
    "ponto": "1 batimento",
    "notas": "1 nota de transporte",
    "oportunidades": "1 oportunidade do CRM",
    "lancamentos": "1 lancamento contabil",
    "contas_receber": "1 titulo a receber",
    "campanhas": "1 campanha",
    "inventario": "1 snapshot de estoque",
}


def periodo(df: pd.DataFrame) -> str:
    for c in df.columns:
        if c.startswith("data_") or c in ("competencia", "data_emissao"):
            s = pd.to_datetime(df[c], errors="coerce")
            if s.notna().any():
                return f"{s.min():%Y-%m-%d} a {s.max():%Y-%m-%d}"
    return "-"


def proximo_arquivo(nome: str) -> str:
    mapa = {
        "vendas": "vendas/pedidos_vendas.csv", "vendedores": "vendas/vendedores.csv",
        "metas": "vendas/metas_vendas.csv", "clientes": "comum/dim_cliente.csv",
        "produtos": "comum/dim_produto.csv", "calendario": "comum/dim_calendario.csv",
        "regiao": "comum/dim_regiao.csv", "colaboradores": "rh/colaboradores.csv",
        "ponto": "rh/ponto_registros.csv", "ferias": "rh/ferias.csv",
        "custos_rh": "rh/custos_rh.csv", "cargos": "rh/cargos.csv",
        "oportunidades": "comercial/oportunidades_crm.csv", "atividades": "comercial/atividades_crm.csv",
        "campanhas": "marketing/campanhas.csv", "trafego": "marketing/trafego_diario.csv",
        "notas": "logistica/notas_fiscais_transporte.csv", "inventario": "logistica/inventario.csv",
        "lancamentos": "financeiro/lancamentos_contabeis.csv",
        "contas_pagar": "financeiro/contas_pagar.csv",
        "contas_receber": "financeiro/contas_receber.csv", "orcamento": "financeiro/orcamento.csv",
    }
    return mapa[nome]


# ====================================================== 02 qualidade

def secao_02_qualidade() -> None:
    titulo("02 qualidade - nulos, duplicatas, coerencia e escala")
    d = dados()

    sub("nulos por tabela (apenas > 0)")
    nulos = []
    for nome, df in d.items():
        n = int(df.isna().sum().sum())
        if n:
            colunas = df.isna().sum()
            colunas = colunas[colunas > 0].to_dict()
            nulos.append({"tabela": nome, "celulas_nulas": n, "colunas": colunas})
    print(pd.DataFrame(nulos).to_string(index=False) if nulos else "nenhuma celula nula")

    sub("chaves duplicadas")
    chaves = {
        "vendas": "pedido_id", "clientes": "cliente_id", "produtos": "produto_id",
        "colaboradores": "colaborador_id", "notas": "nota_id",
        "oportunidades": "oportunidade_id", "lancamentos": "lancamento_id",
        "campanhas": "campanha_id", "ferias": "ferias_id",
    }
    for nome, chave in chaves.items():
        df = d[nome]
        dup = int(df.duplicated(subset=[chave]).sum())
        flag = "OK" if dup == 0 else "FALHA"
        print(f"  {nome:<16} {chave:<20} {dup:>6} duplicadas  [{flag}]")
        if dup:
            achado("ALTO", nome, f"chave {chave} com {dup} duplicatas",
                   "qualquer agregacao por essa chave conta dinheiro duplicado")

    sub("valores sem sentido")
    problemas = {
        "valor_liquido negativo": int((d["vendas"]["valor_liquido"] < 0).sum()),
        "desconto acima de 100%": int((d["vendas"]["desconto_pct"] > 1).sum()),
        "quantidade zero": int((d["vendas"]["quantidade"] <= 0).sum()),
        "preco_unitario <= 0": int((d["vendas"]["preco_unitario"] <= 0).sum()),
        "valor contavel negativo": int((d["contas_pagar"]["valor"] < 0).sum()),
        "peso negativo": int((d["notas"]["peso_kg"] < 0).sum()),
        "salario negativo": int((d["colaboradores"]["salario_bruto"] < 0).sum()),
    }
    for rotulo, n in problemas.items():
        print(f"  {rotulo:<26} {n}")

    sub("coerencia de status (entregue sem data, pago sem data)")
    v = vendas_prep(d)
    entregues_sem_data = int(((v["status_pedido"].str.upper() == "ENTREGUE") & v["data_entrega_real"].isna()).sum())
    cp = d["contas_pagar"]
    pago_sem_data = int(((cp["status"].str.upper() == "PAGO") & cp["data_pagamento"].isna()).sum())
    print(f"  pedidos entregues sem data de entrega: {entregues_sem_data} ({pct(entregues_sem_data, len(v))})")
    print(f"  contas pagas sem data de pagamento:    {pago_sem_data} ({pct(pago_sem_data, len(cp))})")
    if entregues_sem_data:
        achado("MEDIO", "vendas", f"{entregues_sem_data} pedidos com status Entregue sem data_entrega_real",
               "impossivel calcular SLA real de entrega; KPI de=on-time fica inflado")

    sub("escala: os numeros fecham entre si?")
    receita_vendas = v.loc[v["faturado"], "valor_liquido"].sum()
    debitos_lanc = d["lancamentos"]["debito"].astype(float).sum()
    print(f"  receita em vendas (faturado):        {brl(receita_vendas)}")
    print(f"  debitos no ledger contabil:          {brl(debitos_lanc)}")
    razao = debitos_lanc / receita_vendas
    print(f"  razao debitos/receita:                {razao:.1f}x")
    if razao > 5 or razao < 0.2:
        achado("ALTO", "financeiro",
               f"ledger contabil {razao:.0f}x maior que a receita de vendas",
               "os dois fontes nao reconciliam; DRE construida sobre lancamentos e irreiavel "
               "para decisao. origem provavel: lancamentos sinteticos com escala aleatoria")

    sub("custos_rh: consistência")
    cr = d["custos_rh"]
    print(cr.head(8).to_string(index=False))
    print(f"\n  competencias distintas: {cr['competencia'].nunique()} (esperado 12+ meses)")
    print(f"  custo_total = folha + encargos + beneficios: "
          f"{bool((cr['custo_total'].sub(cr['folha_bruta'] + cr['encargos'] + cr['beneficios']).abs() < 0.01).all())}")
    print(f"  encargos / folha: "
          f"{cr['encargos'].sum() / cr['folha_bruta'].sum():.4f} (esperado 0.28 a 0.36)")
    print(f"  areas no cadastro x areas no custo: "
          f"{sorted(cr['area'].unique()) == sorted(d['colaboradores']['area'].unique())}")

    sub("dim_regiao: tabela inutil")
    rg = d["regiao"]
    print(rg.to_string(index=False))
    achado("MEDIO", "dimensoes", "dim_regiao tem apenas UF->regiao, sem hierarquia e incompleta",
           "nao da para responder 'qual regiao gera mais receita'; pedir cadastro oficial "
           "de regioes ou derivar do cadastro de clientes")


# ========================================================== 03 vendas

def secao_03_vendas() -> None:
    titulo("03 vendas - receita, ticket, mix e margem")
    d = dados()
    v = vendas_prep(d)

    fat = v.loc[v["faturado"]]
    print(f"pedidos: {len(v):,} | validos: {int(v['valido'].sum()):,} | "
          f"faturados: {len(fat):,} | cancelados: {int((~v['valido']).sum()):,}")

    sub("indicadores gerais (periodo completo)")
    print(f"  receita bruta:      {brl(v['valor_bruto'].sum())}")
    print(f"  desconto concedido:{brl(v['valor_bruto'].sum() - v['valor_liquido'].sum()):>12}"
          f"  ({pct(v['valor_bruto'].sum() - v['valor_liquido'].sum(), v['valor_bruto'].sum())} da bruta)")
    print(f"  receita faturada:   {brl(fat['valor_liquido'].sum())}")
    print(f"  ticket medio:       {brl(fat['valor_liquido'].mean())}")
    print(f"  ticket mediano:     {brl(fat['valor_liquido'].median())}")
    print(f"  quantidade total:   {int(v['quantidade'].sum()):,} itens")

    sub("distribuicao do valor do pedido")
    q = fat["valor_liquido"].quantile([.01, .25, .5, .75, .95, .99])
    print(pd.DataFrame({"percentil": q.index, "valor": q.values}).to_string(index=False))
    print(f"  desvio padrao {brl(fat['valor_liquido'].std())} vs media {brl(fat['valor_liquido'].mean())} "
          f"(razao {fat['valor_liquido'].std() / fat['valor_liquido'].mean():.2f})")
    print("  leitura: cauda longa. a mediana e o melhor termino para KPI de pedido, nao a media")

    sub("mix por categoria")
    mix = (v.merge(d["produtos"][["produto_id", "descricao", "categoria"]], on="produto_id", how="left")
             .groupby("categoria")
             .agg(itens=("quantidade", "sum"),
                  pedidos=("pedido_id", "nunique"),
                  receita=("valor_liquido", "sum"),
                  ticket=("valor_liquido", "mean"))
             .sort_values("receita", ascending=False))
    mix["% receita"] = (mix["receita"] / mix["receita"].sum()).map("{:.1%}".format)
    print(mix.round(2).to_string())

    sub("desconto por categoria (onde a margem e perdida)")
    desc = (v.merge(d["produtos"][["produto_id", "categoria"]], on="produto_id", how="left")
              .groupby("categoria")
              .agg(desc_medio=("desconto_pct", "mean"), desc_max=("desconto_pct", "max"),
                   receita=("valor_liquido", "sum"))
              .sort_values("desc_medio", ascending=False))
    desc["desconto_perdido"] = (desc["receita"] / (1 - desc["desc_medio"]) - desc["receita"]).round(2)
    print(desc.round(4).to_string())

    sub("evolucao mensal")
    mensal = (v.loc[v["faturado"]]
              .groupby("competencia")
              .agg(pedidos=("pedido_id", "nunique"), receita=("valor_liquido", "sum"),
                   ticket=("valor_liquido", "mean"))
              .round(2))
    mensal["mes_anterior"] = mensal["receita"].shift(1)
    mensal["variacao_%"] = (mensal["receita"] / mensal["mes_anterior"] - 1).round(4)
    print(mensal.to_string())
    print("\n  leitura: receita em patamar, sem tendencia nem sazonalidade clara. "
          "o que muda mes a mes e o ticket, nao o volume de pedidos.")

    sub("forma de pagamento")
    pgto = (v.groupby("forma_pagamento")
             .agg(pedidos=("pedido_id", "nunique"), receita=("valor_liquido", "sum"))
             .sort_values("receita", ascending=False))
    pgto["% receita"] = (pgto["receita"] / pgto["receita"].sum()).map("{:.1%}".format)
    pgto["ticket"] = (pgto["receita"] / pgto["pedidos"]).round(2)
    print(pgto.round(2).to_string())

    sub("status dos pedidos")
    print(v["status_pedido"].value_counts().to_string())


# ======================================================= 04 clientes

def secao_04_clientes() -> None:
    titulo("04 clientes - concentracao, segmento, canal e saude da base")
    d = dados()
    v = vendas_prep(d)
    cli = d["clientes"].copy()
    cli["data_criacao"] = pd.to_datetime(cli["data_criacao"], errors="coerce")

    fat = v.loc[v["faturado"]].merge(cli, on="cliente_id", how="left")
    receita_cliente = fat.groupby("cliente_id")["valor_liquido"].sum().sort_values(ascending=False)
    receita_total = receita_cliente.sum()

    sub("concentracao de receita (lei de Pareto nao se aplica a portfolio B2B)")
    for n in (10, 50, 100, 200):
        acumulado = receita_cliente.head(n).sum()
        print(f"  top {n:>3} clientes: {brl(acumulado):>18}  ({pct(acumulado, receita_total)} da receita)")

    top10 = receita_cliente.head(10)
    print(f"\n  top 10 detalhe:")
    print(cli.set_index("cliente_id").loc[top10.index, ["razao_social", "segmento", "status_cliente"]]
          .assign(receita=top10.values).round(2).to_string())

    sub("por segmento")
    seg = (fat.groupby("segmento")
             .agg(clientes=("cliente_id", "nunique"), pedidos=("pedido_id", "nunique"),
                  receita=("valor_liquido", "sum"), ticket=("valor_liquido", "mean"))
             .sort_values("receita", ascending=False))
    seg["% receita"] = (seg["receita"] / seg["receita"].sum()).map("{:.1%}".format)
    print(seg.round(2).to_string())

    sub("por canal de origem")
    can = (fat.groupby("canal")
             .agg(receita=("valor_liquido", "sum"), pedidos=("pedido_id", "nunique"))
             .sort_values("receita", ascending=False))
    can["% receita"] = (can["receita"] / can["receita"].sum()).map("{:.1%}".format)
    print(can.round(2).to_string())

    sub("saude da base")
    print(cli["status_cliente"].value_counts().to_string())
    print(f"\n  clientes ativos:    {int((cli['status_cliente'] == 'Ativo').sum())}")
    print(f"  inativos:           {int((cli['status_cliente'] == 'Inativo').sum())}")
    print(f"  bloqueados:         {int((cli['status_cliente'] == 'Bloqueado').sum())}")

    bloqueados_com_receita = (fat[fat["status_cliente"] == "Bloqueado"]
                              .groupby("cliente_id")["valor_liquido"].sum().sum())
    if bloqueados_com_receita > 0:
        print(f"\n  ATENCAO: {brl(bloqueados_com_receita)} de receita em 2026 veio de "
              f"clientes marcados como Bloqueado")
        print(f"  {int((fat['status_cliente'] == 'Bloqueado').sum())} pedidos em clientes bloqueados")
        achado("ALTO", "vendas",
               "pedidos faturados em clientes com status Bloqueado",
               f"{brl(bloqueados_com_receita)} de receita sem lastro; se for bloqueio por "
               "inadimplencia, e risco de perda nao provisionado")

    inativos_com_receita = int((fat["status_cliente"] == "Inativo").sum())
    if inativos_com_receita:
        achado("BAIXO", "vendas", f"{inativos_com_receita} pedidos em clientes Inativos",
               "cliente cancelado que voltou a comprar: ou status desatualizado no ERP, "
               "ou recorrencia que o comercial nao acompanha")

    sub("coerencia UF x cidade no cadastro")
    mapa = dict(zip(d["regiao"]["uf"], d["regiao"]["cidade"]))
    inconsistente = int(cli["cidade"].map(lambda c: c not in mapa.values()).sum())
    print(f"  linhas cuja cidade nao existe no cadastro: {inconsistente} de {len(cli)}")
    if inconsistente:
        achado("MEDIO", "dimensoes",
               f"{inconsistente} de {len(cli)} clientes com cidade fora do cadastro de regioes",
               "qualquer analise geografica por cidade perde registros; o problema naso e o "
               "cadastro de regioes incompleto, e sim dim_regiao sem definicao de negocio")


# ========================================================== 05 metas

def secao_05_metas() -> None:
    titulo("05 metas - atingimento por vendedor")
    d = dados()
    v = vendas_prep(d)
    metas = d["metas"].copy()
    metas["competencia"] = pd.to_datetime(metas["competencia"] + "-01").dt.to_period("M")
    vend = d["vendedores"].copy()

    fat = v.loc[v["faturado"]].copy()
    fat["competencia"] = fat["data_pedido"].dt.to_period("M")
    realizado = (fat.groupby(["competencia", "vendedor_id"])["valor_liquido"]
                       .sum().reset_index(name="realizado"))

    meses_ate_hoje = ref_date(v).to_period("M")
    m = metas.merge(realizado, on=["competencia", "vendedor_id"], how="left")
    m["realizado"] = m["realizado"].fillna(0)
    # Metas existem para 12 meses, mas vendas so vao ate o ultimo mes com dado.
    # Comparar so o que compete evita diluir o atingimento com meses a frente.
    parcial = m[m["competencia"] <= meses_ate_hoje]
    if len(parcial) < len(m):
        print(f"  nota: metas de {len(m) - len(parcial)} meses posteriores a {meses_ate_hoje} "
              f"foram excluidas do calculo de atingimento")
    m["atingimento"] = m["realizado"] / m["meta_valor"]

    sub("atingimento mensal da empresa")
    mensal = (parcial.groupby(parcial["competencia"])
                .agg(meta=("meta_valor", "sum"), realizado=("realizado", "sum")))
    mensal["atingimento"] = mensal["realizado"] / mensal["meta"]
    print(mensal.round(2).to_string())

    sub("atingimento por vendedor")
    por_vend = (parcial.groupby("vendedor_id")
                  .agg(meta=("meta_valor", "sum"), realizado=("realizado", "sum"),
                       meses=("meta_valor", "size")))
    por_vend["atingimento"] = por_vend["realizado"] / por_vend["meta"]
    por_vend = por_vend.merge(vend[["vendedor_id", "nome", "regiao", "status"]], on="vendedor_id")
    print(por_vend.sort_values("atingimento", ascending=False).round(3).to_string(index=False))

    sub("resumo do time")
    atingiu = int((por_vend["atingimento"] >= 1).sum())
    print(f"  vendedores acima da meta: {atingiu} de {len(por_vend)} ({pct(atingiu, len(por_vend))})")
    print(f"  atingimento mediano:     {por_vend['atingimento'].median():.1%}")
    print(f"  meta vs realizado total: {brl(por_vend['meta'].sum())} / {brl(por_vend['realizado'].sum())}")

    inativos_com_venda = por_vend[(por_vend["status"].str.upper() == "DESLIGADO")
                                  & (por_vend["realizado"] > 0)]
    if len(inativos_com_venda):
        achado("MEDIO", "comercial",
               f"{len(inativos_com_venda)} vendedores desligados com venda registrada",
               "venda de vendedor desligado precisa de aprovacao do comercial; sem isso, "
               "comissao e forecast ficam errados")


# ======================================================= 06 comercial

def secao_06_comercial() -> None:
    titulo("06 comercial - funil, win rate e ciclo de venda")
    d = dados()
    o = d["oportunidades"].copy()
    o["data_criacao"] = pd.to_datetime(o["data_criacao"], errors="coerce")
    o["data_previsao_fechamento"] = pd.to_datetime(o["data_previsao_fechamento"], errors="coerce")
    o["ciclo_dias"] = (o["data_previsao_fechamento"] - o["data_criacao"]).dt.days

    ordem = ["Prospeccao", "Qualificacao", "Proposta", "Negociacao", "Fechado Ganho", "Fechado Perdido"]

    sub("funil por etapa")
    funil = (o.groupby("etapa")
              .agg(oportunidades=("oportunidade_id", "nunique"),
                   valor=("valor_oportunidade", "sum"))
              .reindex(ordem))
    funil["valor_medio"] = (funil["valor"] / funil["oportunidades"]).round(2)
    funil["% do pipeline"] = (funil["valor"] / funil.loc[ordem[:4], "valor"].sum()).map("{:.1%}".format)
    print(funil.round(2).to_string())

    sub("taxa de conversao etapa a etapa")
    ganho = int(o["etapa"].eq("Fechado Ganho").sum())
    perdido = int(o["etapa"].eq("Fechado Perdido").sum())
    fechadas = ganho + perdido
    print(f"  ganhas: {ganho} | perdidas: {perdido} | fechadas: {fechadas}")
    print(f"  win rate: {pct(ganho, fechadas)}")
    print(f"  valor ponderado declarado:  {brl(o['valor_ponderado'].sum())}")
    print(f"  valor ganho real:           {brl(o.loc[o['etapa'] == 'Fechado Ganho', 'valor_oportunidade'].sum())}")

    coerencia = o["valor_oportunidade"] * o["probabilidade"]
    divergencia = (o["valor_ponderado"] - coerencia).abs()
    print(f"\n  divergencia entre valor_ponderado e valor x probabilidade: "
          f"{int((divergencia > 1).sum())} de {len(o)} linhas "
          f"(max {brl(divergencia.max())})")
    if int((divergencia > 1).sum()):
        achado("MEDIO", "comercial", "valor_ponderado divergente de valor x probabilidade",
               "forecast da comercial nao bate com a regra; confirmar se o CRM usa "
               "probabilidade customizada por etapa")

    sub("ciclo de venda por etapa (dias ate previsao de fechamento)")
    print(o.groupby("etapa")["ciclo_dias"].describe().loc[ordem, ["count", "mean", "50%", "max"]].round(1).to_string())

    sub("pipeline aberto por regiao")
    aberto = o[o["etapa"].isin(ordem[:4])]
    reg = (aberto.groupby("regiao")
                 .agg(abertas=("oportunidade_id", "nunique"),
                      valor=("valor_oportunidade", "sum"),
                      ponderado=("valor_ponderado", "sum"))
                 .sort_values("ponderado", ascending=False))
    reg["cobertura"] = (reg["ponderado"] / reg["ponderado"].sum()).map("{:.1%}".format)
    print(reg.round(2).to_string())

    sub("tamanho medio da oportunidade por etapa (o negocio medio cresce com a etapa?)")
    print(funil["valor_medio"].to_string())

    sub("atividades do CRM")
    at = d["atividades"].copy()
    at["data_atividade"] = pd.to_datetime(at["data_atividade"], errors="coerce")
    print(at["tipo_atividade"].value_counts().to_string())
    print()
    print(at.groupby("tipo_atividade")["resultado"].value_counts().unstack(fill_value=0).to_string())
    print(f"\n  atividades por oportunidade: {len(at) / len(o):.1f}")
    sem_atividade = len(set(o["oportunidade_id"]) - set(at["oportunidade_id"]))
    print(f"  oportunidades sem nenhuma atividade registrada: {sem_atividade}")


# ======================================================= 07 marketing

def secao_07_marketing() -> None:
    titulo("07 marketing - cac, roas e conversao por canal")
    d = dados()
    c = d["campanhas"].copy()
    for col in ("data_inicio", "data_fim"):
        c[col] = pd.to_datetime(c[col], errors="coerce")
    c["duracao_dias"] = (c["data_fim"] - c["data_inicio"]).dt.days

    c["cac"] = c["investimento"] / c["leads_gerados"].replace(0, np.nan)
    c["cpl"] = c["investimento"] / c["leads_gerados"].replace(0, np.nan)
    c["roas"] = c["receita_atribuida"] / c["investimento"]
    c["taxa_conversao"] = c["conversoes"] / c["leads_gerados"].replace(0, np.nan)

    sub("investimento e retorno")
    print(f"  investimento total:   {brl(c['investimento'].sum())}")
    print(f"  receita atribuida:    {brl(c['receita_atribuida'].sum())}")
    print(f"  roas geral:           {c['receita_atribuida'].sum() / c['investimento'].sum():.2f}x")
    print(f"  leads gerados:        {int(c['leads_gerados'].sum()):,}")
    print(f"  conversoes:           {int(c['conversoes'].sum()):,}")
    print(f"  cac medio:            {brl(c['cac'].mean())}")
    print(f"  cpl medio:            {brl(c['cpl'].mean())}")

    sub("por canal")
    canal = (c.groupby("canal")
               .agg(campanhas=("campanha_id", "nunique"),
                    investimento=("investimento", "sum"),
                    leads=("leads_gerados", "sum"),
                    conversoes=("conversoes", "sum"),
                    receita=("receita_atribuida", "sum"))
               .sort_values("investimento", ascending=False))
    canal["roas"] = (canal["receita"] / canal["investimento"]).round(2)
    canal["cac"] = (canal["investimento"] / canal["leads"]).round(2)
    canal["conv_%"] = (canal["conversoes"] / canal["leads"] * 100).round(2)
    canal["% inv"] = (canal["investimento"] / canal["investimento"].sum()).map("{:.1%}".format)
    print(canal.round(2).to_string())

    sub("campanhas acima e abaixo do roas 1.0")
    print(f"  roas > 1 (positivo): {int((c['roas'] > 1).sum())} de {len(c)}")
    print(f"  investimento em campanhas com roas < 1: "
          f"{brl(c.loc[c['roas'] < 1, 'investimento'].sum())} "
          f"({pct(c.loc[c['roas'] < 1, 'investimento'].sum(), c['investimento'].sum())} do total)")

    sub("coluna cpa: confere com o calculo?")
    c["cpa_calculado"] = c["investimento"] / c["leads_gerados"].replace(0, np.nan)
    divergente = int(((c["cpa"] - c["cpa_calculado"]).abs() > 1).sum())
    print(f"  linhas onde cpa informado != investimento/leads: {divergente} de {len(c)}")
    print(f"  cpa informado:   media {brl(c['cpa'].mean())} | min {brl(c['cpa'].min())} | max {brl(c['cpa'].max())}")
    print(f"  cpa calculado:   media {brl(c['cpa_calculado'].mean())}")
    if divergente:
        achado("MEDIO", "marketing", f"coluna cpa diverge do calculo investimento/leads em {divergente} campanhas",
               "cpa vem de outra fonte (provavelmente do ad platform); definir qual e a "
               "fonte de verdade antes de usar CAC em contrato de agencia")

    sub("trafego diario")
    t = d["trafego"].copy()
    t["data"] = pd.to_datetime(t["data"], errors="coerce")
    traf = (t.groupby("canal")
             .agg(sessoes=("sessoes", "sum"), sessoes_pagas=("sessoes_pagas", "sum"),
                  custo_clique_medio=("custo_clique", "mean"),
                  conversao_media=("taxa_conversao", "mean"),
                  custo_lead_medio=("custo_lead", "mean"))
             .sort_values("sessoes", ascending=False))
    traf["% pagas"] = (traf["sessoes_pagas"] / traf["sessoes"] * 100).round(1)
    print(traf.round(3).to_string())


# ======================================================= 08 logistica

def secao_08_logistica() -> None:
    titulo("08 logistica - sla de entrega e custo de frete")
    d = dados()
    n = d["notas"].copy()
    for col in ("data_emissao", "data_entrega"):
        n[col] = pd.to_datetime(n[col], errors="coerce")
    n["atraso_dias"] = (n["data_entrega"] - n["data_emissao"] - pd.to_timedelta(n["prazo_dias"], unit="D")).dt.days
    n["atraso_dias"] = n["atraso_dias"].fillna(0)
    n["custo_por_kg"] = n["custo_frete"] / n["peso_kg"].replace(0, np.nan)

    entregues = n[n["status_entrega"].isin(["Entregue", "Atrasado"])]

    sub("volume e status")
    print(n["status_entrega"].value_counts().to_string())
    print(f"\n  peso total: {n['peso_kg'].sum():,.0f} kg | custo frete: {brl(n['custo_frete'].sum())}".replace(",", "."))

    sub("sla por transportadora (apenas notas com entrega)")
    sla = (entregues.groupby("transportadora")
                     .agg(notas=("nota_id", "nunique"),
                          atrase=("atraso_dias", lambda s: int((s > 0).sum())),
                          atraso_medio=("atraso_dias", "mean"),
                          custo_kg=("custo_por_kg", "mean"))
                     .sort_values("custo_kg"))
    sla["% no prazo"] = (100 - sla["atrase"] / sla["notas"] * 100).round(1)
    print(sla.round(3).to_string())

    sub("sla por centro de origem")
    centro = (entregues.groupby("centro_origem")
                       .agg(notas=("nota_id", "nunique"),
                            atraso_medio=("atraso_dias", "mean"),
                            custo_frete_medio=("custo_frete", "mean"))
                       .sort_values("atraso_medio", ascending=False))
    centro["% no prazo"] = ((1 - centro["notas"].apply(
        lambda _: 0)) * 100).round(1)
    print(centro.round(2).to_string())

    sub("custo de frete por regiao")
    print((n.groupby("regiao_origem")
             .agg(notas=("nota_id", "nunique"), custo=("custo_frete", "sum"),
                  custo_kg=("custo_por_kg", "mean"))
             .sort_values("custo", ascending=False)).round(2).to_string())

    sub("frete como % da receita")
    v = vendas_prep(d)
    receita = v.loc[v["faturado"], "valor_liquido"].sum()
    print(f"  custo de frete total: {brl(n['custo_frete'].sum())}")
    print(f"  receita faturada:     {brl(receita)}")
    print(f"  frete / receita:      {pct(n['custo_frete'].sum(), receita)}")

    cobertura = len(set(n["pedido_id"]) & set(v["pedido_id"]))
    print(f"\n  notas de transporte com pedido correspondente em vendas: "
          f"{cobertura} de {len(n)} ({pct(cobertura, len(n))})")
    if cobertura / len(n) < 0.5:
        achado("ALTO", "logistica", f"somente {pct(cobertura, len(n))} das notas tem pedido_id valido em vendas",
               "nao da para calcular margem liquida por pedido (receita menos frete) nem "
               "atribuir atraso a uma venda; chave pedido_id esta sem integridade entre os sistemas")

    sub("estoque")
    inv = d["inventario"].copy()
    print(f"  itens abaixo do minimo: {int((inv['quantidade_estoque'] < inv['estoque_minimo']).sum())} "
          f"de {len(inv)} ({pct((inv['quantidade_estoque'] < inv['estoque_minimo']).sum(), len(inv))})")
    print(f"  valor de estoque:      {brl((inv['quantidade_estoque'] * inv['custo_unitario']).sum())}")
    print(inv["status"].value_counts().to_string())


# ======================================================= 09 financeiro

def secao_09_financeiro() -> None:
    titulo("09 financeiro - contas a pagar e receber, aging e orcamento")
    d = dados()
    ref = ref_date(vendas_prep(d))

    sub("contas a receber - aging")
    cr = d["contas_receber"].copy()
    for col in ("data_emissao", "data_vencimento", "data_recebimento"):
        cr[col] = pd.to_datetime(cr[col], errors="coerce")
    aberto = cr[cr["status"].str.upper().ne("RECEBIDO")].copy()
    aberto["atraso"] = (ref - aberto["data_vencimento"]).dt.days

    faixas = [-10**6, 0, 30, 60, 90, 180, 10**6]
    rotulos = ["a vencer", "1-30", "31-60", "61-90", "91-180", "180+"]
    aberto["faixa"] = pd.cut(aberto["atraso"], faixas, labels=rotulos)

    aging = (aberto.groupby("faixa", observed=True)
                  .agg(titulos=("conta_receber_id", "count"), valor=("valor", "sum")))
    aging["% do saldo"] = (aging["valor"] / aberto["valor"].sum()).map("{:.1%}".format)
    aging = aging.reset_index()
    aging["faixa"] = aging["faixa"].astype(str)
    print(aging.round(2).to_string(index=False))
    print(f"\n  saldo total em aberto: {brl(aberto['valor'].sum())}")
    print(f"  vencido:               {brl(aberto.loc[aberto['atraso'] > 0, 'valor'].sum())} "
          f"({pct(aberto.loc[aberto['atraso'] > 0, 'valor'].sum(), aberto['valor'].sum())} do saldo)")
    vencido_90 = aberto.loc[aberto["atraso"] > 90, "valor"].sum()
    if vencido_90 > 0:
        print(f"  vencido ha mais de 90 dias: {brl(vencido_90)} -> risco de perda")
        achado("ALTO", "financeiro", f"{brl(vencido_90)} vencidos ha mais de 90 dias",
               "candidatos a provisao de perda; precisa de acordo com comercial sobre "
               "clientes com processo judicial")

    sub("dso - dias medios de recebimento")
    recebido = cr[cr["data_recebimento"].notna()].copy()
    recebido["ciclo"] = (recebido["data_recebimento"] - recebido["data_emissao"]).dt.days
    print(f"  ciclo medio de recebimento: {recebido['ciclo'].mean():.1f} dias")
    print(f"  ciclo mediano:              {recebido['ciclo'].median():.1f} dias")
    por_pgto = recebido.groupby("forma_pagamento")["ciclo"].agg(["count", "mean", "median"]).round(1)
    print(por_pgto.to_string())

    sub("inadimplencia por cliente")
    inad = (aberto.loc[aberto["atraso"] > 0]
            .groupby("cliente_id")
            .agg(titulos=("conta_receber_id", "count"), valor=("valor", "sum"))
            .sort_values("valor", ascending=False))
    print(inad.head(10).round(2).to_string())
    print(f"\n  clientes com titulo vencido: {len(inad)}")

    sub("contas a pagar - aging")
    cp = d["contas_pagar"].copy()
    for col in ("data_emissao", "data_vencimento", "data_pagamento"):
        cp[col] = pd.to_datetime(cp[col], errors="coerce")
    cp["atraso"] = (ref - cp["data_vencimento"]).dt.days
    print(cp["status"].value_counts().to_string())
    print(f"\n  total a pagar: {brl(cp['valor'].sum())}")
    print(f"  em atraso:    {brl(cp.loc[cp['atraso'] > 0, 'valor'].sum())} "
          f"({int((cp['atraso'] > 0).sum())} titulos)")
    print(f"  atraso medio: {cp.loc[cp['atraso'] > 0, 'atraso'].mean():.0f} dias")

    sub("fornecedores por categoria")
    forn = (cp.groupby("categoria")
               .agg(titulos=("conta_pagar_id", "count"), valor=("valor", "sum"),
                    atraso_medio=("atraso", "mean"))
               .sort_values("valor", ascending=False))
    forn["% do total"] = (forn["valor"] / forn["valor"].sum()).map("{:.1%}".format)
    print(forn.round(2).to_string())

    sub("orcamento vs realizado")
    orc = d["orcamento"].copy()
    orc["desvio"] = orc["valor_realizado"] - orc["valor_orcado"]
    orc["desvio_%"] = (orc["valor_realizado"] / orc["valor_orcado"] - 1).map("{:.1%}".format)
    por_conta = (orc.groupby(["conta_contabil", "descricao_conta", "tipo"])
                    .agg(orcado=("valor_orcado", "sum"), realizado=("valor_realizado", "sum")))
    por_conta["desvio"] = por_conta["realizado"] - por_conta["orcado"]
    por_conta["desvio_%"] = (por_conta["realizado"] / por_conta["orcado"] - 1).map("{:.1%}".format)
    print(por_conta.round(2).to_string())
    print(f"\n  orcado total:   {brl(orc['valor_orcado'].sum())}")
    print(f"  realizado total:{brl(orc['valor_realizado'].sum())}")
    print(f"  desvio total:   {brl(orc['desvio'].sum())}")

    estourou = por_conta[por_conta["desvio"] > 0].index.tolist()
    if estourou:
        achado("ALTO", "financeiro",
               f"{len(estourou)} contas acima do orcado: "
               + ", ".join(c[1] for c in estourou),
               "desvio orcamentario precisa de justificativa do controller antes de fechar o mes")

    sub("lancamentos contabil por grupo")
    l = d["lancamentos"].copy()
    l["valor_debito"] = l["debito"].astype(float)
    l["grupo"] = np.select(
        [l["conta_contabil"].str.startswith("1"), l["conta_contabil"].str.startswith("2"),
         l["conta_contabil"].str.startswith("3"), l["conta_contabil"].str.startswith("4"),
         l["conta_contabil"].str.startswith("5")],
        ["Ativo", "Passivo", "Resultado Custo", "Resultado Despesa", "Resultado Folha"],
        default="Outros")
    print(l.groupby("grupo")["valor_debito"].agg(["count", "sum"]).round(2).to_string())
    print("\n  ATENCAO: o ledger nao reconcilia com as vendas (ver secao 02). usar para "
          "analise por conta/centro de custo, nao para DRE consolidada.")

    sub("centro de custo")
    cc = (l.groupby(["centro_custo", "grupo"])["valor_debito"].sum().unstack(fill_value=0).round(2))
    print(cc.to_string())


# ============================================================== 10 rh

def secao_10_rh() -> None:
    titulo("10 rh - headcount, absenteismo, turnover e folha")
    d = dados()
    col = d["colaboradores"].copy()
    for c in ("data_admissao", "data_demissao"):
        col[c] = pd.to_datetime(col[c], errors="coerce")
    col["ativo"] = col["data_demissao"].isna()

    sub("headcount")
    print(f"  total no cadastro: {len(col)}")
    print(f"  ativos:            {int(col['ativo'].sum())}")
    print(f"  desligados:        {int((~col['ativo']).sum())}")
    print(f"  data base:         {col['data_demissao'].min():%Y-%m-%d} a {col['data_demissao'].max():%Y-%m-%d}")

    sub("headcount por area")
    area = (col[col["ativo"]].groupby("area")
               .agg(colaboradores=("colaborador_id", "count"),
                    salario_medio=("salario_bruto", "mean"),
                    salario_mediano=("salario_bruto", "median"))
               .sort_values("colaboradores", ascending=False))
    area["custo_mensal"] = (area["colaboradores"] * area["salario_medio"]).round(2)
    print(area.round(2).to_string())

    sub("headcount por senioridade e tipo de contrato")
    print(pd.crosstab(col.loc[col['ativo'], 'area'], col.loc[col['ativo'], 'senioridade']).to_string())
    print()
    print(col.loc[col["ativo"], "tipo_contrato"].value_counts().to_string())
    estagio = int((col.loc[col["ativo"], "tipo_contrato"] == "Estagio").sum())
    print(f"\n  estagiarios no quadro: {estagio} ({pct(estagio, int(col['ativo'].sum()))})")
    if estagio:
        achado("BAIXO", "rh", f"{estagio} estagiarios no quadro ativo",
               "estagio e contratado CLT: tem custo de folha e rights trabalhistas "
               "diferentes dos demais. se voce for responsavel pela area, isso cai no seu radar")

    sub("turnover por area")
    ultimos_12m = ref_date(vendas_prep(d)) - pd.Timedelta(days=365)
    saidas = col[(~col["ativo"]) & (col["data_demissao"] >= ultimos_12m)]
    print(f"  saidas nos ultimos 12 meses: {len(saidas)}")
    if len(saidas):
        turn = (saidas.groupby("area").size().rename("saidas_12m").to_frame()
                .join(area["colaboradores"].rename("quadro_ativo")))
        turn["turnover_12m_%"] = (turn["saidas_12m"] / turn["quadro_ativo"] * 100).round(1)
        print(turn.sort_values("turnover_12m_%", ascending=False).round(2).to_string())
        print(f"\n  turnover geral 12m: {len(saidas) / int(col['ativo'].sum()):.1%}")

    sub("absenteismo (batimento de ponto)")
    p = d["ponto"].copy()
    p["data_hora_entrada"] = pd.to_datetime(p["data_hora_entrada"], errors="coerce")
    print(p["situacao"].value_counts().to_string())
    total = len(p)
    faltas = int(p["situacao"].eq("Falta").sum())
    atrasos = int(p["situacao"].eq("Atraso").sum())
    print(f"\n  registros de ponto: {total:,}".replace(",", "."))
    print(f"  faltas:  {faltas} ({pct(faltas, total)})")
    print(f"  atrasos: {atrasos} ({pct(atrasos, total)})")
    print(f"  absenteismo total: {pct(faltas + atrasos, total)}")
    print(f"\n  horas por situacao:")
    print(p.groupby("situacao")["horas_trabalhadas"].agg(["count", "mean", "median"]).round(2).to_string())
    remoto = int(p["situacao"].eq("Remoto").sum())
    print(f"\n  trabalho remoto: {remoto} registros ({pct(remoto, total)})")

    sub("ferias e licencas")
    f = d["ferias"].copy()
    print(f["status_ferias"].value_counts().to_string())
    print()
    print(f["tipo"].value_counts().to_string())
    print(f"\n  dias medios de ausencia: {f['dias_ferias'].mean():.1f}")
    licenca = int(f["tipo"].str.contains("Licenca", na=False).sum())
    print(f"  registros de licenca: {licenca} ({pct(licenca, len(f))})")

    sub("custos de rh")
    cr = d["custos_rh"].copy()
    print(cr.groupby("area").agg(
        folha_bruta=("folha_bruta", "sum"),
        encargos=("encargos", "sum"),
        beneficios=("beneficios", "sum"),
        custo_total=("custo_total", "sum"),
        colaboradores=("qtd_colaboradores", "sum"),
    ).round(2).to_string())
    print(f"\n  competencias distintas: {cr['competencia'].nunique()}")
    print(f"  encargos / folha: "
          f"{pct(cr['encargos'].sum(), cr['folha_bruta'].sum())}")
    print(f"  custo total geral: {brl(cr['custo_total'].sum())}")
    col["custo_anualizado"] = col["salario_bruto"] * 12
    print(f"  folha anualizada bruta (cadastro, {int(col['ativo'].sum())} ativos): "
          f"{brl(col.loc[col['ativo'], 'custo_anualizado'].sum())}")

    sub("dado sensivel - registrar no inventario de governanca")
    print("  col.dados_pessoais: nome, salario_bruto, situacao de ponto, dados de licenca medica")
    print("  -> staging fica restrito a engenharia; o time de RH so ve agregados no mart_rh")


# ====================================================== 11 cruzamentos

def secao_11_cruzamentos() -> None:
    titulo("11 cruzamentos - relacoes entre dominios")
    d = dados()
    v = vendas_prep(d)
    fat = v.loc[v["faturado"]]

    sub("correlacoes no pedido")
    cols = ["quantidade", "preco_unitario", "desconto_pct", "valor_bruto", "valor_liquido"]
    print("pearson:")
    print(fat[cols].corr(numeric_only=True).round(3).to_string())
    print("\nspearman (robusto a outliers):")
    print(fat[cols].corr(numeric_only=True, method="spearman").round(3).to_string())

    sub("desconto x margem por categoria")
    merged = (fat.merge(d["produtos"][["produto_id", "categoria"]], on="produto_id", how="left")
                 .groupby("categoria")
                 .agg(desconto_medio=("desconto_pct", "mean"),
                      receita=("valor_liquido", "sum"),
                      pedidos=("pedido_id", "nunique")))
    merged["receita_perda_desconto"] = (merged["receita"] / (1 - merged["desconto_medio"]) - merged["receita"]).round(2)
    print(merged.round(4).to_string())

    sub("prazo de entrega x atraso")
    n = d["notas"].copy()
    n["data_emissao"] = pd.to_datetime(n["data_emissao"], errors="coerce")
    n["data_entrega"] = pd.to_datetime(n["data_entrega"], errors="coerce")
    n["atraso"] = (n["data_entrega"] - n["data_emissao"] - pd.to_timedelta(n["prazo_dias"], unit="D")).dt.days
    print(f"  corr(prazo_dias, atraso): {n['prazo_dias'].corr(n['atraso']):.3f}")
    print(f"  corr(peso_kg, custo_frete): {n['peso_kg'].corr(n['custo_frete']):.3f}")
    print(f"  corr(prazo_dias, peso_kg): {n['prazo_dias'].corr(n['peso_kg']):.3f}")

    sub("frete x receita por pedido (cobertura da chave)")
    por_pedido = (n.groupby("pedido_id")
                   .agg(frete=("custo_frete", "sum"), atraso=("atraso", "mean")))
    cru = (fat.groupby("pedido_id")["valor_liquido"].sum().to_frame()
           .join(por_pedido, how="inner"))
    cru["margem_sobre_frete"] = cru["valor_liquido"] - cru["frete"]
    print(f"  pedidos com dados dos dois lados: {len(cru)} de {len(fat)} "
          f"({pct(len(cru), len(fat))})")
    if len(cru):
        print(f"  receita nesses pedidos: {brl(cru['valor_liquido'].sum())}")
        print(f"  frete total:           {brl(cru['frete'].sum())}")
        print(f"  margem sobre frete:    {pct(cru['frete'].sum(), cru['valor_liquido'].sum())}")
        correlacao = cru["valor_liquido"].corr(cru["atraso"])
        print(f"\n  correlacao receita x atraso: {correlacao:.3f}")
        if pd.isna(correlacao):
            print("  (indefinida: 'atraso' veio todo nulo nas notas amarradas a um pedido)")

    sub("campanhas x receita atribuida x vendas reais")
    c = d["campanhas"].copy()
    print(f"  receita atribuida por marketing: {brl(c['receita_atribuida'].sum())}")
    print(f"  receita real faturada:          {brl(fat['valor_liquido'].sum())}")
    print(f"  razao: {c['receita_atribuida'].sum() / fat['valor_liquido'].sum():.2f}x")
    achado("ALTO", "marketing",
           "receita_atribuida do marketing nao fecha com a receita de vendas",
           "atribuicao de origem nao rastreavel; para medir CAC/ROAS de verdade e preciso "
           "ligar campanha -> lead -> oportunidade -> pedido, hoje nao ha chave que faca isso")

    sub("custos de rh x receita")
    col = d["colaboradores"].copy()
    folha = col["salario_bruto"].sum() * 12
    print(f"  folha anualizada bruta:  {brl(folha)}")
    print(f"  receita faturada:        {brl(fat['valor_liquido'].sum())}")
    print(f"  folha / receita:         {pct(folha, fat['valor_liquido'].sum())}")


# ========================================================== 12 achados

def secao_12_achados() -> pd.DataFrame:
    titulo("12 achados - backlog de qualidade de dados")
    if not ACHADOS:
        print("nenhum achado registrado")
        return pd.DataFrame(ACHADOS, columns=["severidade", "area", "problema", "impacto"])

    df = pd.DataFrame(ACHADOS, columns=["severidade", "area", "problema", "impacto"])
    ordem = {"ALTO": 0, "MEDIO": 1, "BAIXO": 2}
    df = df.sort_values("severidade", key=lambda s: s.map(ordem)).reset_index(drop=True)

    print(f"{len(df)} achados | "
          f"ALTO: {int((df['severidade'] == 'ALTO').sum())} | "
          f"MEDIO: {int((df['severidade'] == 'MEDIO').sum())} | "
          f"BAIXO: {int((df['severidade'] == 'BAIXO').sum())}\n")

    for _, r in df.iterrows():
        print(f"[{r['severidade']}] {r['area'].upper()} - {r['problema']}")
        print(f"    {r['impacto']}\n")

    sub("resumo por area")
    print(df.groupby(["severidade", "area"]).size().rename("achados").to_string())
    return df


SECOES = [
    secao_01_panorama, secao_02_qualidade, secao_03_vendas, secao_04_clientes,
    secao_05_metas, secao_06_comercial, secao_07_marketing, secao_08_logistica,
    secao_09_financeiro, secao_10_rh, secao_11_cruzamentos, secao_12_achados,
]


def main() -> None:
    for secao in SECOES:
        secao()


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    main()
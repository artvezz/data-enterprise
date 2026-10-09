"""
Gerador de dados sintéticos para o projeto Data Enterprise.

Simula os sistemas de origem de cada area e grava arquivos CSV na camada raw,
com sujeira proposital (nulos, duplicatas, tipos divergentes, datas em formatos
mistos) para que a camada de ingestao e o dbt tenham o que corrigir.

Uso:
    python scripts/gerar_dados.py --linhas-vendas 8000
"""

from __future__ import annotations

import argparse
import csv
import random
from datetime import date, datetime, time, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"

random.seed(42)

# ---------------------------------------------------------------- dimensoes

CARGOS = [
    ("Analista de Dados", "Tecnologia", "Pleno"),
    ("Engenheiro de Dados", "Tecnologia", "Senior"),
    ("Cientista de Dados", "Tecnologia", "Senior"),
    ("Desenvolvedor Backend", "Tecnologia", "Pleno"),
    ("Gerente de Dados", "Tecnologia", "Lideranca"),
    ("Assistente Administrativo", "Administrativo", "Junior"),
    ("Analista Financeiro", "Financeiro", "Pleno"),
    ("Coordenador Financeiro", "Financeiro", "Coordenacao"),
    ("Analista de RH", "Recursos Humanos", "Pleno"),
    ("Business Partner de RH", "Recursos Humanos", "Senior"),
    ("Recrutador", "Recursos Humanos", "Pleno"),
    ("Representante de Vendas", "Comercial", "Junior"),
    ("Executivo de Contas", "Comercial", "Pleno"),
    ("Gerente Regional", "Comercial", "Lideranca"),
    ("Analista de Marketing", "Marketing", "Pleno"),
    ("Especialista em Marketing Digital", "Marketing", "Senior"),
    ("Analista de Logistica", "Operacoes", "Pleno"),
    ("Supervisor de Centro de Distribuicao", "Operacoes", "Coordenacao"),
]

ESTADOS = [
    ("SP", "Sao Paulo"), ("RJ", "Rio de Janeiro"), ("MG", "Minas Gerais"),
    ("PR", "Parana"), ("RS", "Rio Grande do Sul"), ("SC", "Santa Catarina"),
    ("BA", "Bahia"), ("PE", "Pernambuco"), ("CE", "Ceara"), ("GO", "Goias"),
    ("DF", "Distrito Federal"), ("AM", "Amazonas"), ("PR", "Parana"),
]

UFS_SIGLA = [e[0] for e in ESTADOS]

PRODUTOS = [
    ("PRD-1001", "Notebook Pro 14", "Hardware", 6890.00),
    ("PRD-1002", "Notebook Air 13", "Hardware", 4290.00),
    ("PRD-1003", "Monitor 27 4K", "Hardware", 2190.00),
    ("PRD-1004", "Teclado Mecanico", "Periferico", 749.00),
    ("PRD-1005", "Mouse Vertical", "Periferico", 289.00),
    ("PRD-1006", "Headset Noise Cancel", "Periferico", 1190.00),
    ("PRD-1007", "Licenca Software Pro", "Software", 899.00),
    ("PRD-1008", "Licenca Suite Analytics", "Software", 2490.00),
    ("PRD-1009", "Assinamento Cloud Mensal", "Servico", 349.00),
    ("PRD-1010", "Suporte Premium 24/7", "Servico", 599.00),
    ("PRD-1011", "Impressora LaserCorp", "Hardware", 1890.00),
    ("PRD-1012", "Rack de Rede 12U", "Infra", 4590.00),
]

SEGMENTOS = ["Corporativo Grande", "Corporativo Medio", "Pequeno Empresa", "Governo", "Educacao"]
CANAIS = ["Direto", "Parceiro", "E-commerce", "Licitacao"]
REGIOES = ["Sudeste", "Sul", "Nordeste", "Centro-Oeste", "Norte"]

CENTROS = [
    ("CD-SP", "Sao Paulo", "Sudeste"), ("CD-RJ", "Rio de Janeiro", "Sudeste"),
    ("CD-BH", "Belo Horizonte", "Sudeste"), ("CD-CWB", "Curitiba", "Sul"),
    ("CD-POA", "Porto Alegre", "Sul"), ("CD-REC", "Recife", "Nordeste"),
    ("CD-FOR", "Fortaleza", "Nordeste"), ("CD-GRU", "Goiania", "Centro-Oeste"),
]
TRANSPORTADORAS = ["TransRodon", "LogExpress", "CargoSul", "RapidoCarga", "Rodofacil"]
CUSTOS_CENTRO = {"CD-SP": 1.15, "CD-RJ": 1.22, "CD-BH": 1.08, "CD-CWB": 1.02,
                 "CD-POA": 1.18, "CD-REC": 1.30, "CD-FOR": 1.28, "CD-GRU": 0.98}

FORMAS_PAGTO = ["Pix", "Cartao Credito", "Boleto", "Transferencia", "Longa Prazo"]
STATUS_PEDIDO = ["Aprovado", "Aprovado", "Aprovado", "Em Separacao", "Em Transporte",
                 "Entregue", "Entregue", "Cancelado"]
DIAS_HISTORICO = 540


def uf_aleatorio() -> str:
    return random.choice(UFS_SIGLA)


def escrever(caminho: Path, cabecalho: list[str], linhas) -> None:
    caminho.parent.mkdir(parents=True, exist_ok=True)
    with caminho.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh)
        w.writerow(cabecalho)
        w.writerows(linhas)
    print(f"  {caminho.relative_to(ROOT).as_posix():<52} {caminho.stat().st_size / 1024:8.1f} KB")


# ------------------------------------------------------------------- comum

def gerar_calendario() -> list[date]:
    hoje = date(2026, 9, 30)
    return [hoje - timedelta(days=i) for i in range(DIAS_HISTORICO)][::-1]


def gerar_dimensoes():
    escrever(RAW / "comum" / "dim_calendario.csv",
             ["data", "ano", "mes", "mes_nome", "trimestre", "semana", "dia_semana", "is_util"],
             [[d.isoformat(), d.year, d.month, d.strftime("%B"), (d.month - 1) // 3 + 1,
               d.isocalendar()[1], d.strftime("%A"), int(d.weekday() < 5)] for d in gerar_calendario()])

    escrever(RAW / "comum" / "dim_produto.csv",
             ["produto_id", "descricao", "categoria", "preco_lista", "ativo"],
             [[p[0], p[1], p[2], f"{p[3]:.2f}", "S" if random.random() > 0.08 else "N"] for p in PRODUTOS])

    escrever(RAW / "comum" / "dim_cliente.csv",
             ["cliente_id", "razao_social", "segmento", "uf", "cidade", "canal",
              "data_criacao", "status_cliente"],
             [[f"CLI-{i:05d}",
               f"{random.choice(['Alpha','Beta','Gamma','Delta','Epsilon','Zeta','Omega','Sigma','Aurora','Vertex'])} "
               f"{random.choice(['Ind','Log','Tech','Srv','Com','Corp','Group'])} {i:03d} LTDA",
               random.choice(SEGMENTOS), uf_aleatorio(),
               dict((u, c) for u, c in ESTADOS).get(uf_aleatorio(), "Outra"),
               random.choice(CANAIS),
               (date(2019, 1, 1) + timedelta(days=random.randint(0, 2500))).isoformat(),
               random.choice(["Ativo", "Ativo", "Ativo", "Inativo", "Bloqueado"])]
              for i in range(1, 601)])

    escrever(RAW / "comum" / "dim_regiao.csv",
             ["regiao", "uf", "cidade"],
             sorted({(r, u, c) for u, c in ESTADOS for r in REGIOES
                     if (r == "Sudeste" and u in ("SP", "RJ", "MG")) or
                        (r == "Sul" and u in ("PR", "RS", "SC")) or
                        (r == "Nordeste" and u in ("BA", "PE", "CE")) or
                        (r == "Centro-Oeste" and u == "GO") or
                        (r == "Centro-Oeste" and u == "DF") or
                        (r == "Norte" and u == "AM")}))


# --------------------------------------------------------------------- rh

def gerar_rh(calendario):
    colaboradores = []
    for i in range(1, 481):
        cargo, area, senioridade = random.choice(CARGOS)
        data_adm = random.choice(calendario[:400])
        uf = uf_aleatorio()
        colaboradores.append({
            "colaborador_id": f"COL-{i:05d}",
            "nome": f"{random.choice(['Ana','Bruno','Carla','Diego','Elisa','Felipe','Gabriela','Henrique','Isabela','Joao','Karina','Lucas','Mariana','Nicolas','Olivia','Paulo','Queila','Rafael','Sofia','Thiago'])} "
                    f"{random.choice(['Silva','Santos','Oliveira','Souza','Rodrigues','Ferreira','Alves','Pereira','Lima','Carvalho','Gomes','Ribeiro','Martins','Araujo','Barbosa'])}",
            "cargo": cargo, "area": area, "senioridade": senioridade,
            "uf": uf, "cidade": "Sao Paulo" if uf == "SP" else "Outra",
            "data_admissao": data_adm.isoformat(),
            "data_demissao": "",
            "salario_bruto": round(random.uniform(2800, 24000), 2),
            "tipo_contrato": random.choice(["CLT", "CLT", "CLT", "PJ", "Estagio", "Terceirizado"]),
            "status": "Ativo",
        })
        # ~18% desligados em algum momento do historico
        if random.random() < 0.18:
            demissao = data_adm + timedelta(days=random.randint(180, 3000))
            if demissao <= calendario[-1]:
                colaboradores[-1]["data_demissao"] = demissao.isoformat()
                colaboradores[-1]["status"] = "Desligado"

    escrever(RAW / "rh" / "colaboradores.csv",
             list(colaboradores[0].keys()),
             [[c[k] for k in colaboradores[0].keys()] for c in colaboradores])

    escrever(RAW / "rh" / "ferias.csv",
             ["ferias_id", "colaborador_id", "data_inicio", "data_fim", "dias_ferias",
              "status_ferias", "tipo"],
             [[f"FER-{i:06d}", random.choice(colaboradores)["colaborador_id"],
               (d := random.choice(calendario)).isoformat(),
               (d + timedelta(days=random.randint(5, 30))).isoformat(),
               random.randint(5, 30), random.choice(["Aprovado", "Aprovado", "Pendente", "Recusado"]),
               random.choice(["Ferias", "Ferias", "Licenca Medica", "Licenca Maternidade", "Ferias"])]
              for i in range(1, 2201)])

    # folha ponto: 3 registros por dia para ~90 colaboradores, ~= 110k linhas
    ponto = []
    col_ids = [c["colaborador_id"] for c in colaboradores][:90]
    for i, cid in enumerate(col_ids):
        for d in random.sample(calendario, 140):
            if d.weekday() < 5 and random.random() < 0.95:
                entrada = datetime.combine(d, time(random.randint(7, 10), random.randint(0, 59)))
                saida = datetime.combine(d, time(random.randint(17, 21), random.randint(0, 59)))
                ponto.append([f"PON-{len(ponto):08d}", cid, f"{entrada:%Y-%m-%d %H:%M}",
                              f"{saida:%H:%M}",
                              round((saida - entrada).seconds / 3600 - 1, 2),
                              random.choice(["Presente", "Presente", "Presente", "Falta", "Atraso", "Remoto"])])
    escrever(RAW / "rh" / "ponto_registros.csv",
             ["ponto_id", "colaborador_id", "data_hora_entrada", "hora_saida", "horas_trabalhadas", "situacao"],
             ponto)

    escrever(RAW / "rh" / "cargos.csv",
             ["cargo_id", "descricao_cargo", "area", "senioridade", "faixa_salarial_min", "faixa_salarial_max"],
             [[f"CAR-{i:03d}", c[0], c[1], c[2], round(random.uniform(2200, 9000), 2),
               round(random.uniform(12000, 32000), 2)] for i, c in enumerate(CARGOS, 1)])

    areas_rh = sorted({c0["area"] for c0 in colaboradores})
    competencias_rh = []
    ano, mes = calendario[-1].year, calendario[-1].month
    for _ in range(18):
        competencias_rh.append(f"{ano:04d}-{mes:02d}")
        mes -= 1
        if mes == 0:
            ano, mes = ano - 1, 12
    competencias_rh.reverse()

    custos_rh = []
    for comp in competencias_rh:
        for area in areas_rh:
            base = sum(x["salario_bruto"] for x in colaboradores if x["area"] == area)
            folha = round(base * random.uniform(0.95, 1.06), 2)
            encargos = round(folha * random.uniform(0.28, 0.36), 2)
            beneficios = round(folha * random.uniform(0.12, 0.2), 2)
            custos_rh.append([comp, area, folha, encargos, beneficios,
                              round(folha + encargos + beneficios, 2),
                              len([x for x in colaboradores if x["area"] == area])])
    escrever(RAW / "rh" / "custos_rh.csv",
             ["competencia", "area", "folha_bruta", "encargos", "beneficios", "custo_total", "qtd_colaboradores"],
             custos_rh)


# ----------------------------------------------------------------- vendas

def gerar_vendas(calendario, qtd):
    pedidos = []
    for i in range(1, qtd + 1):
        d = random.choices(calendario, weights=[1 + (0.9 if random.random() < 0.6 else 0) for _ in calendario])[0]
        produto = random.choice(PRODUTOS)
        cliente = f"CLI-{random.randint(1, 600):05d}"
        qtd_item = random.randint(1, 20)
        desconto = random.choice([0, 0, 0, 0.03, 0.05, 0.08, 0.12, 0.15])
        bruto = round(produto[3] * qtd_item, 2)
        liquido = round(bruto * (1 - desconto), 2)
        status = random.choice(STATUS_PEDIDO)
        pedidos.append([
            f"PED-{i:07d}", cliente, produto[0], d.isoformat(),
            f"REP-{random.randint(1, 40):03d}", qtd_item, f"{produto[3]:.2f}",
            f"{desconto:.2f}", f"{bruto:.2f}", f"{liquido:.2f}",
            random.choice(FORMAS_PAGTO), status,
            f"{d + timedelta(days=random.randint(1, 12))}" if status != "Cancelado" else "",
            "",
        ])
    escrever(RAW / "vendas" / "pedidos_vendas.csv",
             ["pedido_id", "cliente_id", "produto_id", "data_pedido", "vendedor_id",
              "quantidade", "preco_unitario", "desconto_pct", "valor_bruto",
              "valor_liquido", "forma_pagamento", "status_pedido",
              "data_previsao_entrega", "data_entrega_real"], pedidos)

    escrever(RAW / "vendas" / "vendedores.csv",
             ["vendedor_id", "nome", "regiao", "meta_mensal", "data_admissao", "status"],
             [[f"REP-{i:03d}", f"Vendedor {i:03d}", random.choice(REGIOES),
               round(random.uniform(80000, 450000), 2),
               random.choice(calendario[:400]).isoformat(),
               random.choice(["Ativo", "Ativo", "Ativo", "Desligado"])]
              for i in range(1, 41)])

    escrever(RAW / "vendas" / "metas_vendas.csv",
             ["vendedor_id", "competencia", "meta_valor"],
             [[f"REP-{v:03d}", c.strftime("%Y-%m"), round(random.uniform(80000, 450000), 2)]
              for c in calendario[-12:] for v in range(1, 41)])

    # ------------------------------------------------------- comercial (CRM)

    oportunidades = []
    for i in range(1, int(qtd * 0.55) + 1):
        d = random.choices(calendario, weights=[1] * len(calendario))[0]
        etapa = random.choices(
            ["Prospeccao", "Qualificacao", "Proposta", "Negociacao", "Fechado Ganho", "Fechado Perdido"],
            weights=[20, 18, 16, 16, 18, 12])[0]
        valor = round(random.uniform(5000, 900000), 2)
        prob = {"Prospeccao": 0.1, "Qualificacao": 0.25, "Proposta": 0.5,
                "Negociacao": 0.75, "Fechado Ganho": 1.0, "Fechado Perdido": 0.0}[etapa]
        oportunidades.append([
            f"OPP-{i:07d}", f"CLI-{random.randint(1, 600):05d}", d.isoformat(),
            etapa, valor, prob,
            round(valor * prob, 2), random.choice(REGIOES),
            f"REP-{random.randint(1, 40):03d}",
            random.choice(["Ativo", "Ativo", "Convertida", "Perdida", "Sem contato"]),
            (d + timedelta(days=random.randint(1, 45))).isoformat(),
        ])
    escrever(RAW / "comercial" / "oportunidades_crm.csv",
             ["oportunidade_id", "cliente_id", "data_criacao", "etapa", "valor_oportunidade",
              "probabilidade", "valor_ponderado", "regiao", "vendedor_id",
              "status_oportunidade", "data_previsao_fechamento"], oportunidades)

    escrever(RAW / "comercial" / "atividades_crm.csv",
             ["atividade_id", "oportunidade_id", "data_atividade", "tipo_atividade",
              "resultado", "duracao_min", "vendedor_id"],
             [[f"ATI-{i:08d}", f"OPP-{random.randint(1, int(qtd * 0.55)):07d}",
               random.choice(calendario).isoformat(),
               random.choice(["Call", "Email", "Reuniao", "Visita", "Proposta enviada"]),
               random.choice(["Positivo", "Positivo", "Neutro", "Negativo"]),
               random.randint(10, 180), f"REP-{random.randint(1, 40):03d}"]
              for i in range(1, 9001)])

    # ------------------------------------------------------------ marketing

    campanhas = []
    for i in range(1, 61):
        inicio = random.choice(calendario[:-7])
        fim = min(inicio + timedelta(days=random.randint(14, 90)), calendario[-1])
        investimento = round(random.uniform(3000, 250000), 2)
        leads = random.randint(20, 1800)
        conversao = random.uniform(0.01, 0.12)
        campanhas.append([
            f"CMP-{i:04d}", f"{random.choice(['Search','Social','Display','Video','Email','Influencer'])} "
            f"{random.choice(['Branding','Performance','Retencao','Lancamento','Topo','Fundo'])}",
            random.choice(CANAIS), inicio.isoformat(), fim.isoformat(),
            f"{investimento:.2f}", leads, round(leads * conversao, 0),
            f"{investimento * random.uniform(1.3, 6.0):.2f}",
            f"{random.uniform(1800, 9500):.2f}", random.choice(["Ativa", "Encerrada", "Pausada"]),
        ])
    escrever(RAW / "marketing" / "campanhas.csv",
             ["campanha_id", "nome_campanha", "canal", "data_inicio", "data_fim",
              "investimento", "leads_gerados", "conversoes", "receita_atribuida", "cpa", "status"], campanhas)

    escrever(RAW / "marketing" / "trafego_diario.csv",
             ["data", "canal", "sessoes", "sessoes_pagas", "usuarios_unicos",
              "taxa_conversao", "custo_clique", "custo_lead"],
             [[d.isoformat(), c, random.randint(400, 9000), random.randint(50, 3000),
               random.randint(300, 7000), round(random.uniform(0.005, 0.09), 4),
               round(random.uniform(0.4, 8.5), 2), round(random.uniform(12, 260), 2)]
              for d in random.sample(calendario, 300) for c in ["Organic", "Paid Search", "Paid Social", "Email", "Referral"]])

    # ------------------------------------------------------------- logistica

    notas = []
    for i in range(1, int(qtd * 0.8) + 1):
        d = random.choice(calendario)
        origem, _, regiao_o = random.choice(CENTROS)
        destino = f"CD-{random.choice(UFS_SIGLA)[0:2]}" if random.random() < 0.3 else random.choice([c[0] for c in CENTROS])
        peso = round(random.uniform(5, 900), 2)
        dias = max(1, round(abs(random.gauss(6, 3)) * CUSTOS_CENTRO[origem]))
        status = random.choices(["Em Separacao", "Em Transporte", "Entregue", "Atrasado", "Cancelado"],
                                weights=[10, 15, 55, 15, 5])[0]
        custo = round(peso * random.uniform(1.2, 4.8) + 45 * CUSTOS_CENTRO[origem], 2)
        notas.append([
            f"NF-{i:08d}", origem, destino, d.isoformat(), f"PED-{random.randint(1, qtd):07d}",
            transportadora if (transportadora := random.choice(TRANSPORTADORAS)) else "",
            f"{peso:.2f}", dias,
            (d + timedelta(days=dias)).isoformat(),
            f"{custo:.2f}", status, regiao_o,
        ])
    escrever(RAW / "logistica" / "notas_fiscais_transporte.csv",
             ["nota_id", "centro_origem", "centro_destino", "data_emissao", "pedido_id",
              "transportadora", "peso_kg", "prazo_dias", "data_entrega", "custo_frete",
              "status_entrega", "regiao_origem"], notas)

    escrever(RAW / "logistica" / "inventario.csv",
             ["centro_id", "produto_id", "data_snapshot", "quantidade_estoque",
              "estoque_minimo", "custo_unitario", "status"],
             [[c[0], p[0], random.choice(calendario).isoformat(), random.randint(0, 800),
               random.randint(20, 120), f"{p[3] * random.uniform(0.45, 0.7):.2f}",
               random.choice(["Normal", "Normal", "Baixo", "Repor"])]
              for c in CENTROS for p in PRODUTOS for _ in range(3)])

    # ------------------------------------------------------------ financeiro

    escrever(RAW / "financeiro" / "lancamentos_contabeis.csv",
             ["lancamento_id", "data_lancamento", "data_competencia", "conta_contabil",
              "descricao", "tipo", "debito", "credito", "centro_custo", "projeto",
              "documento_origem"],
             [[f"LAN-{i:09d}",
               (d := random.choice(calendario)).isoformat(),
               d.isoformat(),
               conta, desc, tipo,
               f"{random.uniform(50, 120000):.2f}" if tipo == "D" else "0.00",
               "0.00" if tipo == "D" else f"{random.uniform(50, 120000):.2f}",
               random.choice(["CC-1001", "CC-1002", "CC-2001", "CC-3001", "CC-4001"]),
               random.choice(["P&L-CORE", "P&L-MKT", "P&L-RD", "CAPEX-2026", "OPEX-2026"]),
               random.choice(["NF", "CT", "FOLHA", "CONTRATO", "TRANSF"])]
              for i in range(1, 25001)
              for conta, desc, tipo in random.sample([
                  ("1.1.01.001", "Recebimento de Clientes", "D"),
                  ("1.1.01.002", "Duplicatas a Receber", "D"),
                  ("2.1.01.001", "Fornecedores de Mercadorias", "C"),
                  ("2.1.01.002", "Obrigacoes Trabalhistas", "C"),
                  ("3.2.01.001", "Custo dos Produtos Vendidos", "D"),
                  ("3.3.01.001", "Despesas com Vendas", "D"),
                  ("3.3.01.002", "Despesas com Marketing", "D"),
                  ("4.1.01.001", "Despesas Administrativas", "D"),
                  ("4.2.01.001", "Impostos sobre a Receita", "D"),
                  ("5.1.01.001", "Folha de Pagamento", "D"),
              ], 1)])

    escrever(RAW / "financeiro" / "contas_pagar.csv",
             ["conta_pagar_id", "fornecedor", "categoria", "data_emissao", "data_vencimento",
              "data_pagamento", "valor", "status", "centro_custo"],
             [[f"CP-{i:08d}",
               f"{random.choice(['Fornecedor','Distribuidora','Servico','Imobiliaria','TI'])} {random.choice(chr(65)+chr(90))}{i % 40:02d} LTDA",
               random.choice(["Fornecedor", "Servico", "Imoveis", "Software", "Logistica", "RH", "Utilidades"]),
               (d := random.choice(calendario)).isoformat(),
               (d + timedelta(days=random.randint(15, 60))).isoformat(),
               (d + timedelta(days=random.randint(5, 70))).isoformat() if random.random() < 0.8 else "",
               f"{random.uniform(800, 250000):.2f}",
               random.choice(["Pago", "Pago", "Pago", "Aberto", "Atrasado", "Atrasado"]),
               random.choice(["CC-1001", "CC-1002", "CC-2001", "CC-3001"])]
              for i in range(1, 4001)])

    escrever(RAW / "financeiro" / "contas_receber.csv",
             ["conta_receber_id", "cliente_id", "pedido_id", "data_emissao", "data_vencimento",
              "data_recebimento", "valor", "status", "forma_pagamento"],
             [[f"CR-{i:08d}", f"CLI-{random.randint(1, 600):05d}",
               f"PED-{random.randint(1, qtd):07d}",
               (d := random.choice(calendario)).isoformat(),
               (d + timedelta(days=random.choice([28, 30, 45, 60]))).isoformat(),
               (d + timedelta(days=random.randint(20, 75))).isoformat() if random.random() < 0.82 else "",
               f"{random.uniform(500, 180000):.2f}",
               random.choice(["Recebido", "Recebido", "Recebido", "Aberto", "Vencido"]),
               random.choice(FORMAS_PAGTO)]
              for i in range(1, 5001)])

    escrever(RAW / "financeiro" / "orcamento.csv",
             ["ano", "mes", "conta_contabil", "descricao_conta", "tipo",
              "valor_orcado", "valor_realizado", "centro_custo"],
             [[2026, m, conta, desc, tipo,
               f"{random.uniform(50000, 4000000):.2f}", f"{random.uniform(40000, 4200000):.2f}",
               random.choice(["CC-1001", "CC-2001", "CC-3001", "CC-4001"])]
              for m in range(1, 10)
              for conta, desc, tipo in random.sample([
                  ("3.2.01.001", "Custo dos Produtos Vendidos", "Custo"),
                  ("3.3.01.001", "Despesas com Vendas", "Despesa"),
                  ("3.3.01.002", "Despesas com Marketing", "Despesa"),
                  ("4.1.01.001", "Despesas Administrativas", "Despesa"),
                  ("5.1.01.001", "Folha de Pagamento", "Despesa"),
                  ("1.1.01.001", "Receita Bruta", "Receita"),
              ], 4)])


def main() -> None:
    p = argparse.ArgumentParser(description="Gera dados sinteticos para a camada raw")
    p.add_argument("--linhas-vendas", type=int, default=8000,
                   help="Quantidade de pedidos de venda (default 8000)")
    args = p.parse_args()

    print("Gerando dados sinteticos...\n")
    calendario = gerar_calendario()
    print("[1/6] Dimensoes comuns")
    gerar_dimensoes()
    print("[2/6] Recursos Humanos")
    gerar_rh(calendario)
    print("[3/6] Vendas e comercial")
    gerar_vendas(calendario, args.linhas_vendas)
    print("[4/6] Marketing")
    print("[5/6] Logistica")
    print("[6/6] Financeiro")
    print("\nConcluido.")


if __name__ == "__main__":
    main()
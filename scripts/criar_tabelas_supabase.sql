-- DDL para Supabase (Postgres)
-- Cria schema raw e todas as tabelas com base nos CSVs gerados
-- Cole no SQL Editor do Supabase e rode uma unica vez

CREATE SCHEMA IF NOT EXISTS raw;

-- COMUM
CREATE TABLE IF NOT EXISTS raw.dim_calendario (
  data DATE PRIMARY KEY,
  ano INT,
  mes INT,
  mes_nome TEXT,
  trimestre INT,
  semana INT,
  dia_semana TEXT,
  is_util INT
);

CREATE TABLE IF NOT EXISTS raw.dim_produto (
  produto_id TEXT PRIMARY KEY,
  descricao TEXT,
  categoria TEXT,
  preco_lista NUMERIC(18,2),
  ativo TEXT
);

CREATE TABLE IF NOT EXISTS raw.dim_cliente (
  cliente_id TEXT PRIMARY KEY,
  razao_social TEXT,
  segmento TEXT,
  uf TEXT,
  cidade TEXT,
  canal TEXT,
  data_criacao DATE,
  status_cliente TEXT
);

CREATE TABLE IF NOT EXISTS raw.dim_regiao (
  regiao TEXT,
  uf TEXT,
  cidade TEXT
);

-- RH
CREATE TABLE IF NOT EXISTS raw.colaboradores (
  colaborador_id TEXT PRIMARY KEY,
  nome TEXT,
  cargo TEXT,
  area TEXT,
  senioridade TEXT,
  uf TEXT,
  cidade TEXT,
  data_admissao DATE,
  data_demissao TEXT,
  salario_bruto NUMERIC(18,2),
  tipo_contrato TEXT,
  status TEXT,
  ingestion_timestamp TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS raw.ferias (
  ferias_id TEXT PRIMARY KEY,
  colaborador_id TEXT,
  data_inicio DATE,
  data_fim DATE,
  dias_ferias INT,
  status_ferias TEXT,
  tipo TEXT,
  ingestion_timestamp TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS raw.ponto_registros (
  ponto_id TEXT PRIMARY KEY,
  colaborador_id TEXT,
  data_hora_entrada TIMESTAMP,
  hora_saida TEXT,
  horas_trabalhadas NUMERIC(6,2),
  situacao TEXT,
  ingestion_timestamp TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS raw.cargos (
  cargo_id TEXT PRIMARY KEY,
  descricao_cargo TEXT,
  area TEXT,
  senioridade TEXT,
  faixa_salarial_min NUMERIC(18,2),
  faixa_salarial_max NUMERIC(18,2)
);

CREATE TABLE IF NOT EXISTS raw.custos_rh (
  competencia TEXT,
  area TEXT,
  folha_bruta NUMERIC(18,2),
  encargos NUMERIC(18,2),
  beneficios NUMERIC(18,2),
  custo_total NUMERIC(18,2),
  qtd_colaboradores INT,
  ingestion_timestamp TIMESTAMP WITH TIME ZONE
);

-- VENDAS
CREATE TABLE IF NOT EXISTS raw.pedidos_vendas (
  pedido_id TEXT PRIMARY KEY,
  cliente_id TEXT,
  produto_id TEXT,
  data_pedido DATE,
  vendedor_id TEXT,
  quantidade INT,
  preco_unitario NUMERIC(18,2),
  desconto_pct NUMERIC(6,4),
  valor_bruto NUMERIC(18,2),
  valor_liquido NUMERIC(18,2),
  forma_pagamento TEXT,
  status_pedido TEXT,
  data_previsao_entrega DATE,
  data_entrega_real DATE,
  ingestion_timestamp TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS raw.vendedores (
  vendedor_id TEXT PRIMARY KEY,
  nome TEXT,
  regiao TEXT,
  meta_mensal NUMERIC(18,2),
  data_admissao DATE,
  status TEXT
);

CREATE TABLE IF NOT EXISTS raw.metas_vendas (
  vendedor_id TEXT,
  competencia TEXT,
  meta_valor NUMERIC(18,2)
);

-- COMERCIAL
CREATE TABLE IF NOT EXISTS raw.oportunidades_crm (
  oportunidade_id TEXT PRIMARY KEY,
  cliente_id TEXT,
  data_criacao DATE,
  etapa TEXT,
  valor_oportunidade NUMERIC(18,2),
  probabilidade NUMERIC(5,4),
  valor_ponderado NUMERIC(18,2),
  regiao TEXT,
  vendedor_id TEXT,
  status_oportunidade TEXT,
  data_previsao_fechamento DATE
);

CREATE TABLE IF NOT EXISTS raw.atividades_crm (
  atividade_id TEXT PRIMARY KEY,
  oportunidade_id TEXT,
  data_atividade DATE,
  tipo_atividade TEXT,
  resultado TEXT,
  duracao_min INT,
  vendedor_id TEXT
);

-- MARKETING
CREATE TABLE IF NOT EXISTS raw.campanhas (
  campanha_id TEXT PRIMARY KEY,
  nome_campanha TEXT,
  canal TEXT,
  data_inicio DATE,
  data_fim DATE,
  investimento NUMERIC(18,2),
  leads_gerados INT,
  conversoes NUMERIC(12,2),
  receita_atribuida NUMERIC(18,2),
  cpa NUMERIC(18,2),
  status TEXT
);

CREATE TABLE IF NOT EXISTS raw.trafego_diario (
  data DATE,
  canal TEXT,
  sessoes INT,
  sessoes_pagas INT,
  usuarios_unicos INT,
  taxa_conversao NUMERIC(8,4),
  custo_clique NUMERIC(10,2),
  custo_lead NUMERIC(10,2)
);

-- LOGISTICA
CREATE TABLE IF NOT EXISTS raw.notas_fiscais_transporte (
  nota_id TEXT PRIMARY KEY,
  centro_origem TEXT,
  centro_destino TEXT,
  data_emissao DATE,
  pedido_id TEXT,
  transportadora TEXT,
  peso_kg NUMERIC(12,2),
  prazo_dias INT,
  data_entrega DATE,
  custo_frete NUMERIC(18,2),
  status_entrega TEXT,
  regiao_origem TEXT
);

CREATE TABLE IF NOT EXISTS raw.inventario (
  centro_id TEXT,
  produto_id TEXT,
  data_snapshot DATE,
  quantidade_estoque INT,
  estoque_minimo INT,
  custo_unitario NUMERIC(18,2),
  status TEXT
);

-- FINANCEIRO
CREATE TABLE IF NOT EXISTS raw.lancamentos_contabeis (
  lancamento_id TEXT PRIMARY KEY,
  data_lancamento DATE,
  data_competencia DATE,
  conta_contabil TEXT,
  descricao TEXT,
  tipo TEXT,
  debito NUMERIC(18,2),
  credito NUMERIC(18,2),
  centro_custo TEXT,
  projeto TEXT,
  documento_origem TEXT,
  ingestion_timestamp TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS raw.contas_pagar (
  conta_pagar_id TEXT PRIMARY KEY,
  fornecedor TEXT,
  categoria TEXT,
  data_emissao DATE,
  data_vencimento DATE,
  data_pagamento TEXT,
  valor NUMERIC(18,2),
  status TEXT,
  centro_custo TEXT,
  ingestion_timestamp TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS raw.contas_receber (
  conta_receber_id TEXT PRIMARY KEY,
  cliente_id TEXT,
  pedido_id TEXT,
  data_emissao DATE,
  data_vencimento DATE,
  data_recebimento TEXT,
  valor NUMERIC(18,2),
  status TEXT,
  forma_pagamento TEXT,
  ingestion_timestamp TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS raw.orcamento (
  ano INT,
  mes INT,
  conta_contabil TEXT,
  descricao_conta TEXT,
  tipo TEXT,
  valor_orcado NUMERIC(18,2),
  valor_realizado NUMERIC(18,2),
  centro_custo TEXT
);

-- Schemas para marts por time
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS intermediate;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS marts;
CREATE SCHEMA IF NOT EXISTS qualidade;
CREATE SCHEMA IF NOT EXISTS mart_financeiro;
CREATE SCHEMA IF NOT EXISTS mart_rh;
CREATE SCHEMA IF NOT EXISTS mart_vendas;
CREATE SCHEMA IF NOT EXISTS mart_comercial;
CREATE SCHEMA IF NOT EXISTS mart_marketing;
CREATE SCHEMA IF NOT EXISTS mart_logistica;
CREATE SCHEMA IF NOT EXISTS mart_bi;
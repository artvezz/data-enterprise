-- 03_mart_financeiro.sql
-- MART Financeiro: aging de recebiveis, contas a pagar e orcamento

CREATE SCHEMA IF NOT EXISTS mart_financeiro;

-- CONTAS A RECEBER
DROP VIEW IF EXISTS staging.stg_contas_receber CASCADE;
CREATE OR REPLACE VIEW staging.stg_contas_receber AS
SELECT
  conta_receber_id,
  cliente_id,
  pedido_id,
  data_emissao::DATE AS data_emissao,
  data_vencimento::DATE AS data_vencimento,
  NULLIF(TRIM(data_recebimento), '')::DATE AS data_recebimento,
  valor::NUMERIC(18,2) AS valor,
  UPPER(TRIM(status)) AS status,
  UPPER(TRIM(forma_pagamento)) AS forma_pagamento,
  ingestion_timestamp
FROM raw.contas_receber;

-- CONTAS A PAGAR
DROP VIEW IF EXISTS staging.stg_contas_pagar CASCADE;
CREATE OR REPLACE VIEW staging.stg_contas_pagar AS
SELECT
  conta_pagar_id,
  UPPER(TRIM(fornecedor)) AS fornecedor,
  UPPER(TRIM(categoria)) AS categoria,
  data_emissao::DATE AS data_emissao,
  data_vencimento::DATE AS data_vencimento,
  NULLIF(TRIM(data_pagamento), '')::DATE AS data_pagamento,
  valor::NUMERIC(18,2) AS valor,
  UPPER(TRIM(status)) AS status,
  centro_custo,
  ingestion_timestamp
FROM raw.contas_pagar;

-- LANCAMENTOS
DROP VIEW IF EXISTS staging.stg_lancamentos CASCADE;
CREATE OR REPLACE VIEW staging.stg_lancamentos AS
SELECT
  lancamento_id,
  data_lancamento::DATE AS data_lancamento,
  data_competencia::DATE AS data_competencia,
  conta_contabil,
  descricao,
  UPPER(TRIM(tipo)) AS tipo,
  debito::NUMERIC(18,2) AS valor_debito,
  credito::NUMERIC(18,2) AS valor_credito,
  centro_custo,
  projeto,
  documento_origem,
  ingestion_timestamp,
  DATE_TRUNC('month', data_competencia)::DATE AS competencia
FROM raw.lancamentos_contabeis;

-- ORCAMENTO
DROP VIEW IF EXISTS staging.stg_orcamento CASCADE;
CREATE OR REPLACE VIEW staging.stg_orcamento AS
SELECT
  ano,
  mes,
  conta_contabil,
  descricao_conta,
  tipo,
  valor_orcado::NUMERIC(18,2) AS valor_orcado,
  valor_realizado::NUMERIC(18,2) AS valor_realizado,
  centro_custo,
  (ano::TEXT || '-' || LPAD(mes::TEXT,2,'0')) AS competencia_char,
  TO_DATE((ano::TEXT || '-' || LPAD(mes::TEXT,2,'0') || '-01'), 'YYYY-MM-DD') AS competencia
FROM raw.orcamento;

-- RECEBER ABERTO (usando data_ref = ultimo dia de pedidos)
DROP TABLE IF EXISTS mart_financeiro.aging_contas_receber;
CREATE TABLE mart_financeiro.aging_contas_receber AS
WITH ref AS (
  SELECT MAX(data_pedido)::DATE AS data_ref FROM staging.stg_pedidos_vendas
),
aberto AS (
  SELECT
    cr.*,
    r.data_ref,
    (r.data_ref - cr.data_vencimento) AS atraso_dias
  FROM staging.stg_contas_receber cr, ref r
  WHERE cr.status <> 'RECEBIDO'
)
SELECT
  cliente_id,
  COUNT(*) AS titulos,
  SUM(valor) AS valor_aberto,
  SUM(CASE WHEN atraso_dias > 0 THEN valor ELSE 0 END) AS valor_vencido,
  SUM(CASE WHEN atraso_dias > 90 THEN valor ELSE 0 END) AS valor_vencido_90,
  SUM(CASE WHEN atraso_dias > 0 AND atraso_dias <= 30 THEN valor ELSE 0 END) AS faixa_1_30,
  SUM(CASE WHEN atraso_dias > 30 AND atraso_dias <= 60 THEN valor ELSE 0 END) AS faixa_31_60,
  SUM(CASE WHEN atraso_dias > 60 AND atraso_dias <= 90 THEN valor ELSE 0 END) AS faixa_61_90,
  SUM(CASE WHEN atraso_dias > 90 AND atraso_dias <= 180 THEN valor ELSE 0 END) AS faixa_91_180,
  SUM(CASE WHEN atraso_dias > 180 THEN valor ELSE 0 END) AS faixa_180_mais
FROM aberto
GROUP BY 1
ORDER BY valor_aberto DESC;

DROP TABLE IF EXISTS mart_financeiro.saldo_contas_receber;
CREATE TABLE mart_financeiro.saldo_contas_receber AS
WITH ref AS (
  SELECT MAX(data_pedido)::DATE AS data_ref FROM staging.stg_pedidos_vendas
),
aberto AS (
  SELECT cr.*, r.data_ref, (r.data_ref - cr.data_vencimento) AS atraso_dias
  FROM staging.stg_contas_receber cr, ref r
  WHERE cr.status <> 'RECEBIDO'
)
SELECT
  'TOTAL' AS grupo,
  SUM(valor) AS saldo_aberto,
  SUM(CASE WHEN atraso_dias > 0 THEN valor ELSE 0 END) AS vencido,
  ROUND(SUM(CASE WHEN atraso_dias > 0 THEN valor ELSE 0 END) / NULLIF(SUM(valor),0), 4) AS pct_vencido
FROM aberto;

DROP TABLE IF EXISTS mart_financeiro.contas_pagar_aging;
CREATE TABLE mart_financeiro.contas_pagar_aging AS
WITH ref AS (
  SELECT MAX(data_pedido)::DATE AS data_ref FROM staging.stg_pedidos_vendas
)
SELECT
  categoria,
  COUNT(*) AS titulos,
  SUM(valor) AS valor_total,
  SUM(CASE WHEN status <> 'PAGO' AND (ref.data_ref - data_vencimento) > 0 THEN valor ELSE 0 END) AS valor_em_atraso
FROM staging.stg_contas_pagar cp, ref
GROUP BY 1
ORDER BY valor_total DESC;

DROP TABLE IF EXISTS mart_financeiro.orcamento_vs_realizado;
CREATE TABLE mart_financeiro.orcamento_vs_realizado AS
SELECT
  competencia,
  descricao_conta,
  tipo,
  SUM(valor_orcado) AS valor_orcado,
  SUM(valor_realizado) AS valor_realizado,
  (SUM(valor_realizado) - SUM(valor_orcado)) AS desvio,
  ROUND((SUM(valor_realizado) / NULLIF(SUM(valor_orcado),0)) - 1, 4) AS desvio_pct
FROM staging.stg_orcamento
GROUP BY 1,2,3
ORDER BY competencia, ABS(SUM(valor_realizado) - SUM(valor_orcado)) DESC;

GRANT USAGE ON SCHEMA mart_financeiro TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA mart_financeiro TO anon, authenticated;
GRANT USAGE ON SCHEMA staging TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA staging TO anon, authenticated;
-- 01_staging_vendas.sql
-- STAGING: limpa e padroniza dados de vendas (camada staging)

CREATE SCHEMA IF NOT EXISTS staging;

DROP VIEW IF EXISTS staging.stg_pedidos_vendas CASCADE;
CREATE OR REPLACE VIEW staging.stg_pedidos_vendas AS
SELECT
  pedido_id,
  cliente_id,
  produto_id,
  data_pedido::DATE AS data_pedido,
  vendedor_id,
  quantidade::INT AS quantidade,
  preco_unitario::NUMERIC(18,2) AS preco_unitario,
  desconto_pct::NUMERIC(6,4) AS desconto_pct,
  valor_bruto::NUMERIC(18,2) AS valor_bruto,
  valor_liquido::NUMERIC(18,2) AS valor_liquido,
  UPPER(TRIM(forma_pagamento)) AS forma_pagamento,
  UPPER(TRIM(status_pedido)) AS status_pedido,
  data_previsao_entrega::DATE AS data_previsao_entrega,
  data_entrega_real::DATE AS data_entrega_real,
  ingestion_timestamp,
  (UPPER(TRIM(status_pedido)) <> 'CANCELADO') AS pedido_valido,
  (UPPER(TRIM(status_pedido)) IN ('APROVADO','EM SEPARACAO','EM TRANSPORTE','ENTREGUE')) AS faturado,
  COALESCE(data_entrega_real, data_previsao_entrega) AS data_referencia_entrega,
  CASE
    WHEN data_entrega_real IS NOT NULL AND data_previsao_entrega IS NOT NULL
      THEN GREATEST((data_entrega_real - data_previsao_entrega), 0)
  END AS dias_atraso_entrega
FROM raw.pedidos_vendas;

DROP VIEW IF EXISTS staging.stg_vendedores CASCADE;
CREATE OR REPLACE VIEW staging.stg_vendedores AS
SELECT
  vendedor_id,
  UPPER(TRIM(nome)) AS nome,
  UPPER(TRIM(regiao)) AS regiao,
  meta_mensal::NUMERIC(18,2) AS meta_mensal,
  data_admissao::DATE AS data_admissao,
  UPPER(TRIM(status)) AS status,
  (UPPER(TRIM(status)) = 'ATIVO') AS ativo
FROM raw.vendedores;

DROP VIEW IF EXISTS staging.stg_metas_vendas CASCADE;
CREATE OR REPLACE VIEW staging.stg_metas_vendas AS
SELECT
  vendedor_id,
  TO_DATE(competencia, 'YYYY-MM') AS competencia,
  meta_valor::NUMERIC(18,2) AS meta_valor
FROM raw.metas_vendas;

DROP VIEW IF EXISTS staging.stg_clientes CASCADE;
CREATE OR REPLACE VIEW staging.stg_clientes AS
SELECT
  cliente_id,
  UPPER(TRIM(razao_social)) AS razao_social,
  UPPER(TRIM(segmento)) AS segmento,
  UPPER(TRIM(uf)) AS uf,
  cidade,
  UPPER(TRIM(canal)) AS canal,
  data_criacao::DATE AS data_criacao,
  UPPER(TRIM(status_cliente)) AS status_cliente
FROM raw.dim_cliente;

DROP VIEW IF EXISTS staging.stg_produtos CASCADE;
CREATE OR REPLACE VIEW staging.stg_produtos AS
SELECT
  produto_id,
  descricao,
  categoria,
  preco_lista::NUMERIC(18,2) AS preco_lista,
  ativo
FROM raw.dim_produto;

DROP VIEW IF EXISTS staging.stg_calendario CASCADE;
CREATE OR REPLACE VIEW staging.stg_calendario AS
SELECT
  data::DATE AS data,
  ano,
  mes,
  mes_nome,
  trimestre,
  semana,
  dia_semana,
  is_util
FROM raw.dim_calendario;

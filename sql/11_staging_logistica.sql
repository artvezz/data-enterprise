-- 11_staging_logistica.sql
-- STAGING LOGISTICA: limpa e padroniza dados de transporte e estoque

CREATE SCHEMA IF NOT EXISTS staging;

DROP VIEW IF EXISTS staging.stg_entregas CASCADE;
CREATE OR REPLACE VIEW staging.stg_entregas AS
SELECT
  nota_id,
  centro_origem,
  centro_destino,
  data_emissao::DATE AS data_emissao,
  pedido_id,
  UPPER(TRIM(transportadora)) AS transportadora,
  peso_kg::NUMERIC(12,3) AS peso_kg,
  prazo_dias::INT AS prazo_dias,
  data_entrega::DATE AS data_entrega,
  custo_frete::NUMERIC(18,2) AS custo_frete,
  UPPER(TRIM(status_entrega)) AS status_entrega,
  UPPER(TRIM(regiao_origem)) AS regiao_origem,
  data_emissao::DATE + prazo_dias::INT AS data_prevista,
  (UPPER(TRIM(status_entrega)) = 'ENTREGUE') AS entregue,
  (UPPER(TRIM(status_entrega)) IN ('EM_TRANSITO','EM TRANSITO')) AS em_transito,
  CASE
    WHEN UPPER(TRIM(status_entrega)) = 'ENTREGUE' AND data_entrega IS NOT NULL
      THEN (data_entrega - (data_emissao::DATE + prazo_dias::INT))
  END AS dias_atraso_entrega,
  CASE
    WHEN UPPER(TRIM(status_entrega)) = 'ENTREGUE' AND data_entrega IS NOT NULL
      THEN (data_entrega - (data_emissao::DATE + prazo_dias::INT)) <= 0
  END AS entregue_no_prazo,
  DATE_TRUNC('month', data_emissao)::DATE AS competencia
FROM raw.notas_fiscais_transporte;

DROP VIEW IF EXISTS staging.stg_estoque CASCADE;
CREATE OR REPLACE VIEW staging.stg_estoque AS
SELECT
  centro_id,
  produto_id,
  data_snapshot::DATE AS data_snapshot,
  quantidade_estoque::INT AS quantidade_estoque,
  estoque_minimo::INT AS estoque_minimo,
  custo_unitario::NUMERIC(18,2) AS custo_unitario,
  UPPER(TRIM(status)) AS status,
  (quantidade_estoque::INT <= estoque_minimo::INT) AS abaixo_minimo,
  (quantidade_estoque::INT - estoque_minimo::INT) AS excesso_sobre_minimo,
  (quantidade_estoque::NUMERIC * custo_unitario::NUMERIC)::NUMERIC(18,2) AS valor_estoque
FROM raw.estoque;

GRANT USAGE ON SCHEMA staging TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA staging TO anon, authenticated;
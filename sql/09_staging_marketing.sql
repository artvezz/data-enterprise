-- 09_staging_marketing.sql
-- STAGING MARKETING: limpa e padroniza dados de marketing

CREATE SCHEMA IF NOT EXISTS staging;

DROP VIEW IF EXISTS staging.stg_campanhas CASCADE;
CREATE OR REPLACE VIEW staging.stg_campanhas AS
SELECT
  campanha_id,
  UPPER(TRIM(nome_campanha)) AS nome_campanha,
  UPPER(TRIM(canal)) AS canal,
  data_inicio::DATE AS data_inicio,
  data_fim::DATE AS data_fim,
  investimento::NUMERIC(18,2) AS investimento,
  leads_gerados::INT AS leads_gerados,
  conversoes::INT AS conversoes,
  receita_atribuida::NUMERIC(18,2) AS receita_atribuida,
  cpa::NUMERIC(18,2) AS cpa,
  UPPER(TRIM(status)) AS status,
  (data_fim - data_inicio + 1)::INT AS dias_campanha,
  ROUND(
    receita_atribuida::NUMERIC / NULLIF(investimento::NUMERIC, 0),
    4
  ) AS roi,
  ROUND(
    conversoes::NUMERIC / NULLIF(leads_gerados, 0),
    4
  ) AS taxa_conversao,
  DATE_TRUNC('month', data_inicio)::DATE AS competencia
FROM raw.campanhas;

DROP VIEW IF EXISTS staging.stg_trafego_diario CASCADE;
CREATE OR REPLACE VIEW staging.stg_trafego_diario AS
SELECT
  data::DATE AS data,
  UPPER(TRIM(canal)) AS canal,
  sessoes::INT AS sessoes,
  sessoes_pagas::INT AS sessoes_pagas,
  usuarios_unicos::INT AS usuarios_unicos,
  taxa_conversao::NUMERIC(6,4) AS taxa_conversao,
  custo_clique::NUMERIC(18,4) AS custo_clique,
  custo_lead::NUMERIC(18,2) AS custo_lead,
  (sessoes_pagas::NUMERIC / NULLIF(sessoes, 0)) AS pct_sessoes_pagas,
  DATE_TRUNC('month', data)::DATE AS competencia
FROM raw.atuacoes_marketing;

GRANT USAGE ON SCHEMA staging TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA staging TO anon, authenticated;
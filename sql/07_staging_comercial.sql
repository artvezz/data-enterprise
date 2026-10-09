-- 07_staging_comercial.sql
-- STAGING COMERCIAL: limpa e padroniza dados de CRM

CREATE SCHEMA IF NOT EXISTS staging;

DROP VIEW IF EXISTS staging.stg_oportunidades CASCADE;
CREATE OR REPLACE VIEW staging.stg_oportunidades AS
SELECT
  oportunidade_id,
  cliente_id,
  data_criacao::DATE AS data_criacao,
  UPPER(TRIM(etapa)) AS etapa,
  valor_oportunidade::NUMERIC(18,2) AS valor_oportunidade,
  probabilidade::NUMERIC(6,4) AS probabilidade,
  valor_ponderado::NUMERIC(18,2) AS valor_ponderado,
  UPPER(TRIM(regiao)) AS regiao,
  vendedor_id,
  UPPER(TRIM(status_oportunidade)) AS status_oportunidade,
  data_previsao_fechamento::DATE AS data_previsao_fechamento,
  (UPPER(TRIM(status_oportunidade)) = 'GANHA') AS ganha,
  (UPPER(TRIM(status_oportunidade)) IN ('GANHA','PERDIDA')) AS encerrada,
  DATE_TRUNC('month', data_criacao)::DATE AS competencia
FROM raw.oportunidades;

DROP VIEW IF EXISTS staging.stg_atividades CASCADE;
CREATE OR REPLACE VIEW staging.stg_atividades AS
SELECT
  atividade_id,
  oportunidade_id,
  data_atividade::DATE AS data_atividade,
  UPPER(TRIM(tipo_atividade)) AS tipo_atividade,
  UPPER(TRIM(resultado)) AS resultado,
  duracao_min::INT AS duracao_min,
  vendedor_id,
  DATE_TRUNC('month', data_atividade)::DATE AS competencia
FROM raw.leads;

GRANT USAGE ON SCHEMA staging TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA staging TO anon, authenticated;
-- 08_mart_comercial.sql
-- MART COMERCIAL: visão de consumo para o time Comercial

CREATE SCHEMA IF NOT EXISTS mart_comercial;

DROP TABLE IF EXISTS mart_comercial.pipeline_por_etapa;
CREATE TABLE mart_comercial.pipeline_por_etapa AS
SELECT
  etapa,
  COUNT(*) AS oportunidades,
  SUM(valor_oportunidade) AS valor_total,
  SUM(valor_ponderado) AS valor_ponderado,
  ROUND(AVG(probabilidade), 4) AS probabilidade_media,
  COUNT(*) FILTER (WHERE encerrada) AS encerradas,
  COUNT(*) FILTER (WHERE ganha) AS ganhas
FROM staging.stg_oportunidades
GROUP BY etapa
ORDER BY valor_total DESC;

DROP TABLE IF EXISTS mart_comercial.pipeline_por_vendedor;
CREATE TABLE mart_comercial.pipeline_por_vendedor AS
SELECT
  o.vendedor_id,
  v.nome AS vendedor,
  v.regiao,
  COUNT(*) AS oportunidades,
  SUM(o.valor_oportunidade) AS pipeline_total,
  SUM(o.valor_oportunidade) FILTER (WHERE o.ganha) AS valor_ganho,
  ROUND(
    COUNT(*) FILTER (WHERE o.ganha)::NUMERIC / NULLIF(COUNT(*) FILTER (WHERE o.encerrada), 0),
    4
  ) AS win_rate,
  ROUND(
    SUM(o.valor_oportunidade) FILTER (WHERE o.ganha)
      / NULLIF(COUNT(*) FILTER (WHERE o.ganha), 0),
    2
  ) AS ticket_medio
FROM staging.stg_oportunidades o
LEFT JOIN staging.stg_vendedores v ON v.vendedor_id = o.vendedor_id
GROUP BY o.vendedor_id, v.nome, v.regiao
ORDER BY valor_ganho DESC;

DROP TABLE IF EXISTS mart_comercial.conversao_mensal;
CREATE TABLE mart_comercial.conversao_mensal AS
SELECT
  competencia,
  COUNT(*) AS oportunidades_criadas,
  COUNT(*) FILTER (WHERE encerrada) AS encerradas,
  COUNT(*) FILTER (WHERE ganha) AS ganhas,
  SUM(valor_oportunidade) AS valor_criado,
  SUM(valor_oportunidade) FILTER (WHERE ganha) AS valor_ganho,
  ROUND(
    COUNT(*) FILTER (WHERE ganha)::NUMERIC / NULLIF(COUNT(*) FILTER (WHERE encerrada), 0),
    4
  ) AS taxa_win
FROM staging.stg_oportunidades
GROUP BY competencia
ORDER BY competencia;

DROP TABLE IF EXISTS mart_comercial.win_rate_por_regiao;
CREATE TABLE mart_comercial.win_rate_por_regiao AS
SELECT
  regiao,
  COUNT(*) AS oportunidades,
  COUNT(*) FILTER (WHERE encerrada) AS encerradas,
  COUNT(*) FILTER (WHERE ganha) AS ganhas,
  SUM(valor_oportunidade) FILTER (WHERE ganha) AS valor_ganho,
  ROUND(
    COUNT(*) FILTER (WHERE ganha)::NUMERIC / NULLIF(COUNT(*) FILTER (WHERE encerrada), 0),
    4
  ) AS win_rate
FROM staging.stg_oportunidades
GROUP BY regiao
ORDER BY valor_ganho DESC;

DROP TABLE IF EXISTS mart_comercial.atividades_mensais;
CREATE TABLE mart_comercial.atividades_mensais AS
SELECT
  competencia,
  COUNT(*) AS atividades,
  COUNT(DISTINCT oportunidade_id) AS oportunidades_atendidas,
  COUNT(DISTINCT vendedor_id) AS vendedores,
  SUM(duracao_min) AS minutos_total,
  COUNT(*) FILTER (WHERE resultado = 'POSITIVO') AS atividades_positivas
FROM staging.stg_atividades
GROUP BY competencia
ORDER BY competencia;

GRANT USAGE ON SCHEMA mart_comercial TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA mart_comercial TO anon, authenticated;
GRANT USAGE ON SCHEMA staging TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA staging TO anon, authenticated;
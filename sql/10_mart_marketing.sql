-- 10_mart_marketing.sql
-- MART MARKETING: visão de consumo para o time de Marketing

CREATE SCHEMA IF NOT EXISTS mart_marketing;

DROP TABLE IF EXISTS mart_marketing.campanhas_por_canal;
CREATE TABLE mart_marketing.campanhas_por_canal AS
SELECT
  canal,
  COUNT(*) AS campanhas,
  SUM(investimento) AS investimento_total,
  SUM(receita_atribuida) AS receita_atribuida,
  SUM(leads_gerados) AS leads,
  SUM(conversoes) AS conversoes,
  ROUND(SUM(receita_atribuida) / NULLIF(SUM(investimento), 0), 4) AS roi,
  ROUND(SUM(conversoes)::NUMERIC / NULLIF(SUM(leads_gerados), 0), 4) AS taxa_conversao,
  ROUND(SUM(investimento) / NULLIF(SUM(leads_gerados), 0), 2) AS cpa_medio,
  ROUND(SUM(receita_atribuida) / NULLIF(SUM(conversoes), 0), 2) AS receita_por_conversao
FROM staging.stg_campanhas
GROUP BY canal
ORDER BY receita_atribuida DESC;

DROP TABLE IF EXISTS mart_marketing.campanhas_mensais;
CREATE TABLE mart_marketing.campanhas_mensais AS
SELECT
  competencia,
  COUNT(*) AS campanhas,
  SUM(investimento) AS investimento_total,
  SUM(receita_atribuida) AS receita_atribuida,
  SUM(leads_gerados) AS leads,
  SUM(conversoes) AS conversoes,
  ROUND(SUM(receita_atribuida) / NULLIF(SUM(investimento), 0), 4) AS roi
FROM staging.stg_campanhas
GROUP BY competencia
ORDER BY competencia;

DROP TABLE IF EXISTS mart_marketing.trafego_mensal;
CREATE TABLE mart_marketing.trafego_mensal AS
SELECT
  competencia,
  SUM(sessoes) AS sessoes,
  SUM(sessoes_pagas) AS sessoes_pagas,
  SUM(usuarios_unicos) AS usuarios_unicos,
  ROUND(SUM(sessoes_pagas)::NUMERIC / NULLIF(SUM(sessoes), 0), 4) AS pct_sessoes_pagas,
  ROUND(AVG(taxa_conversao), 4) AS taxa_conversao_media,
  ROUND(SUM(sessoes_pagas) * AVG(custo_clique), 2) AS investimento_estimado,
  ROUND(AVG(custo_lead), 2) AS custo_lead_medio
FROM staging.stg_trafego_diario
GROUP BY competencia
ORDER BY competencia;

DROP TABLE IF EXISTS mart_marketing.trafego_por_canal;
CREATE TABLE mart_marketing.trafego_por_canal AS
SELECT
  canal,
  COUNT(*) AS dias,
  SUM(sessoes) AS sessoes,
  SUM(sessoes_pagas) AS sessoes_pagas,
  SUM(usuarios_unicos) AS usuarios_unicos,
  ROUND(SUM(sessoes_pagas)::NUMERIC / NULLIF(SUM(sessoes), 0), 4) AS pct_sessoes_pagas,
  ROUND(AVG(custo_clique), 4) AS custo_clique_medio,
  ROUND(AVG(custo_lead), 2) AS custo_lead_medio,
  ROUND(AVG(taxa_conversao), 4) AS taxa_conversao_media
FROM staging.stg_trafego_diario
GROUP BY canal
ORDER BY sessoes DESC;

GRANT USAGE ON SCHEMA mart_marketing TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA mart_marketing TO anon, authenticated;
GRANT USAGE ON SCHEMA staging TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA staging TO anon, authenticated;
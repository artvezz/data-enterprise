-- 12_mart_logistica.sql
-- MART LOGÍSTICA: visão de consumo para o time de Logística

CREATE SCHEMA IF NOT EXISTS mart_logistica;

DROP TABLE IF EXISTS mart_logistica.entregas_mensais;
CREATE TABLE mart_logistica.entregas_mensais AS
SELECT
  competencia,
  COUNT(*) AS notas,
  COUNT(*) FILTER (WHERE entregue) AS entregues,
  COUNT(*) FILTER (WHERE em_transito) AS em_transito,
  COUNT(*) FILTER (WHERE entregue_no_prazo) AS no_prazo,
  ROUND(
    COUNT(*) FILTER (WHERE entregue_no_prazo)::NUMERIC
      / NULLIF(COUNT(*) FILTER (WHERE entregue), 0),
    4
  ) AS otif,
  SUM(custo_frete) AS custo_frete_total,
  ROUND(AVG(peso_kg), 2) AS peso_medio_kg,
  ROUND(AVG(dias_atraso_entrega) FILTER (WHERE entregue), 2) AS atraso_medio_dias
FROM staging.stg_entregas
GROUP BY competencia
ORDER BY competencia;

DROP TABLE IF EXISTS mart_logistica.entregas_por_transportadora;
CREATE TABLE mart_logistica.entregas_por_transportadora AS
SELECT
  transportadora,
  COUNT(*) AS notas,
  COUNT(*) FILTER (WHERE entregue) AS entregues,
  COUNT(*) FILTER (WHERE entregue_no_prazo) AS no_prazo,
  ROUND(
    COUNT(*) FILTER (WHERE entregue_no_prazo)::NUMERIC
      / NULLIF(COUNT(*) FILTER (WHERE entregue), 0),
    4
  ) AS otif,
  ROUND(AVG(dias_atraso_entrega) FILTER (WHERE entregue), 2) AS atraso_medio_dias,
  SUM(custo_frete) AS custo_frete_total,
  ROUND(SUM(custo_frete) / NULLIF(SUM(peso_kg), 0), 4) AS custo_por_kg,
  ROUND(AVG(prazo_dias), 1) AS prazo_medio_dias
FROM staging.stg_entregas
GROUP BY transportadora
ORDER BY custo_frete_total DESC;

DROP TABLE IF EXISTS mart_logistica.entregas_por_regiao;
CREATE TABLE mart_logistica.entregas_por_regiao AS
SELECT
  regiao_origem,
  centro_origem,
  centro_destino,
  COUNT(*) AS notas,
  COUNT(*) FILTER (WHERE entregue) AS entregues,
  COUNT(*) FILTER (WHERE entregue_no_prazo) AS no_prazo,
  ROUND(
    COUNT(*) FILTER (WHERE entregue_no_prazo)::NUMERIC
      / NULLIF(COUNT(*) FILTER (WHERE entregue), 0),
    4
  ) AS otif,
  SUM(custo_frete) AS custo_frete_total,
  ROUND(AVG(prazo_dias), 1) AS prazo_medio_dias
FROM staging.stg_entregas
GROUP BY regiao_origem, centro_origem, centro_destino
ORDER BY custo_frete_total DESC;

DROP TABLE IF EXISTS mart_logistica.estoque_abaixo_minimo;
CREATE TABLE mart_logistica.estoque_abaixo_minimo AS
SELECT
  e.centro_id,
  e.produto_id,
  p.descricao AS produto,
  p.categoria,
  e.quantidade_estoque,
  e.estoque_minimo,
  e.excesso_sobre_minimo AS falta_para_minimo,
  e.custo_unitario,
  e.valor_estoque,
  e.data_snapshot
FROM staging.stg_estoque e
LEFT JOIN staging.stg_produtos p ON p.produto_id = e.produto_id
WHERE e.abaixo_minimo
ORDER BY e.excesso_sobre_minimo, e.produto_id;

DROP TABLE IF EXISTS mart_logistica.estoque_valor_por_categoria;
CREATE TABLE mart_logistica.estoque_valor_por_categoria AS
SELECT
  p.categoria,
  COUNT(DISTINCT e.produto_id) AS produtos,
  SUM(e.quantidade_estoque) AS unidades,
  SUM(e.valor_estoque) AS valor_estoque,
  COUNT(*) FILTER (WHERE e.abaixo_minimo) AS itens_abaixo_minimo
FROM staging.stg_estoque e
LEFT JOIN staging.stg_produtos p ON p.produto_id = e.produto_id
GROUP BY p.categoria
ORDER BY valor_estoque DESC;

GRANT USAGE ON SCHEMA mart_logistica TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA mart_logistica TO anon, authenticated;
GRANT USAGE ON SCHEMA staging TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA staging TO anon, authenticated;
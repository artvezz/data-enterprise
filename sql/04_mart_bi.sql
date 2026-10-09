-- 04_mart_bi.sql
-- MART BI: visão transversal (cross-area) para análise corporativa

CREATE SCHEMA IF NOT EXISTS mart_bi;

DROP TABLE IF EXISTS mart_bi.receita_por_mes;
CREATE TABLE mart_bi.receita_por_mes AS
SELECT
  DATE_TRUNC('month', data_pedido)::DATE AS competencia,
  SUM(valor_liquido) AS receita_liquida,
  SUM(valor_bruto - valor_liquido) AS desconto,
  COUNT(DISTINCT pedido_id) AS pedidos,
  SUM(quantidade) AS itens,
  ROUND(SUM(valor_liquido) / NULLIF(COUNT(DISTINCT pedido_id),0), 2) AS ticket_medio
FROM staging.stg_pedidos_vendas
WHERE faturado
GROUP BY DATE_TRUNC('month', data_pedido)
ORDER BY competencia;

DROP TABLE IF EXISTS mart_bi.receita_por_segmento;
CREATE TABLE mart_bi.receita_por_segmento AS
SELECT
  c.segmento,
  SUM(p.valor_liquido) AS receita,
  COUNT(DISTINCT p.pedido_id) AS pedidos,
  COUNT(DISTINCT p.cliente_id) AS clientes,
  ROUND(SUM(p.valor_liquido) / NULLIF(COUNT(DISTINCT p.cliente_id),0), 2) AS receita_por_cliente
FROM staging.stg_pedidos_vendas p
LEFT JOIN staging.stg_clientes c ON c.cliente_id = p.cliente_id
WHERE p.faturado
GROUP BY 1
ORDER BY receita DESC;

DROP TABLE IF EXISTS mart_bi.receita_por_canal;
CREATE TABLE mart_bi.receita_por_canal AS
SELECT
  c.canal,
  SUM(p.valor_liquido) AS receita,
  COUNT(DISTINCT p.pedido_id) AS pedidos,
  ROUND(SUM(p.valor_liquido) / NULLIF(COUNT(DISTINCT p.pedido_id),0), 2) AS ticket_medio
FROM staging.stg_pedidos_vendas p
LEFT JOIN staging.stg_clientes c ON c.cliente_id = p.cliente_id
WHERE p.faturado
GROUP BY 1
ORDER BY receita DESC;

DROP TABLE IF EXISTS mart_bi.receita_por_uf;
CREATE TABLE mart_bi.receita_por_uf AS
SELECT
  c.uf,
  SUM(p.valor_liquido) AS receita,
  COUNT(DISTINCT p.cliente_id) AS clientes,
  COUNT(DISTINCT p.pedido_id) AS pedidos
FROM staging.stg_pedidos_vendas p
LEFT JOIN staging.stg_clientes c ON c.cliente_id = p.cliente_id
WHERE p.faturado
GROUP BY 1
ORDER BY receita DESC;

GRANT USAGE ON SCHEMA mart_bi TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA mart_bi TO anon, authenticated;
GRANT USAGE ON SCHEMA staging TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA staging TO anon, authenticated;
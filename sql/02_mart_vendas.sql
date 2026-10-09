-- 02_mart_vendas.sql
-- MART: visão de consumo para o time de Vendas

CREATE SCHEMA IF NOT EXISTS mart_vendas;

DROP TABLE IF EXISTS mart_vendas.fatos_pedidos;
CREATE TABLE mart_vendas.fatos_pedidos AS
SELECT
  p.pedido_id,
  p.data_pedido,
  DATE_TRUNC('month', p.data_pedido)::DATE AS competencia,
  p.cliente_id,
  c.razao_social,
  c.segmento,
  c.uf,
  c.canal,
  c.status_cliente,
  p.produto_id,
  pr.descricao AS produto,
  pr.categoria,
  p.vendedor_id,
  v.nome AS vendedor,
  v.regiao,
  p.quantidade,
  p.preco_unitario,
  p.desconto_pct,
  p.valor_bruto,
  p.valor_liquido,
  p.forma_pagamento,
  p.status_pedido,
  p.faturado,
  p.pedido_valido,
  p.dias_atraso_entrega
FROM staging.stg_pedidos_vendas p
LEFT JOIN staging.stg_clientes c ON c.cliente_id = p.cliente_id
LEFT JOIN staging.stg_produtos pr ON pr.produto_id = p.produto_id
LEFT JOIN staging.stg_vendedores v ON v.vendedor_id = p.vendedor_id
WHERE p.pedido_valido;

DROP TABLE IF EXISTS mart_vendas.vendas_mensais;
CREATE TABLE mart_vendas.vendas_mensais AS
SELECT
  competencia,
  COUNT(DISTINCT pedido_id) AS pedidos,
  SUM(quantidade) AS itens,
  SUM(valor_bruto) AS receita_bruta,
  SUM(valor_liquido) AS receita_liquida,
  SUM(valor_bruto - valor_liquido) AS desconto_total,
  SUM(valor_liquido) / NULLIF(COUNT(DISTINCT pedido_id), 0) AS ticket_medio,
  (PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY valor_liquido))::NUMERIC(18,2) AS ticket_mediano
FROM mart_vendas.fatos_pedidos
WHERE faturado
GROUP BY competencia
ORDER BY competencia;

DROP TABLE IF EXISTS mart_vendas.vendas_por_categoria;
CREATE TABLE mart_vendas.vendas_por_categoria AS
SELECT
  categoria,
  COUNT(DISTINCT pedido_id) AS pedidos,
  SUM(quantidade) AS itens,
  SUM(valor_liquido) AS receita,
  SUM(valor_liquido) / NULLIF(COUNT(DISTINCT pedido_id), 0) AS ticket_medio,
  ROUND(AVG(desconto_pct), 4) AS desconto_medio
FROM mart_vendas.fatos_pedidos
WHERE faturado
GROUP BY 1
ORDER BY receita DESC;

DROP TABLE IF EXISTS mart_vendas.vendas_por_cliente;
CREATE TABLE mart_vendas.vendas_por_cliente AS
SELECT
  cliente_id,
  razao_social,
  segmento,
  uf,
  COUNT(DISTINCT pedido_id) AS pedidos,
  SUM(valor_liquido) AS receita,
  SUM(valor_liquido) / NULLIF(COUNT(DISTINCT pedido_id), 0) AS ticket_medio,
  MAX(data_pedido) AS ultimo_pedido
FROM mart_vendas.fatos_pedidos
WHERE faturado
GROUP BY 1,2,3,4
ORDER BY receita DESC;

DROP TABLE IF EXISTS mart_vendas.atingimento_metas;
CREATE TABLE mart_vendas.atingimento_metas AS
SELECT
  m.competencia::DATE AS competencia,
  m.vendedor_id,
  v.nome AS vendedor,
  v.regiao,
  m.meta_valor,
  COALESCE(r.realizado, 0) AS realizado,
  ROUND(COALESCE(r.realizado, 0) / NULLIF(m.meta_valor, 0), 4) AS atingimento_pct
FROM staging.stg_metas_vendas m
LEFT JOIN (
  SELECT
    DATE_TRUNC('month', data_pedido)::DATE AS competencia,
    vendedor_id,
    SUM(valor_liquido) AS realizado
  FROM staging.stg_pedidos_vendas
  WHERE faturado
  GROUP BY DATE_TRUNC('month', data_pedido), vendedor_id
) r ON r.competencia = m.competencia AND r.vendedor_id = m.vendedor_id
LEFT JOIN staging.stg_vendedores v ON v.vendedor_id = m.vendedor_id
ORDER BY m.competencia, atingimento_pct DESC;

GRANT USAGE ON SCHEMA mart_vendas TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA mart_vendas TO anon, authenticated;
GRANT USAGE ON SCHEMA staging TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA staging TO anon, authenticated;
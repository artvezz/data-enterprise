-- 06_mart_rh.sql
-- MART RH: visão de consumo para o time de RH

CREATE SCHEMA IF NOT EXISTS mart_rh;

DROP TABLE IF EXISTS mart_rh.headcount;
CREATE TABLE mart_rh.headcount AS
SELECT
  COUNT(*) FILTER (WHERE ativo) AS ativos,
  COUNT(*) FILTER (WHERE NOT ativo) AS inativos,
  COUNT(*) AS total,
  ROUND(AVG(salario_bruto) FILTER (WHERE ativo), 2) AS salario_medio_ativo
FROM staging.stg_funcionarios;

DROP TABLE IF EXISTS mart_rh.headcount_por_area;
CREATE TABLE mart_rh.headcount_por_area AS
SELECT
  area,
  COUNT(*) FILTER (WHERE ativo) AS ativos,
  COUNT(*) FILTER (WHERE NOT ativo) AS inativos,
  SUM(salario_bruto) FILTER (WHERE ativo) AS folha_por_area
FROM staging.stg_funcionarios
GROUP BY area
ORDER BY ativos DESC;

DROP TABLE IF EXISTS mart_rh.headcount_por_uf;
CREATE TABLE mart_rh.headcount_por_uf AS
SELECT
  uf,
  COUNT(*) FILTER (WHERE ativo) AS ativos
FROM staging.stg_funcionarios
WHERE ativo
GROUP BY uf
ORDER BY ativos DESC;

DROP TABLE IF EXISTS mart_rh.custo_rh_mensal;
CREATE TABLE mart_rh.custo_rh_mensal AS
SELECT
  competencia,
  SUM(folha_bruta) AS folha_bruta,
  SUM(encargos) AS encargos,
  SUM(beneficios) AS beneficios,
  SUM(custo_total) AS custo_total,
  SUM(qtd_colaboradores) AS colaboradores,
  ROUND(SUM(encargos) / NULLIF(SUM(folha_bruta), 0), 4) AS pct_encargos,
  ROUND(SUM(custo_total) / NULLIF(SUM(qtd_colaboradores), 0), 2) AS custo_medio_colaborador
FROM staging.stg_custos_rh
GROUP BY competencia
ORDER BY competencia;

DROP TABLE IF EXISTS mart_rh.horas_trabalhadas_mensal;
CREATE TABLE mart_rh.horas_trabalhadas_mensal AS
SELECT
  competencia,
  COUNT(DISTINCT colaborador_id) AS colaboradores_com_registro,
  COUNT(*) AS registros_ponto,
  SUM(horas_trabalhadas) AS horas_trabalhadas,
  COUNT(*) FILTER (WHERE falta) AS faltas,
  ROUND(AVG(horas_trabalhadas), 2) AS horas_media_dia,
  ROUND(SUM(horas_trabalhadas) / NULLIF(COUNT(*) FILTER (WHERE NOT falta), 0), 2) AS horas_media_dia_trabalha
FROM staging.stg_folha_ponto
GROUP BY competencia
ORDER BY competencia;

DROP TABLE IF EXISTS mart_rh.ferias_mensal;
CREATE TABLE mart_rh.ferias_mensal AS
SELECT
  DATE_TRUNC('month', data_inicio)::DATE AS competencia,
  COUNT(*) AS registros_ferias,
  SUM(dias_ferias) AS dias_ferias,
  COUNT(*) FILTER (WHERE status_ferias = 'CONCLUIDA') AS concluidas,
  COUNT(DISTINCT colaborador_id) AS colaboradores
FROM staging.stg_ferias
GROUP BY DATE_TRUNC('month', data_inicio)
ORDER BY competencia;

GRANT USAGE ON SCHEMA mart_rh TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA mart_rh TO anon, authenticated;
GRANT USAGE ON SCHEMA staging TO anon, authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA staging TO anon, authenticated;
-- 05_staging_rh.sql
-- STAGING RH: limpa e padroniza dados de RH

CREATE SCHEMA IF NOT EXISTS staging;

DROP VIEW IF EXISTS staging.stg_funcionarios CASCADE;
CREATE OR REPLACE VIEW staging.stg_funcionarios AS
SELECT
  colaborador_id,
  UPPER(TRIM(nome)) AS nome,
  UPPER(TRIM(cargo)) AS cargo,
  UPPER(TRIM(area)) AS area,
  UPPER(TRIM(senioridade)) AS senioridade,
  UPPER(TRIM(uf)) AS uf,
  cidade,
  data_admissao::DATE AS data_admissao,
  NULLIF(data_demissao, '')::DATE AS data_demissao,
  salario_bruto::NUMERIC(18,2) AS salario_bruto,
  UPPER(TRIM(tipo_contrato)) AS tipo_contrato,
  UPPER(TRIM(status)) AS status,
  (UPPER(TRIM(status)) = 'ATIVO') AS ativo,
  ingestion_timestamp
FROM raw.funcionarios;

DROP VIEW IF EXISTS staging.stg_cargos CASCADE;
CREATE OR REPLACE VIEW staging.stg_cargos AS
SELECT
  cargo_id,
  UPPER(TRIM(descricao_cargo)) AS descricao_cargo,
  UPPER(TRIM(area)) AS area,
  UPPER(TRIM(senioridade)) AS senioridade,
  faixa_salarial_min::NUMERIC(18,2) AS faixa_salarial_min,
  faixa_salarial_max::NUMERIC(18,2) AS faixa_salarial_max
FROM raw.cargos;

DROP VIEW IF EXISTS staging.stg_folha_ponto CASCADE;
CREATE OR REPLACE VIEW staging.stg_folha_ponto AS
SELECT
  ponto_id,
  colaborador_id,
  data_hora_entrada::TIMESTAMP AS data_hora_entrada,
  DATE_TRUNC('month', data_hora_entrada)::DATE AS competencia,
  hora_saida,
  horas_trabalhadas::NUMERIC(10,2) AS horas_trabalhadas,
  UPPER(TRIM(situacao)) AS situacao,
  (UPPER(TRIM(situacao)) = 'FALTA') AS falta
FROM raw.folha_ponto;

DROP VIEW IF EXISTS staging.stg_custos_rh CASCADE;
CREATE OR REPLACE VIEW staging.stg_custos_rh AS
SELECT
  TO_DATE(competencia, 'YYYY-MM') AS competencia,
  UPPER(TRIM(area)) AS area,
  folha_bruta::NUMERIC(18,2) AS folha_bruta,
  encargos::NUMERIC(18,2) AS encargos,
  beneficios::NUMERIC(18,2) AS beneficios,
  custo_total::NUMERIC(18,2) AS custo_total,
  qtd_colaboradores::INT AS qtd_colaboradores,
  (encargos::NUMERIC / NULLIF(folha_bruta::NUMERIC, 0)) AS pct_encargos
FROM raw.remuneracao;

DROP VIEW IF EXISTS staging.stg_ferias CASCADE;
CREATE OR REPLACE VIEW staging.stg_ferias AS
SELECT
  ferias_id,
  colaborador_id,
  data_inicio::DATE AS data_inicio,
  data_fim::DATE AS data_fim,
  dias_ferias::INT AS dias_ferias,
  UPPER(TRIM(status_ferias)) AS status_ferias,
  UPPER(TRIM(tipo)) AS tipo
FROM raw.ferias;
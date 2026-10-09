-- ============================================================
-- 01_schemas.sql
-- Cria a estrutura de schemas que representa a arquitetura de dados.
-- Camadas: raw -> staging -> intermediate -> core -> marts (acesso por time)
-- ============================================================

-- Camada de ingested (dbt faz as tabelas, mas criamos schema)
CREATE SCHEMA IF NOT EXISTS raw;
COMMENT ON SCHEMA raw IS 'Camada 0: dados brutos carregados pelo pipeline de ingestao. Somente leitura para o dbt.';

CREATE SCHEMA IF NOT EXISTS staging;
COMMENT ON SCHEMA staging IS 'Camada 1: dados padronizados, deduplicados e com tipos corrigidos (dbt staging).';

CREATE SCHEMA IF NOT EXISTS intermediate;
COMMENT ON SCHEMA intermediate IS 'Camada 2: joins, agregacoes e regras de negocio entre dominios (dbt intermediate).';

CREATE SCHEMA IF NOT EXISTS core;
COMMENT ON SCHEMA core IS 'Camada 3: modelo dimensional canonico da empresa (fatos e dimensoes).';

CREATE SCHEMA IF NOT EXISTS marts;
COMMENT ON SCHEMA marts IS 'Camada 4: marts transversais de consumo (cross-area).';

CREATE SCHEMA IF NOT EXISTS qualidade;
COMMENT ON SCHEMA qualidade IS 'Resultado das execucoes de qualidade de dados (dbt tests e checks customizados).';

CREATE SCHEMA IF NOT EXISTS airflow;

-- Schemas de acesso por time (consumo)
CREATE SCHEMA IF NOT EXISTS mart_financeiro;
CREATE SCHEMA IF NOT EXISTS mart_rh;
CREATE SCHEMA IF NOT EXISTS mart_vendas;
CREATE SCHEMA IF NOT EXISTS mart_comercial;
CREATE SCHEMA IF NOT EXISTS mart_marketing;
CREATE SCHEMA IF NOT EXISTS mart_logistica;
CREATE SCHEMA IF NOT EXISTS mart_bi;
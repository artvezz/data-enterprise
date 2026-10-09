-- ============================================================
-- 02_roles_times.sql
-- Um login por time de negocio. Cada role enxerga apenas o
-- schema do proprio time. Papel "de negocio", nunca acesso a raw.
-- ============================================================

DO $$
DECLARE
  times TEXT[] := ARRAY[
    'financeiro', 'rh', 'vendas', 'comercial', 'marketing', 'logistica', 'bi'
  ];
  t TEXT;
  senha TEXT := 'time_local_2026';
BEGIN
  FOREACH t IN ARRAY times LOOP
    EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', 'app_' || t, senha);
    EXECUTE format('COMMENT ON ROLE %I IS %L', 'app_' || t,
                   'Usuario de acesso do time ' || t || '. Escopo restrito ao schema mart_' || t);
  END LOOP;
END $$;

-- Perfis tecnicos (usados pela engenharia de dados)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'de_engineer') THEN
    CREATE ROLE de_engineer LOGIN PASSWORD 'engineer_local_2026';
    COMMENT ON ROLE de_engineer IS 'Engenharia de dados: operacao do dbt, schemas tecnicos.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'de_reader') THEN
    CREATE ROLE de_reader LOGIN PASSWORD 'reader_local_2026';
    COMMENT ON ROLE de_reader IS 'Leitura transversal para auditoria e BI corporativo.';
  END IF;
END $$;

GRANT CONNECT ON DATABASE enterprise TO app_financeiro, app_rh, app_vendas, app_comercial,
      app_marketing, app_logistica, app_bi, de_engineer, de_reader;
-- ============================================================
-- 03_grants_e_segredos.sql
-- Controle de acesso em duas direcoes:
--   1) times de negocio -> somente o proprio schema mart_*
--   2) engenharia de dados -> operacao total nas camadas tecnicas
-- Nenhum role de negocio enxerga raw/staging/intermediate/core.
-- ============================================================

-- --- Perfis tecnicos: acesso as camadas de engenharia ---
GRANT USAGE ON SCHEMA raw, staging, intermediate, core, marts, qualidade TO de_engineer;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA raw, staging, intermediate, core, marts TO de_engineer;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA raw, staging, intermediate, core, marts TO de_engineer;

-- --- Leitor transversal: ve marts e core, mas nao dados brutos ---
GRANT USAGE ON SCHEMA core, marts, mart_financeiro, mart_rh, mart_vendas,
      mart_comercial, mart_marketing, mart_logistica, mart_bi TO de_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA core, marts TO de_reader;
ALTER DEFAULT PRIVILEGES IN SCHEMA core, marts GRANT SELECT ON TABLES TO de_reader;

-- --- Escopo por time: cada role ve apenas o seu mart ---
DO $$
DECLARE
  times TEXT[] := ARRAY[
    'financeiro', 'rh', 'vendas', 'comercial', 'marketing', 'logistica', 'bi'
  ];
  t TEXT;
BEGIN
  FOREACH t IN ARRAY times LOOP
    EXECUTE format('GRANT USAGE ON SCHEMA mart_%s TO app_%s', t, t);
    EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA mart_%s TO app_%s', t, t);
    EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA mart_%s GRANT SELECT ON TABLES TO app_%s', t, t);
  END LOOP;
END $$;

-- --- O time de BI e o unico autorizado a cruzar areas ---
-- As dimensoes so existem depois que o dbt roda; guarda com to_regclass
-- para o init nunca abortar (abortar aqui deixa o banco sem os grants finais).
DO $$
DECLARE
  dim TEXT;
BEGIN
  FOREACH dim IN ARRAY ARRAY[
    'core.dim_cliente', 'core.dim_produto', 'core.dim_calendario', 'core.dim_vendedor'
  ] LOOP
    IF to_regclass(dim) IS NOT NULL THEN
      EXECUTE format('GRANT SELECT ON %I.%I TO app_bi',
                     split_part(dim, '.', 1), split_part(dim, '.', 2));
    END IF;
  END LOOP;
END $$;

-- --- Revogacao explicita: negocio nunca alcanca a camada raw ---
DO $$
DECLARE
  times TEXT[] := ARRAY[
    'financeiro', 'rh', 'vendas', 'comercial', 'marketing', 'logistica', 'bi'
  ];
  t TEXT;
BEGIN
  FOREACH t IN ARRAY times LOOP
    EXECUTE format('REVOKE ALL ON SCHEMA raw, staging, intermediate FROM app_%s', t);
  END LOOP;
END $$;

-- --- Segredos: nao ha dados sensiveis de pessoas em marts de negocio ---
-- (o mart_rh expoe apenas agregados; dados nominais ficam em staging)
COMMENT ON SCHEMA mart_rh IS 'Acesso RH: agregados de folha, absenteismo e turnover. Sem dados nominais.';
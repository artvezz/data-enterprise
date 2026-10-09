-- =====================================================================
-- 14_metabase_ro.sql
-- Login dedicado do Metabase, somente leitura nos schemas de mart.
--
-- Como o Metabase conecta com essa role, ele NAO enxerga raw.* nem
-- staging.* - o isolamento e feito pelo proprio banco, nao pela UI.
--
-- A senha vem da variavel psql `mb_pass`, injetada pelo .env.
-- Rode pelo wrapper (nao cole direto no SQL Editor do Supabase):
--
--     .\scripts\exec_sql.ps1 sql\14_metabase_ro.sql
--
-- Repita apos qualquer `dbt run`: as tabelas sao recriadas e os grants
-- sobre tabelas somem (o ALTER DEFAULT PRIVILEGES ja cobre as futuras).
-- =====================================================================

\if :{?mb_pass}
\else
\echo 'ERRO: variavel mb_pass nao definida. Use: .\\scripts\\exec_sql.ps1 sql\\14_metabase_ro.sql'
\quit 1
\endif

-- psql nao substitui variaveis dentro de $$ ... $$, entao cria/altera fora
-- do bloco DO e com \gexec (a senha vem sempre do .env, nunca do repo).
SELECT 'CREATE ROLE metabase_ro LOGIN PASSWORD ' || quote_literal(:'mb_pass')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'metabase_ro')
\gexec

SELECT 'ALTER ROLE metabase_ro PASSWORD ' || quote_literal(:'mb_pass')
\gexec

COMMENT ON ROLE metabase_ro IS
    'Metabase: somente SELECT nos schemas mart_*. Sem acesso a raw/staging.';

REVOKE ALL ON SCHEMA public FROM metabase_ro;

-- grants nas tabelas ja existentes + nas que o dbt criar depois
DO $$
DECLARE
    s TEXT;
BEGIN
    FOREACH s IN ARRAY ARRAY[
        'mart_vendas', 'mart_financeiro', 'mart_rh',
        'mart_comercial', 'mart_marketing', 'mart_logistica', 'mart_bi'
    ] LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA %I TO metabase_ro', s);
        EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO metabase_ro', s);
        EXECUTE format(
            'ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA %I GRANT SELECT ON TABLES TO metabase_ro',
            s);
    END LOOP;
END
$$;

-- =====================================================================
-- REGRANT (rode apos um dbt run se quiser ter certeza dos grants)
--     psql -f sql/14_metabase_ro.sql
-- =====================================================================

-- validacao: a role deve ver APENAS mart_*
SELECT
    n.nspname AS schema,
    count(*)  AS tabelas_visiveis
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN information_schema.role_table_grants g
  ON g.table_schema = n.nspname AND g.table_name = c.relname
WHERE c.relkind = 'r'
  AND g.grantee = 'metabase_ro'
  AND g.privilege_type = 'SELECT'
GROUP BY n.nspname
ORDER BY n.nspname;

-- =====================================================================
-- 13_roles_por_time.sql
-- ACESSO RESTRITO POR TIME
--
-- Cada time recebe uma role que enxerga APENAS o schema do seu mart.
-- staging.* e raw.* continuam restritos a engenharia de dados.
--
-- Executar no Supabase > SQL Editor.
-- =====================================================================

-- ----------------------------------------------------- cria as roles
-- NOLOGIN: quem loga no Supabase usa anon/authenticated e assume a role
-- com "set role" (app_* e so uma permissao, nao um login).
DO $$
DECLARE
    r TEXT;
BEGIN
    FOREACH r IN ARRAY ARRAY[
        'app_vendas', 'app_financeiro', 'app_rh',
        'app_comercial', 'app_marketing', 'app_logistica', 'app_bi'
    ] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('CREATE ROLE %I NOLOGIN', r);
        END IF;
        -- nenhuma role de negocio pode ler a camada crua
        EXECUTE format('REVOKE ALL ON SCHEMA raw FROM %I', r);
        EXECUTE format('REVOKE ALL ON SCHEMA staging FROM %I', r);
    END LOOP;
END
$$;

-- ----------------------------------------------------- grants por time
-- cada bloco: usage do schema + select em todas as tabelas atuais + default
-- privileges para tabelas criadas depois (o dbt recria as tabelas a cada run).

DO $$
DECLARE
    par RECORD;
BEGIN
    FOR par IN
        SELECT * FROM (VALUES
            ('app_vendas',     'mart_vendas'),
            ('app_financeiro', 'mart_financeiro'),
            ('app_rh',         'mart_rh'),
            ('app_comercial',  'mart_comercial'),
            ('app_marketing',  'mart_marketing'),
            ('app_logistica',  'mart_logistica'),
            ('app_bi',         'mart_bi')
        ) AS t(role, schema_nome)
    LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA %I TO %I', par.schema_nome, par.role);
        EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO %I',
                       par.schema_nome, par.role);
        EXECUTE format(
            'ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT ON TABLES TO %I',
            par.schema_nome, par.role);
    END LOOP;
END
$$;

-- ----------------------------------------------------- papeis do Supabase
-- anon/authenticated leem tudo que esta em mart_* (dashboards e APIs publicas).
-- Se algum mart for sensivel, remova o grant correspondente.
DO $$
DECLARE
    s TEXT;
BEGIN
    FOREACH s IN ARRAY ARRAY[
        'mart_vendas', 'mart_financeiro', 'mart_rh',
        'mart_comercial', 'mart_marketing', 'mart_logistica', 'mart_bi'
    ] LOOP
        EXECUTE format('GRANT USAGE ON SCHEMA %I TO anon, authenticated', s);
        EXECUTE format('GRANT SELECT ON ALL TABLES IN SCHEMA %I TO anon, authenticated', s);
        EXECUTE format('ALTER DEFAULT PRIVILEGES IN SCHEMA %I GRANT SELECT ON TABLES TO anon, authenticated', s);
    END LOOP;
END
$$;

-- =====================================================================
-- COMO USAR
--
-- 1) Crie um usuario no Supabase (Auth) para cada pessoa do time.
-- 2) Na primeira conexao daquele usuario:
--        SET ROLE app_vendas;
--    Ele passa a ver apenas mart_vendas.*.
-- 3) Para voltar:
--        RESET ROLE;
--
-- Teste de isolamento (deve FALHAR para quem e do time de vendas):
--        SET ROLE app_vendas;
--        SELECT * FROM mart_financeiro.aging_contas_receber;  -- permission denied
--        SELECT * FROM mart_vendas.vendas_mensais;            -- ok
-- =====================================================================

-- ----------------------------------------------------- validacao
SELECT
    r.rolname AS role,
    n.nspname AS schema,
    has_schema_privilege(r.rolname, n.nspname, 'USAGE') AS pode_ver_schema
FROM pg_roles r
CROSS JOIN pg_namespace n
WHERE r.rolname LIKE 'app\_%'
  AND n.nspname LIKE 'mart\_%'
ORDER BY r.rolname, n.nspname;

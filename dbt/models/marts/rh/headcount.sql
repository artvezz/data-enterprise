{{ config(materialized='table', tags=['rh','mart']) }}

-- ============================================================
-- headcount: quadro atual
-- ============================================================

select
    count(*) filter (where ativo) as ativos,
    count(*) filter (where not ativo) as inativos,
    count(*) as total,
    avg(salario_bruto) filter (where ativo) as salario_medio_ativo,
    count(*) filter (where ativo and is_estagiario) as estagiarios,
    count(*) filter (where foi_desligado) as desligados,
    avg(tempo_de_empresa_dias) filter (where ativo) as tempo_medio_empresa_dias
from {{ ref('stg_colaboradores') }}

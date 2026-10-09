{{ config(materialized='table', tags=['rh','mart']) }}

-- ============================================================
-- headcount_por_area: quadro por area de negocio
-- ============================================================

select
    area,
    count(*) filter (where ativo) as ativos,
    count(*) filter (where not ativo) as inativos,
    count(*) as total,
    sum(salario_bruto) filter (where ativo) as folha_por_area,
    avg(salario_bruto) filter (where ativo) as salario_medio_area,
    count(*) filter (where ativo and is_estagiario) as estagiarios
from {{ ref('stg_colaboradores') }}
group by area
order by ativos desc

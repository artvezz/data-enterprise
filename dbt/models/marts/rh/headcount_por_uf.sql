{{ config(materialized='table', tags=['rh','mart']) }}

-- ============================================================
-- headcount_por_uf: distribuicao geografica do quadro
-- ============================================================

select
    uf,
    area,
    count(*) filter (where ativo) as ativos
from {{ ref('stg_colaboradores') }}
where ativo
group by uf, area
order by uf, ativos desc

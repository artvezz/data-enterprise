{{ config(materialized='table', tags=['comercial','mart']) }}

-- ============================================================
-- win_rate_por_regiao: desempenho por regiao
-- ============================================================

select
    regiao,
    count(*) as oportunidades,
    sum(valor_oportunidade) as pipeline_total,
    count(*) filter (where encerrada) as encerradas,
    count(*) filter (where ganha) as ganhas,
    sum(valor_oportunidade) filter (where ganha) as valor_ganho,
    count(*) filter (where ganha)
        / nullif(count(*) filter (where encerrada), 0) as win_rate
from {{ ref('stg_oportunidades') }}
group by regiao
order by valor_ganho desc nulls last

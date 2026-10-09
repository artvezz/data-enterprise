{{ config(materialized='table', tags=['comercial','mart']) }}

-- ============================================================
-- conversao_mensal: criacao x ganho de oportunidades
-- ============================================================

select
    competencia,
    count(*) as oportunidades_criadas,
    sum(valor_oportunidade) as valor_criado,
    count(*) filter (where encerrada) as encerradas,
    count(*) filter (where ganha) as ganhas,
    count(*) filter (where perdida) as perdidas,
    sum(valor_oportunidade) filter (where ganha) as valor_ganho,
    count(*) filter (where ganha)
        / nullif(count(*) filter (where encerrada), 0) as taxa_win
from {{ ref('stg_oportunidades') }}
group by competencia
order by competencia

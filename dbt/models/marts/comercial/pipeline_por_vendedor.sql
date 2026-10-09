{{ config(materialized='table', tags=['comercial','mart']) }}

-- ============================================================
-- pipeline_por_vendedor: win rate e receita por pessoa
-- ============================================================

select
    o.vendedor_id,
    v.nome as vendedor,
    v.regiao,
    count(*) as oportunidades,
    sum(o.valor_oportunidade) as pipeline_total,
    sum(o.valor_oportunidade) filter (where o.ganha) as valor_ganho,
    count(*) filter (where o.encerrada) as encerradas,
    count(*) filter (where o.ganha) as ganhas,
    count(*) filter (where o.perdida) as perdidas,
    count(*) filter (where o.ganha)
        / nullif(count(*) filter (where o.encerrada), 0) as win_rate,
    sum(o.valor_oportunidade) filter (where o.ganha)
        / nullif(count(*) filter (where o.ganha), 0) as ticket_medio_ganho
from {{ ref('stg_oportunidades') }} o
left join {{ ref('stg_vendedores') }} v on v.vendedor_id = o.vendedor_id
group by o.vendedor_id, v.nome, v.regiao
order by valor_ganho desc nulls last

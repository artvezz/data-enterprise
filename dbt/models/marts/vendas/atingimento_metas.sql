{{ config(materialized='table', tags=['vendas','mart']) }}

-- ============================================================
-- atingimento_metas: meta x realizado por vendedor/competencia
-- ============================================================

select
    m.competencia,
    m.vendedor_id,
    v.nome as vendedor,
    v.regiao,
    m.meta_valor,
    coalesce(r.realizado, 0) as realizado,
    coalesce(r.pedidos, 0) as pedidos,
    round(
        coalesce(r.realizado, 0) / nullif(m.meta_valor, 0), 4
    ) as atingimento_pct,
    coalesce(r.realizado, 0) - coalesce(m.meta_valor, 0) as desvio,
    case
        when m.meta_valor <= 0 then 'SEM META'
        when coalesce(r.realizado, 0) >= m.meta_valor then 'ATINGIDA'
        when coalesce(r.realizado, 0) >= m.meta_valor * 0.9 then 'PROXIMA'
        else 'ABAIXO'
    end as status_meta
from {{ ref('stg_metas_vendas') }} m
left join (
    select
        competencia,
        vendedor_id,
        sum(valor_liquido) as realizado,
        count(distinct pedido_id) as pedidos
    from {{ ref('stg_pedidos_vendas') }}
    where faturado
    group by competencia, vendedor_id
) r
    on r.competencia = m.competencia
   and r.vendedor_id = m.vendedor_id
left join {{ ref('stg_vendedores') }} v on v.vendedor_id = m.vendedor_id

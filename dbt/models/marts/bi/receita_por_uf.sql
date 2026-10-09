{{ config(materialized='table', tags=['bi','mart']) }}

-- ============================================================
-- receita_por_uf: distribuicao geografica da receita
-- ============================================================

select
    c.uf,
    r.regiao,
    sum(p.valor_liquido) as receita,
    count(distinct p.cliente_id) as clientes,
    count(distinct p.pedido_id) as pedidos,
    sum(p.valor_liquido)
        / nullif(count(distinct p.cliente_id), 0) as receita_por_cliente
from {{ ref('stg_pedidos_vendas') }} p
left join {{ ref('stg_clientes') }} c on c.cliente_id = p.cliente_id
left join (
    select uf, max(regiao) as regiao from {{ ref('stg_regiao') }} group by uf
) r on r.uf = c.uf
where p.faturado
group by c.uf, r.regiao
order by receita desc

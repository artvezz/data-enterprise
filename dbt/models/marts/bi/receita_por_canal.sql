{{ config(materialized='table', tags=['bi','mart']) }}

-- ============================================================
-- receita_por_canal: mix de receita por canal de venda
-- ============================================================

select
    c.canal,
    sum(p.valor_liquido) as receita,
    count(distinct p.pedido_id) as pedidos,
    sum(p.valor_liquido)
        / nullif(count(distinct p.pedido_id), 0) as ticket_medio,
    count(distinct p.cliente_id) as clientes
from {{ ref('stg_pedidos_vendas') }} p
left join {{ ref('stg_clientes') }} c on c.cliente_id = p.cliente_id
where p.faturado
group by c.canal
order by receita desc

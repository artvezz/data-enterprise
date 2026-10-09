{{ config(materialized='table', tags=['bi','mart']) }}

-- ============================================================
-- receita_por_segmento: mix de receita por segmento de cliente
-- ============================================================

select
    c.segmento,
    sum(p.valor_liquido) as receita,
    count(distinct p.pedido_id) as pedidos,
    count(distinct p.cliente_id) as clientes,
    sum(p.valor_liquido)
        / nullif(count(distinct p.cliente_id), 0) as receita_por_cliente
from {{ ref('stg_pedidos_vendas') }} p
left join {{ ref('stg_clientes') }} c on c.cliente_id = p.cliente_id
where p.faturado
group by c.segmento
order by receita desc

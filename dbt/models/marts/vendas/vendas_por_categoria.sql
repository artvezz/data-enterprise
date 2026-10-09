{{ config(materialized='table', tags=['vendas','mart']) }}

-- ============================================================
-- vendas_por_categoria: desempenho por categoria de produto
-- ============================================================

select
    categoria,
    count(distinct pedido_id) as pedidos,
    sum(quantidade) as itens,
    sum(valor_liquido) as receita,
    sum(valor_liquido) / nullif(count(distinct pedido_id), 0) as ticket_medio,
    avg(desconto_pct) as desconto_medio
from {{ ref('fatos_pedidos') }}
where faturado
group by categoria
order by receita desc

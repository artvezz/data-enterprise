{{ config(materialized='table', tags=['bi','mart']) }}

-- ============================================================
-- receita_por_mes: serie mensal de receita (visao consolidada)
-- ============================================================

select
    competencia,
    sum(valor_liquido) as receita_liquida,
    sum(valor_bruto - valor_liquido) as desconto,
    count(distinct pedido_id) as pedidos,
    sum(quantidade) as itens,
    sum(valor_liquido) / nullif(count(distinct pedido_id), 0) as ticket_medio,
    count(distinct cliente_id) as clientes
from {{ ref('stg_pedidos_vendas') }}
where faturado
group by competencia
order by competencia

{{ config(materialized='table', tags=['vendas','mart']) }}

-- ============================================================
-- vendas_mensais: KPI de receita por competencia
-- ============================================================

select
    competencia,
    count(distinct pedido_id) as pedidos,
    sum(quantidade) as itens,
    sum(valor_bruto) as receita_bruta,
    sum(valor_liquido) as receita_liquida,
    sum(valor_bruto - valor_liquido) as desconto_total,
    sum(valor_liquido)
        / nullif(count(distinct pedido_id), 0) as ticket_medio,
    percentile_cont(0.5) within group (order by valor_liquido) as ticket_mediano,
    count(distinct cliente_id) as clientes_atendidos,
    count(distinct vendedor_id) as vendedores_ativos
from {{ ref('fatos_pedidos') }}
where faturado
group by competencia
order by competencia

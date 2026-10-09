{{ config(materialized='table', tags=['vendas','mart']) }}

-- ============================================================
-- vendas_por_cliente: ranking de clientes (RFM simples)
-- ============================================================

select
    cliente_id,
    razao_social,
    segmento,
    uf,
    canal,
    count(distinct pedido_id) as pedidos,
    sum(quantidade) as itens,
    sum(valor_liquido) as receita,
    sum(valor_liquido) / nullif(count(distinct pedido_id), 0) as ticket_medio,
    max(data_pedido) as ultimo_pedido,
    min(data_pedido) as primeiro_pedido,
    current_date - max(data_pedido) as dias_desde_ultimo_pedido
from {{ ref('fatos_pedidos') }}
where faturado
group by cliente_id, razao_social, segmento, uf, canal
order by receita desc

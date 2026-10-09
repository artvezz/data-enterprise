{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='pedido_id',
    tags=['vendas','mart']
) }}

-- ============================================================
-- fatos_pedidos: juncao de pedidos x cliente x produto x vendedor
-- Materializado como incremental (merge por pedido_id): a cada
-- run somente o mes corrente + janela de 6 meses sao reprocessados,
-- e alteracoes em pedidos existentes viram update (nao duplicam).
-- ============================================================

select
    p.pedido_id,
    p.data_pedido,
    date_trunc('month', p.data_pedido)::date as competencia,
    p.cliente_id,
    c.razao_social,
    c.segmento,
    c.uf,
    c.canal,
    c.status_cliente,
    p.produto_id,
    pr.descricao as produto,
    pr.categoria,
    p.vendedor_id,
    v.nome as vendedor,
    v.regiao,
    p.quantidade,
    p.preco_unitario,
    p.desconto_pct,
    p.valor_bruto,
    p.valor_liquido,
    p.forma_pagamento,
    p.status_pedido,
    p.faturado,
    p.pedido_valido,
    p.data_previsao_entrega,
    p.data_entrega_real,
    p.dias_atraso_entrega
from {{ ref('stg_pedidos_vendas') }} p
left join {{ ref('stg_clientes') }}  c  on c.cliente_id  = p.cliente_id
left join {{ ref('stg_produtos') }}  pr on pr.produto_id = p.produto_id
left join {{ ref('stg_vendedores') }} v on v.vendedor_id = p.vendedor_id
where p.pedido_valido
{% if is_incremental() %}
    and p.data_pedido >= (select max(competencia) from {{ this }}) - interval '6 months'
{% endif %}

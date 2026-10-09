-- ============================================================
-- stg_pedidos_vendas: pedidos do ERP, tipos corrigidos e dedupe
-- ============================================================

with pedidos as (
    select
        cast(pedido_id as text)                as pedido_id,
        cast(cliente_id as text)               as cliente_id,
        cast(produto_id as text)               as produto_id,
        cast(data_pedido as date)              as data_pedido,
        cast(vendedor_id as text)              as vendedor_id,
        cast(quantidade as integer)            as quantidade,
        cast(preco_unitario as numeric(18, 2)) as preco_unitario,
        cast(desconto_pct as numeric(5, 4))    as desconto_pct,
        cast(valor_bruto as numeric(18, 2))    as valor_bruto,
        cast(valor_liquido as numeric(18, 2))  as valor_liquido,
        upper(trim(forma_pagamento))           as forma_pagamento,
        upper(trim(status_pedido))             as status_pedido,
        cast(data_previsao_entrega as date)    as data_previsao_entrega,
        cast(data_entrega_real as date)        as data_entrega_real,
        ingestion_timestamp
    from {{ source('raw', 'pedidos_vendas') }}
    where pedido_id is not null
),

deduplicado as (
    select distinct on (pedido_id)
        pedido_id,
        cliente_id,
        produto_id,
        data_pedido,
        vendedor_id,
        quantidade,
        preco_unitario,
        desconto_pct,
        valor_bruto,
        valor_liquido,
        forma_pagamento,
        status_pedido,
        data_previsao_entrega,
        data_entrega_real,
        ingestion_timestamp
    from pedidos
    order by pedido_id, ingestion_timestamp desc
)

select
    pedido_id,
    cliente_id,
    produto_id,
    data_pedido,
    vendedor_id,
    quantidade,
    preco_unitario,
    desconto_pct,
    valor_bruto,
    valor_liquido,
    forma_pagamento,
    status_pedido,
    data_previsao_entrega,
    data_entrega_real,
    ingestion_timestamp,

    status_pedido <> 'CANCELADO' as pedido_valido,

    status_pedido in ('APROVADO', 'EM SEPARACAO', 'EM TRANSPORTE', 'ENTREGUE') as faturado,

    date_trunc('month', data_pedido)::date as competencia,

    coalesce(data_entrega_real, data_previsao_entrega) as data_referencia_entrega,

    case
        when data_entrega_real is not null and data_previsao_entrega is not null
            then greatest(data_entrega_real - data_previsao_entrega, 0)
    end as dias_atraso_entrega

from deduplicado

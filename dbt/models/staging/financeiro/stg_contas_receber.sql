-- ============================================================
-- stg_contas_receber: titulos a receber com aging (DSO)
-- ============================================================

with base as (
    select
        cast(conta_receber_id as text) as conta_receber_id,
        cast(cliente_id as text)       as cliente_id,
        cast(pedido_id as text)        as pedido_id,
        cast(data_emissao as date)     as data_emissao,
        cast(data_vencimento as date)  as data_vencimento,
        cast(nullif(trim(data_recebimento), '') as date) as data_recebimento,
        cast(valor as numeric(18, 2))  as valor,
        upper(trim(status))            as status,
        upper(trim(forma_pagamento))   as forma_pagamento,
        ingestion_timestamp
    from {{ source('raw', 'contas_receber') }}
    where conta_receber_id is not null
)

select
    conta_receber_id,
    cliente_id,
    pedido_id,
    data_emissao,
    data_vencimento,
    data_recebimento,
    valor,
    status,
    forma_pagamento,
    ingestion_timestamp,

    status in ('VENCIDO', 'ATRASADO')
        or (status = 'ABERTO' and data_vencimento < current_date) as vencido,

    status = 'RECEBIDO' as liquidado,

    date_trunc('month', data_emissao)::date as competencia_emissao,

    case
        when status <> 'RECEBIDO'
            then greatest(current_date - data_vencimento, 0)
    end as dias_atraso_recebimento,

    case
        when status = 'RECEBIDO' and data_recebimento is not null
            then data_recebimento - data_emissao
    end as dias_ciclo_recebimento,

    case
        when status = 'RECEBIDO' then 'RECEBIDO'
        when current_date <= data_vencimento then 'A VENCER'
        when current_date - data_vencimento <= 30  then 'VENCIDO 1-30'
        when current_date - data_vencimento <= 60  then 'VENCIDO 31-60'
        when current_date - data_vencimento <= 90  then 'VENCIDO 61-90'
        else 'VENCIDO 90+'
    end as faixa_aging

from base

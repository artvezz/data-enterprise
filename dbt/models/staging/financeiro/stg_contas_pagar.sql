-- ============================================================
-- stg_contas_pagar: titulos a pagar com aging
-- ============================================================

with base as (
    select
        cast(conta_pagar_id as text)   as conta_pagar_id,
        upper(trim(fornecedor))        as fornecedor,
        upper(trim(categoria))         as categoria,
        cast(data_emissao as date)     as data_emissao,
        cast(data_vencimento as date)  as data_vencimento,
        cast(nullif(trim(data_pagamento), '') as date) as data_pagamento,
        cast(valor as numeric(18, 2))  as valor,
        upper(trim(status))            as status,
        upper(trim(centro_custo))      as centro_custo,
        ingestion_timestamp
    from {{ source('raw', 'contas_pagar') }}
    where conta_pagar_id is not null
)

select
    conta_pagar_id,
    fornecedor,
    categoria,
    data_emissao,
    data_vencimento,
    data_pagamento,
    valor,
    status,
    centro_custo,
    ingestion_timestamp,

    case
        when status = 'PAGO' then false
        when status = 'ATRASADO' then true
        when data_vencimento < current_date then true
        else false
    end as em_atraso,

    status = 'PAGO' as liquidado,

    date_trunc('month', data_vencimento)::date as competencia_vencimento,

    case
        when status = 'PAGO'
            then greatest(coalesce(data_pagamento, data_vencimento) - data_vencimento, 0)
        when current_date <= data_vencimento
            then 0
        else current_date - data_vencimento
    end as dias_relativo_vencimento,

    case
        when status = 'PAGO' then 'PAGO'
        when current_date <= data_vencimento then 'A VENCER'
        when current_date - data_vencimento <= 30  then 'VENCIDO 1-30'
        when current_date - data_vencimento <= 60  then 'VENCIDO 31-60'
        when current_date - data_vencimento <= 90  then 'VENCIDO 61-90'
        else 'VENCIDO 90+'
    end as faixa_aging

from base

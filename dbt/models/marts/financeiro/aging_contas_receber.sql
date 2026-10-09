{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['data_ref', 'faixa_aging'],
    tags=['financeiro','mart']
) }}

-- ============================================================
-- aging_contas_receber: snapshot diario da carteira em aberto.
-- Incremental (append por dia): cada run gera uma nova data_ref
-- com a carteira 'do dia', e rodadas no mesmo dia nao duplicam
-- (merge por data_ref + faixa_aging). Para 'ver' a carteira do
-- dia corrente: where data_ref = (select max(data_ref) from ...).
-- ============================================================

select
    current_date as data_ref,
    faixa_aging,
    count(*) as titulos,
    sum(valor) as valor_total,
    count(distinct cliente_id) as clientes,
    sum(valor)
        / nullif((select sum(valor) from {{ ref('stg_contas_receber') }}
                  where status <> 'RECEBIDO'), 0) as pct_carteira
from {{ ref('stg_contas_receber') }}
where status <> 'RECEBIDO'
group by faixa_aging
order by
    case faixa_aging
        when 'A VENCER'      then 0
        when 'VENCIDO 1-30'  then 1
        when 'VENCIDO 31-60' then 2
        when 'VENCIDO 61-90' then 3
        when 'VENCIDO 90+'   then 4
    end

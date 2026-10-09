{{ config(materialized='table', tags=['financeiro','mart']) }}

-- ============================================================
-- contas_pagar_aging: carteira a pagar por faixa de atraso
-- ============================================================

select
    current_date as data_ref,
    faixa_aging,
    count(*) as titulos,
    sum(valor) as valor_total,
    count(distinct fornecedor) as fornecedores,
    sum(valor)
        / nullif((select sum(valor) from {{ ref('stg_contas_pagar') }}
                  where status <> 'PAGO'), 0) as pct_carteira
from {{ ref('stg_contas_pagar') }}
where status <> 'PAGO'
group by faixa_aging
order by
    case faixa_aging
        when 'A VENCER'      then 0
        when 'VENCIDO 1-30'  then 1
        when 'VENCIDO 31-60' then 2
        when 'VENCIDO 61-90' then 3
        when 'VENCIDO 90+'   then 4
    end

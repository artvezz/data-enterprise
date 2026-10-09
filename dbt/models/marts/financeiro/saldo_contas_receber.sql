{{ config(materialized='table', tags=['financeiro','mart']) }}

-- ============================================================
-- saldo_contas_receber: saldo em aberto por cliente
-- ============================================================

select
    r.cliente_id,
    c.razao_social,
    c.segmento,
    c.uf,
    count(*) as titulos_abertos,
    sum(r.valor) as saldo_aberto,
    min(r.data_vencimento) as vencimento_mais_antigo,
    max(current_date - r.data_vencimento) as maior_atraso_dias,
    sum(r.valor) filter (where r.vencido) as valor_vencido
from {{ ref('stg_contas_receber') }} r
left join {{ ref('stg_clientes') }} c on c.cliente_id = r.cliente_id
where r.status <> 'RECEBIDO'
group by r.cliente_id, c.razao_social, c.segmento, c.uf
order by saldo_aberto desc

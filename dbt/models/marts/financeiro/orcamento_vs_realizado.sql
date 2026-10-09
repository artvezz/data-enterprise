{{ config(materialized='table', tags=['financeiro','mart']) }}

-- ============================================================
-- orcamento_vs_realizado: execucao orcamentaria por conta/mes
-- ============================================================

select
    competencia,
    conta_contabil,
    descricao_conta,
    tipo,
    centro_custo,
    sum(valor_orcado)    as valor_orcado,
    sum(valor_realizado) as valor_realizado,
    sum(valor_realizado) - sum(valor_orcado) as desvio,
    (sum(valor_realizado) / nullif(sum(valor_orcado), 0)) - 1 as desvio_pct
from {{ ref('stg_orcamento') }}
group by competencia, conta_contabil, descricao_conta, tipo, centro_custo
order by competencia, abs(sum(valor_realizado) - sum(valor_orcado)) desc

{{ config(materialized='table', tags=['marketing','mart']) }}

-- ============================================================
-- campanhas_mensais: evolucao da investimento x receita
-- ============================================================

select
    competencia,
    count(*) as campanhas,
    sum(investimento) as investimento_total,
    sum(receita_atribuida) as receita_atribuida,
    sum(leads_gerados) as leads,
    sum(conversoes) as conversoes,
    sum(receita_atribuida) / nullif(sum(investimento), 0) as roi,
    sum(investimento) / nullif(sum(leads_gerados), 0) as custo_por_lead
from {{ ref('stg_campanhas') }}
group by competencia
order by competencia

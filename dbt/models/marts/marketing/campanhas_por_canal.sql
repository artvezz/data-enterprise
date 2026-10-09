{{ config(materialized='table', tags=['marketing','mart']) }}

-- ============================================================
-- campanhas_por_canal: ROI e eficiencia por canal
-- ============================================================

select
    canal,
    count(*) as campanhas,
    sum(investimento) as investimento_total,
    sum(receita_atribuida) as receita_atribuida,
    sum(leads_gerados) as leads,
    sum(conversoes) as conversoes,
    sum(receita_atribuida) / nullif(sum(investimento), 0) as roi,
    sum(conversoes) / nullif(sum(leads_gerados), 0) as taxa_conversao,
    sum(investimento) / nullif(sum(leads_gerados), 0) as custo_por_lead,
    sum(receita_atribuida) / nullif(sum(conversoes), 0) as receita_por_conversao
from {{ ref('stg_campanhas') }}
group by canal
order by receita_atribuida desc

-- ============================================================
-- stg_campanhas: campanhas de marketing pagas
-- ============================================================

select
    cast(campanha_id as text)    as campanha_id,
    upper(trim(nome_campanha))   as nome_campanha,
    upper(trim(canal))           as canal,
    cast(data_inicio as date)    as data_inicio,
    cast(data_fim as date)       as data_fim,
    cast(investimento as numeric(18, 2))    as investimento,
    cast(leads_gerados as integer)          as leads_gerados,
    cast(conversoes as numeric(18, 2))      as conversoes,
    cast(receita_atribuida as numeric(18,2)) as receita_atribuida,
    cast(cpa as numeric(18, 2))             as cpa,
    upper(trim(status))         as status,

    (cast(data_fim as date) - cast(data_inicio as date)) + 1 as dias_campanha,
    cast(receita_atribuida as numeric(18,2))
        / nullif(cast(investimento as numeric(18,2)), 0) as roi,
    cast(conversoes as numeric(18,2))
        / nullif(cast(leads_gerados as integer), 0)      as taxa_conversao,
    cast(investimento as numeric(18,2))
        / nullif(cast(leads_gerados as integer), 0)      as custo_por_lead,
    date_trunc('month', data_inicio)::date as competencia

from {{ source('raw', 'campanhas') }}
where campanha_id is not null

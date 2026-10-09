-- ============================================================
-- stg_atuacoes_marketing: metricas diarias de trafego por canal
-- ============================================================

select
    cast(data as date) as data,
    upper(trim(canal)) as canal,
    cast(sessoes as integer)       as sessoes,
    cast(sessoes_pagas as integer) as sessoes_pagas,
    cast(usuarios_unicos as integer) as usuarios_unicos,
    cast(taxa_conversao as numeric(6, 4)) as taxa_conversao,
    cast(custo_clique as numeric(18, 4))  as custo_clique,
    cast(custo_lead as numeric(18, 2))    as custo_lead,

    cast(sessoes_pagas as numeric) / nullif(cast(sessoes as numeric), 0) as pct_sessoes_pagas,
    cast(sessoes as numeric) * cast(custo_clique as numeric(18,4)) as custo_estimado_dia,
    cast(sessoes as numeric) * cast(taxa_conversao as numeric(6,4)) as conversoes_estimadas_dia,
    date_trunc('month', data)::date as competencia

from {{ source('raw', 'atuacoes_marketing') }}
where data is not null

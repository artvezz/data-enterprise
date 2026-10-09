{{ config(materialized='table', tags=['marketing','mart']) }}

-- ============================================================
-- trafego_mensal: volume e custo de trafego
-- ============================================================

select
    competencia,
    sum(sessoes) as sessoes,
    sum(sessoes_pagas) as sessoes_pagas,
    sum(usuarios_unicos) as usuarios_unicos,
    sum(sessoes_pagas) / nullif(sum(sessoes), 0) as pct_sessoes_pagas,
    avg(taxa_conversao) as taxa_conversao_media,
    sum(custo_estimado_dia) as investimento_estimado,
    avg(custo_clique) as custo_clique_medio,
    avg(custo_lead) as custo_lead_medio
from {{ ref('stg_atuacoes_marketing') }}
group by competencia
order by competencia

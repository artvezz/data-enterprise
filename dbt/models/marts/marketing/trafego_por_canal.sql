{{ config(materialized='table', tags=['marketing','mart']) }}

-- ============================================================
-- trafego_por_canal: comparativo de canais de aquisicao
-- ============================================================

select
    canal,
    count(*) as dias_medidos,
    sum(sessoes) as sessoes,
    sum(sessoes_pagas) as sessoes_pagas,
    sum(usuarios_unicos) as usuarios_unicos,
    sum(sessoes_pagas) / nullif(sum(sessoes), 0) as pct_sessoes_pagas,
    avg(custo_clique) as custo_clique_medio,
    avg(custo_lead) as custo_lead_medio,
    avg(taxa_conversao) as taxa_conversao_media
from {{ ref('stg_atuacoes_marketing') }}
group by canal
order by sessoes desc

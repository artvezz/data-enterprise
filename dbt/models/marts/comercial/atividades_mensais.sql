{{ config(materialized='table', tags=['comercial','mart']) }}

-- ============================================================
-- atividades_mensais: produtividade de prospeccao
-- ============================================================

select
    competencia,
    count(*) as atividades,
    count(distinct oportunidade_id) as oportunidades_atendidas,
    count(distinct vendedor_id) as vendedores_ativos,
    sum(duracao_min) as minutos_total,
    avg(duracao_min) as duracao_media_min,
    count(*) filter (where positivo) as atividades_positivas,
    count(*) filter (where positivo)
        / nullif(count(*), 0) as taxa_atividade_positiva
from {{ ref('stg_leads') }}
group by competencia
order by competencia

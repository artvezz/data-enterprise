{{ config(materialized='table', tags=['comercial','mart']) }}

-- ============================================================
-- pipeline_por_etapa: carteira por etapa do funil
-- ============================================================

select
    etapa,
    count(*) as oportunidades,
    sum(valor_oportunidade) as valor_total,
    sum(valor_ponderado) as valor_ponderado,
    avg(probabilidade) as probabilidade_media,
    count(*) filter (where encerrada) as encerradas,
    count(*) filter (where ganha) as ganhas,
    avg(valor_oportunidade) as ticket_medio
from {{ ref('stg_oportunidades') }}
group by etapa
order by valor_total desc

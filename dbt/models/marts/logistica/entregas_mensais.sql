{{ config(materialized='table', tags=['logistica','mart']) }}

-- ============================================================
-- entregas_mensais: OTIF e custo de frete no tempo
-- ============================================================

select
    competencia,
    count(*) as notas,
    count(*) filter (where entregue) as entregues,
    count(*) filter (where em_transito) as em_transito,
    count(*) filter (where entregue_no_prazo) as no_prazo,
    count(*) filter (where entregue_no_prazo)
        / nullif(count(*) filter (where entregue), 0) as otif,
    sum(custo_frete) as custo_frete_total,
    avg(peso_kg) as peso_medio_kg,
    avg(dias_atraso_unico) as atraso_medio_dias,
    avg(prazo_dias) as prazo_contratado_medio
from {{ ref('stg_entregas') }}
group by competencia
order by competencia

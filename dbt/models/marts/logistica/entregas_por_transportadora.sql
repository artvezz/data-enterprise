{{ config(materialized='table', tags=['logistica','mart']) }}

-- ============================================================
-- entregas_por_transportadora: desempenho de 3o por parceiro
-- ============================================================

select
    transportadora,
    count(*) as notas,
    count(*) filter (where entregue) as entregues,
    count(*) filter (where entregue_no_prazo) as no_prazo,
    count(*) filter (where entregue_no_prazo)
        / nullif(count(*) filter (where entregue), 0) as otif,
    avg(dias_atraso_unico) as atraso_medio_dias,
    sum(custo_frete) as custo_frete_total,
    sum(custo_frete) / nullif(sum(peso_kg), 0) as custo_por_kg,
    avg(prazo_dias) as prazo_medio_dias
from {{ ref('stg_entregas') }}
group by transportadora
order by custo_frete_total desc

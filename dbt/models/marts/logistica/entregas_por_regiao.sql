{{ config(materialized='table', tags=['logistica','mart']) }}

-- ============================================================
-- entregas_por_regiao: cobertura geografica x prazo
-- ============================================================

select
    regiao_origem,
    centro_origem,
    centro_destino,
    count(*) as notas,
    count(*) filter (where entregue) as entregues,
    count(*) filter (where entregue_no_prazo) as no_prazo,
    count(*) filter (where entregue_no_prazo)
        / nullif(count(*) filter (where entregue), 0) as otif,
    sum(custo_frete) as custo_frete_total,
    avg(prazo_dias) as prazo_medio_dias,
    avg(peso_kg) as peso_medio_kg
from {{ ref('stg_entregas') }}
group by regiao_origem, centro_origem, centro_destino
order by custo_frete_total desc

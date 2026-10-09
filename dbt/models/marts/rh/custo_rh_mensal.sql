{{ config(materialized='table', tags=['rh','mart']) }}

-- ============================================================
-- custo_rh_mensal: folha consolidada por competencia
-- ============================================================

select
    competencia,
    sum(folha_bruta) as folha_bruta,
    sum(encargos) as encargos,
    sum(beneficios) as beneficios,
    sum(custo_total) as custo_total,
    sum(qtd_colaboradores) as colaboradores,
    sum(encargos) / nullif(sum(folha_bruta), 0) as pct_encargos,
    sum(custo_total) / nullif(sum(qtd_colaboradores), 0) as custo_medio_colaborador,
    bool_and(custo_total_consistente) as dados_consistentes
from {{ ref('stg_custos_rh') }}
group by competencia
order by competencia

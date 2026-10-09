-- ============================================================
-- stg_custos_rh: folha, encargos e beneficios por competencia/area
-- ============================================================

select
    to_date(competencia, 'YYYY-MM') as competencia,
    upper(trim(area))               as area,
    cast(folha_bruta as numeric(18, 2))        as folha_bruta,
    cast(encargos as numeric(18, 2))           as encargos,
    cast(beneficios as numeric(18, 2))         as beneficios,
    cast(custo_total as numeric(18, 2))        as custo_total,
    cast(qtd_colaboradores as integer)         as qtd_colaboradores,
    ingestion_timestamp,

    cast(encargos as numeric(18, 2))
        / nullif(cast(folha_bruta as numeric(18, 2)), 0) as pct_encargos,
    cast(beneficios as numeric(18, 2))
        / nullif(cast(folha_bruta as numeric(18, 2)), 0) as pct_beneficios,

    -- guarda de qualidade: custo_total precisa bater com a soma dos componentes
    abs(
        cast(custo_total as numeric(18, 2))
        - (cast(folha_bruta as numeric(18, 2))
           + cast(encargos as numeric(18, 2))
           + cast(beneficios as numeric(18, 2)))
    ) < 0.01 as custo_total_consistente

from {{ source('raw', 'remuneracao') }}
where competencia is not null

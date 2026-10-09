-- ============================================================
-- stg_orcamento: orcamento aprovado por conta/competencia
-- ============================================================

select
    cast(ano as integer) as ano,
    cast(mes as integer) as mes,
    make_date(cast(ano as integer), cast(mes as integer), 1) as competencia,
    cast(conta_contabil as text) as conta_contabil,
    descricao_conta,
    upper(trim(tipo))  as tipo,
    cast(valor_orcado as numeric(18, 2))    as valor_orcado,
    cast(valor_realizado as numeric(18, 2)) as valor_realizado,
    upper(trim(centro_custo)) as centro_custo
from {{ source('raw', 'orcamento') }}
where ano is not null
  and mes is not null

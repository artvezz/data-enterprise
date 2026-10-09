-- ============================================================
-- stg_metas_vendas: metas por vendedor/competencia
-- ============================================================

select
    cast(vendedor_id as text) as vendedor_id,
    to_date(competencia, 'YYYY-MM') as competencia,
    cast(meta_valor as numeric(18, 2)) as meta_valor
from {{ source('raw', 'metas_vendas') }}
where vendedor_id is not null
  and competencia is not null

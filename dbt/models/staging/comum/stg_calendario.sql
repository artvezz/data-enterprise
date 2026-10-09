-- ============================================================
-- stg_calendario: calendario corporativo util
-- ============================================================

select
    cast(data as date) as data,
    cast(ano as integer) as ano,
    cast(mes as integer) as mes,
    mes_nome,
    cast(trimestre as integer) as trimestre,
    cast(semana as integer) as semana,
    dia_semana,
    cast(is_util as integer) = 1 as dia_util,
    date_trunc('month', data)::date as competencia
from {{ source('raw', 'dim_calendario') }}
where data is not null

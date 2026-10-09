-- ============================================================
-- stg_ferias: ferias e licencas
-- ============================================================

select
    cast(ferias_id as text) as ferias_id,
    cast(colaborador_id as text) as colaborador_id,
    cast(data_inicio as date) as data_inicio,
    cast(data_fim as date)    as data_fim,
    cast(dias_ferias as integer) as dias_ferias,
    upper(trim(status_ferias)) as status_ferias,
    upper(trim(tipo))         as tipo_ausencia,
    upper(trim(tipo)) like 'LICENCA%' as licenca_medica,
    date_trunc('month', data_inicio)::date as competencia,
    (data_fim - data_inicio) + 1 as dias_calc,
    data_fim - data_inicio + 1 <> cast(dias_ferias as integer) as dias_divergentes
from {{ source('raw', 'ferias') }}
where colaborador_id is not null

-- ============================================================
-- stg_ponto: batimentos diarios ja calculados
-- ============================================================

select
    cast(ponto_id as text) as ponto_id,
    cast(colaborador_id as text) as colaborador_id,
    cast(data_hora_entrada as timestamp) as data_hora_entrada,
    cast(data_hora_entrada as date)      as data,
    date_trunc('month', data_hora_entrada)::date as competencia,
    cast(nullif(trim(hora_saida), '') as time) as hora_saida,
    cast(horas_trabalhadas as numeric(5, 2))   as horas_trabalhadas,
    upper(trim(situacao))                  as situacao,
    upper(trim(situacao)) = 'FALTA'        as falta,
    upper(trim(situacao)) = 'ATRASO'       as atraso,
    upper(trim(situacao)) = 'REMOTO'       as remoto,
    ingestion_timestamp
from {{ source('raw', 'folha_ponto') }}
where colaborador_id is not null

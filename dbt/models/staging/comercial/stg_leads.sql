-- ============================================================
-- stg_leads: atividades de prospeccao registradas no CRM
-- ============================================================

select
    cast(atividade_id as text)    as atividade_id,
    cast(oportunidade_id as text) as oportunidade_id,
    cast(data_atividade as date)  as data_atividade,
    upper(trim(tipo_atividade))   as tipo_atividade,
    upper(trim(resultado))        as resultado,
    cast(duracao_min as integer)  as duracao_min,
    cast(vendedor_id as text)     as vendedor_id,

    upper(trim(resultado)) in ('POSITIVO', 'CONVERTIDO', 'AGENDADO') as positivo,
    date_trunc('month', data_atividade)::date as competencia

from {{ source('raw', 'leads') }}
where atividade_id is not null

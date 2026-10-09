-- ============================================================
-- stg_oportunidades: pipeline de oportunidades do CRM
-- ============================================================

select
    cast(oportunidade_id as text) as oportunidade_id,
    cast(cliente_id as text)      as cliente_id,
    cast(data_criacao as date)    as data_criacao,
    upper(trim(etapa))            as etapa,
    cast(valor_oportunidade as numeric(18, 2)) as valor_oportunidade,
    cast(probabilidade as numeric(6, 4))       as probabilidade,
    cast(valor_ponderado as numeric(18, 2))    as valor_ponderado,
    upper(trim(regiao))           as regiao,
    cast(vendedor_id as text)     as vendedor_id,
    upper(trim(status_oportunidade)) as status_oportunidade,
    cast(data_previsao_fechamento as date) as data_previsao_fechamento,

    upper(trim(status_oportunidade)) = 'GANHA'                    as ganha,
    upper(trim(status_oportunidade)) = 'PERDIDA'                  as perdida,
    upper(trim(status_oportunidade)) in ('GANHA', 'PERDIDA')      as encerrada,
    upper(trim(etapa)) in ('FECHADO', 'GANHO', 'PERDIDO')         as etapa_fechada,

    date_trunc('month', data_criacao)::date as competencia,
    date_trunc('month', data_previsao_fechamento)::date as competencia_previsao

from {{ source('raw', 'oportunidades') }}
where oportunidade_id is not null

{{ config(materialized='table', tags=['rh','mart']) }}

-- ============================================================
-- ferias_mensal: afastamentos programados
-- ============================================================

select
    competencia,
    count(*) as registros_ferias,
    sum(dias_ferias) as dias_ferias,
    count(distinct colaborador_id) as colaboradores,
    count(*) filter (where licenca_medica) as licencas_medicas,
    count(*) filter (where status_ferias = 'CONCLUIDA') as concluidas,
    count(*) filter (where dias_divergentes) as divergencias_calculo
from {{ ref('stg_ferias') }}
group by competencia
order by competencia

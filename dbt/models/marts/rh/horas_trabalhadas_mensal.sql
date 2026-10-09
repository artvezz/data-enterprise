{{ config(materialized='table', tags=['rh','mart']) }}

-- ============================================================
-- horas_trabalhadas_mensal: ponto, faltas e horas extras
-- ============================================================

select
    competencia,
    count(distinct colaborador_id) as colaboradores_com_registro,
    count(*) as registros_ponto,
    sum(horas_trabalhadas) as horas_trabalhadas,
    count(*) filter (where falta) as faltas,
    count(*) filter (where atraso) as atrasos,
    avg(horas_trabalhadas) as horas_media_dia,
    sum(horas_trabalhadas)
        / nullif(count(*) filter (where not falta), 0) as horas_media_dia_trabalha
from {{ ref('stg_ponto') }}
group by competencia
order by competencia

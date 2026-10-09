-- ============================================================
-- stg_cargos: catalogo de cargos e faixas salariais
-- ============================================================

select
    cast(cargo_id as text) as cargo_id,
    descricao_cargo,
    upper(trim(area))         as area,
    upper(trim(senioridade))  as senioridade,
    cast(faixa_salarial_min as numeric(18, 2)) as faixa_salarial_min,
    cast(faixa_salarial_max as numeric(18, 2)) as faixa_salarial_max
from {{ source('raw', 'cargos') }}
where cargo_id is not null

-- ============================================================
-- stg_regiao: hierarquia regiao > uf > cidade
-- ============================================================

select distinct
    upper(trim(regiao)) as regiao,
    upper(trim(uf))     as uf,
    cidade
from {{ source('raw', 'dim_regiao') }}
where regiao is not null
   or uf is not null

-- ============================================================
-- stg_vendedores: cadastro de vendedores
-- ============================================================

select
    cast(vendedor_id as text) as vendedor_id,
    upper(trim(nome))         as nome,
    upper(trim(regiao))       as regiao,
    cast(meta_mensal as numeric(18, 2)) as meta_mensal,
    cast(data_admissao as date) as data_admissao,
    upper(trim(status))       as status,
    upper(trim(status)) = 'ATIVO' as ativo
from {{ source('raw', 'vendedores') }}
where vendedor_id is not null

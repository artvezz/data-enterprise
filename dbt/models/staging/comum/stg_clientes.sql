-- ============================================================
-- stg_clientes: cadastro master de clientes
-- ============================================================

select
    cast(cliente_id as text)  as cliente_id,
    upper(trim(razao_social)) as razao_social,
    upper(trim(segmento))     as segmento,
    upper(trim(uf))           as uf,
    cidade,
    upper(trim(canal))        as canal,
    cast(data_criacao as date) as data_criacao,
    upper(trim(status_cliente)) as status_cliente,
    upper(trim(status_cliente)) = 'ATIVO' as cliente_ativo
from {{ source('raw', 'dim_cliente') }}
where cliente_id is not null

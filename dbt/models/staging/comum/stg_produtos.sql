-- ============================================================
-- stg_produtos: cadastro master de produtos
-- ============================================================

select
    cast(produto_id as text) as produto_id,
    descricao,
    upper(trim(categoria))   as categoria,
    cast(preco_lista as numeric(18, 2)) as preco_lista,
    upper(trim(ativo)) = 'TRUE' as produto_ativo
from {{ source('raw', 'dim_produto') }}
where produto_id is not null

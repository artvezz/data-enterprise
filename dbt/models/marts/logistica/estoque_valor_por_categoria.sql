{{ config(materialized='table', tags=['logistica','mart']) }}

-- ============================================================
-- estoque_valor_por_categoria: capital imobilizado em estoque
-- ============================================================

select
    p.categoria,
    count(distinct e.produto_id) as produtos,
    sum(e.quantidade_estoque) as unidades,
    sum(e.valor_estoque) as valor_estoque,
    count(*) filter (where e.abaixo_minimo) as itens_abaixo_minimo
from {{ ref('stg_estoque') }} e
left join {{ ref('stg_produtos') }} p on p.produto_id = e.produto_id
group by p.categoria
order by valor_estoque desc

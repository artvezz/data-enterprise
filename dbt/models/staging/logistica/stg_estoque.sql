-- ============================================================
-- stg_estoque: posicao de estoque por centro e produto
-- ============================================================

select
    cast(centro_id as text)    as centro_id,
    cast(produto_id as text)   as produto_id,
    cast(data_snapshot as date) as data_snapshot,
    cast(quantidade_estoque as integer) as quantidade_estoque,
    cast(estoque_minimo as integer)     as estoque_minimo,
    cast(custo_unitario as numeric(18, 2)) as custo_unitario,
    upper(trim(status))        as status,

    cast(quantidade_estoque as integer) <= cast(estoque_minimo as integer) as abaixo_minimo,
    cast(quantidade_estoque as integer) - cast(estoque_minimo as integer)  as saldo_sobre_minimo,
    cast(quantidade_estoque as numeric) * cast(custo_unitario as numeric(18,2)) as valor_estoque,

    date_trunc('month', data_snapshot)::date as competencia

from {{ source('raw', 'estoque') }}
where centro_id is not null
  and produto_id is not null

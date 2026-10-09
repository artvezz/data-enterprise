{{ config(materialized='table', tags=['logistica','mart']) }}

-- ============================================================
-- estoque_abaixo_minimo: SKUs em risco de ruptura
-- ============================================================

select
    e.centro_id,
    e.produto_id,
    p.descricao as produto,
    p.categoria,
    e.data_snapshot,
    e.quantidade_estoque,
    e.estoque_minimo,
    e.saldo_sobre_minimo as falta_para_minimo,
    e.custo_unitario,
    e.valor_estoque
from {{ ref('stg_estoque') }} e
left join {{ ref('stg_produtos') }} p on p.produto_id = e.produto_id
where e.abaixo_minimo
order by e.saldo_sobre_minimo, e.produto_id

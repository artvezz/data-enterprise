-- ============================================================
-- snapshot dim_produto_snapshot: historico SCD2 de produtos.
-- Nova versao a cada mudanca em (descricao, categoria, preco_lista, ativo).
-- ============================================================

{% snapshot dim_produto_snapshot %}

{{ config(
    target_schema='snapshots',
    unique_key='produto_id',
    strategy='check',
    check_cols=['descricao', 'categoria', 'preco_lista', 'produto_ativo'],
    hard_deletes='invalidate'
) }}

select
    produto_id,
    descricao,
    categoria,
    preco_lista,
    produto_ativo
from {{ ref('stg_produtos') }}

{% endsnapshot %}
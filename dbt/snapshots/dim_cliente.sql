-- ============================================================
-- snapshot dim_cliente_snapshot: historico SCD2 de clientes.
-- Registra versoes do cadastro: uma nova linha a cada mudanca
-- em (razao_social, segmento, uf, cidade, canal, status_cliente).
-- Colunas dbt_valid_from / dbt_valid_to controlam a vigencia.
-- ============================================================

{% snapshot dim_cliente_snapshot %}

{{ config(
    target_schema='snapshots',
    unique_key='cliente_id',
    strategy='check',
    check_cols=['razao_social', 'segmento', 'uf', 'cidade', 'canal', 'status_cliente'],
    hard_deletes='invalidate'
) }}

select
    cliente_id,
    razao_social,
    segmento,
    uf,
    cidade,
    canal,
    data_criacao,
    status_cliente,
    cliente_ativo
from {{ ref('stg_clientes') }}

{% endsnapshot %}
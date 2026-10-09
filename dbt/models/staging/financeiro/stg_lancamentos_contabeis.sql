-- ============================================================
-- stg_lancamentos_contabeis: ledger do ERP financeiro
-- Regime de competencia: data_competencia e a data de negocio;
-- data_lancamento e quando o fato foi contabilizado.
-- ============================================================

select
    cast(lancamento_id as text)     as lancamento_id,
    cast(data_lancamento as date)   as data_lancamento,
    cast(data_competencia as date)  as data_competencia,
    cast(conta_contabil as text)    as conta_contabil,
    upper(trim(descricao))          as descricao,
    upper(trim(tipo))               as tipo,
    cast(debito as numeric(18, 2))  as valor_debito,
    cast(credito as numeric(18, 2)) as valor_credito,
    upper(trim(centro_custo))       as centro_custo,
    cast(projeto as text)           as projeto,
    upper(trim(documento_origem))   as documento_origem,
    ingestion_timestamp,

    coalesce(cast(debito as numeric(18, 2)), 0)
        - coalesce(cast(credito as numeric(18, 2)), 0) as valor_liquido,

    date_trunc('month', data_competencia)::date as competencia,

    case
        when conta_contabil like '1%' then 'Ativo'
        when conta_contabil like '2%' then 'Passivo'
        when conta_contabil like '3%' then 'Resultado Custo'
        when conta_contabil like '4%' then 'Resultado Despesa'
        when conta_contabil like '5%' then 'Resultado Folha'
        else 'Outros'
    end as grupo_conta,

    case
        when conta_contabil like '1%' then 'Ativo'
        when conta_contabil like '2%' then 'Passivo'
        else 'Resultado'
    end as natureza_conta

from {{ source('raw', 'lancamentos_contabeis') }}
where lancamento_id is not null

-- ============================================================
-- stg_colaboradores: cadastro de colaboradores do sistema de folha
-- ============================================================

with base as (
    select
        cast(colaborador_id as text) as colaborador_id,
        upper(trim(nome))            as nome,
        upper(trim(cargo))           as cargo,
        upper(trim(area))            as area,
        upper(trim(senioridade))     as senioridade,
        upper(trim(uf))              as uf,
        cidade,
        cast(data_admissao as date)  as data_admissao,
        cast(nullif(trim(data_demissao), '') as date) as data_demissao,
        cast(salario_bruto as numeric(18, 2)) as salario_bruto,
        upper(trim(tipo_contrato))   as tipo_contrato,
        upper(trim(status))          as status,
        ingestion_timestamp
    from {{ source('raw', 'funcionarios') }}
    where colaborador_id is not null
),

deduplicado as (
    select *
    from (
        select
            base.*,
            row_number() over (
                partition by colaborador_id
                order by ingestion_timestamp desc nulls last
            ) as rn
        from base
    ) t
    where rn = 1
)

select
    colaborador_id,
    nome,
    cargo,
    area,
    senioridade,
    uf,
    cidade,
    data_admissao,
    data_demissao,
    salario_bruto,
    tipo_contrato,
    status,

    status = 'ATIVO'                     as ativo,
    tipo_contrato = 'CLT'                as is_clt,
    senioridade = 'ESTAGIARIO'           as is_estagiario,
    data_demissao is not null            as foi_desligado,
    data_demissao - data_admissao        as tempo_de_empresa_dias,
    date_trunc('month', data_admissao)::date as competencia_admissao,
    case
        when data_demissao is not null
            then date_trunc('month', data_demissao)::date
    end as competencia_demissao

from deduplicado

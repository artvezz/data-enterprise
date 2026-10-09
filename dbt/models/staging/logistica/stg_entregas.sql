-- ============================================================
-- stg_entregas: NF-e e status de entrega do TMS
-- ============================================================

select
    cast(nota_id as text)       as nota_id,
    cast(centro_origem as text) as centro_origem,
    cast(centro_destino as text) as centro_destino,
    cast(data_emissao as date)  as data_emissao,
    cast(pedido_id as text)     as pedido_id,
    upper(trim(transportadora)) as transportadora,
    cast(peso_kg as numeric(12, 3)) as peso_kg,
    cast(prazo_dias as integer) as prazo_dias,
    cast(data_entrega as date)  as data_entrega,
    cast(custo_frete as numeric(18, 2)) as custo_frete,
    upper(trim(status_entrega)) as status_entrega,
    upper(trim(regiao_origem))  as regiao_origem,

    cast(data_emissao as date) + cast(prazo_dias as integer) as data_prevista,

    upper(trim(status_entrega)) = 'ENTREGUE'               as entregue,
    upper(trim(status_entrega)) in ('EM_TRANSITO', 'EM TRANSITO') as em_transito,
    upper(trim(status_entrega)) in ('CANCELADO', 'CANCELADA')     as cancelada,

    case
        when upper(trim(status_entrega)) = 'ENTREGUE' and data_entrega is not null
            then data_entrega - (cast(data_emissao as date) + cast(prazo_dias as integer))
    end as dias_atraso_entrega,

    case
        when upper(trim(status_entrega)) = 'ENTREGUE' and data_entrega is not null
            then data_entrega <= (cast(data_emissao as date) + cast(prazo_dias as integer))
    end as entregue_no_prazo,

    case
        when upper(trim(status_entrega)) = 'ENTREGUE' and data_entrega is not null
            then greatest(data_entrega - (cast(data_emissao as date) + cast(prazo_dias as integer)), 0)
    end as dias_atraso_unico,

    date_trunc('month', data_emissao)::date as competencia

from {{ source('raw', 'notas_fiscais_transporte') }}
where nota_id is not null

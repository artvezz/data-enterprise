{% macro auditar_linha(model_name, chave, campo, condicao) %}
    select
        '{{ model_name }}'  as modelo,
        '{{ chave }}'       as chave_primaria,
        '{{ campo }}'       as campo_com_problema,
        cast(current_timestamp as timestamp) as detectado_em
    from {{ this }}
    where {{ condicao }}
{% endmacro %}


{% macro nao_negativo(modelo, coluna) %}
    {{ config(severity='warn') }}
    select * from {{ modelo }} where {{ coluna }} < 0
{% endmacro %}


{% macro percentual_valido(modelo, coluna) %}
    {{ config(severity='error') }}
    select * from {{ modelo }} where {{ coluna }} is not null and ({{ coluna }} < 0 or {{ coluna }} > 1)
{% endmacro %}


{% macro garantir_acesso(schema_destino, role_destino) %}
    do $$
    begin
        execute format('grant usage on schema %I to %I', '{{ schema_destino }}', '{{ role_destino }}');
        execute format('grant select on all tables in schema %I to %I', '{{ schema_destino }}', '{{ role_destino }}');
        execute format('alter default privileges in schema %I grant select on tables to %I', '{{ schema_destino }}', '{{ role_destino }}');
    end
    $$;
{% endmacro %}
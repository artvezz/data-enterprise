{% macro generate_schema_name(custom_schema_name, node) -%}
    {#-
      Sem prefixo do target: queremos exatamente `staging`, `mart_vendas`,
      `qualidade`... igual ao DDL que ja existe no Supabase.
    -#}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}


{% macro garantir_schema(schema_nome) %}
    {#- cria o schema se ainda nao existir (supabase nao tem IF NOT EXISTS via dbt) -#}
    {% set ddl %}
        create schema if not exists {{ schema_nome }}
    {% endset %}
    {% do run_query(ddl) %}
{% endmacro %}


{% macro decimal18(coluna) %}
    cast({{ coluna }} as numeric(18, 2))
{% endmacro %}

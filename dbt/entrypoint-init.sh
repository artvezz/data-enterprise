#!/bin/sh
# Bootstrap do warehouse (roda uma vez no boot, via dbt-init).
# build (marts + testes) -> snapshot (SCD2) -> docs
set -e

DBT_DIR=/opt/dbt

echo "==> dbt deps"
dbt deps --profiles-dir "$DBT_DIR"

echo "==> dbt build (inclui snapshots SCD2)"
dbt build --profiles-dir "$DBT_DIR" --fail-fast

echo "==> dbt docs generate"
dbt docs generate --profiles-dir "$DBT_DIR"

echo "==> bootstrap completo"
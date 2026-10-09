# Data Enterprise

Projeto didático de engenharia de dados com **dados sintéticos** cobrindo 7 domínios de
negócio: Financeiro, BI, RH, Vendas, Comercial, Marketing e Logística.

**Stack:** Postgres (Supabase) · dbt · Airflow · Docker · Metabase

---

## 1. Visão geral

```
dados sintéticos (Python)
        │
        ▼
   raw.*          ← 22 tabelas brutas  (schema staging/landing)
        │
        ▼  dbt (22 modelos staging → views)
   staging.*      ← tipagem, normalização, deduplicação, flags de negócio
        │
        ▼  dbt (33 modelos mart → tabelas)
   mart_*.*       ← 7 schemas separados por time
        │
        ▼
   Metabase / API / consumo por time (roles app_*)
```

| Camada | Schema | Objeto | Qtd |
|---|---|---|---|
| Landing | `raw` | tabelas | 22 |
| Staging | `staging` | views | 22 |
| Marts | `mart_vendas`, `mart_financeiro`, `mart_rh`, `mart_comercial`, `mart_marketing`, `mart_logistica`, `mart_bi` | tabelas | 33 |
| Qualidade | `qualidade` | tabelas de falha (`store_failures`) | — |

**Estado atual:** `dbt run` 55/55 · `dbt test` 88/88 · `dbt docs generate` OK ·
`dbt snapshot` 2 SCD2 (`snapshots.*`) · incrementais (`fatos_pedidos`, `aging_contas_receber`) ·
Metabase 3000 com 7 dashboards (18 cards) lendo o Supabase via `metabase_ro`.

---

## 2. Subir o ambiente

```bash
cp .env.example .env      # preencher DBT_SUPABASE_*

docker compose up -d      # postgres, airflow, metabase, adminer
```

| Serviço | Porta | URL |
|---|---|---|
| Metabase | 3000 | http://localhost:3000 |
| Adminer | 8081 | http://localhost:8081 |
| Airflow | 8080 | http://localhost:8080 |
| Postgres local | 5432 | `dw_admin` / `dw_admin_local` |

---

## 3. dbt

O dbt roda **em container** porque o ambiente local bloqueia DLLs nativas
(AppLocker/WDAC bloqueia `psycopg2`/`psycopg`, impostos pelo `dbt-postgres`).

```bash
# conexão + configuração
docker compose run --rm dbt debug

# pipeline completo
docker compose run --rm dbt seed      # não usado no Supabase (dados já carregados)
docker compose run --rm dbt run       # 55 models
docker compose run --rm dbt test      # 88 tests
docker compose run --rm dbt build     # run + test
docker compose run --rm dbt docs generate && docker compose run --rm dbt docs serve

# comandos úteis
docker compose run --rm dbt ls --resource-type model
docker compose run --rm dbt ls --resource-type test --selector tag:rh
docker compose run --rm dbt run --select marts.vendas+
docker compose run --rm dbt run --select 1+ --exclude 1+2+
```

> A senha vem de `DBT_SUPABASE_PASSWORD` no `.env` (via `env_file` do compose).
> Nunca commitar credenciais — `.env` já está no `.gitignore`.

### Conexão com o Supabase

Host `aws-0-us-west-2.pooler.supabase.com`, **porta 6543** (transaction pooler —
a 5432 falha com *password auth failed*), `sslmode=require`.

### Estrutura

```
dbt/
├── dbt_project.yml        # name: data_enterprise, schemas por domínio
├── profiles.yml           # target supabase (env vars)
├── Dockerfile             # imagem data-enterprise-dbt (python 3.11 + dbt 1.8.4)
├── macros/
│   ├── schema.sql         # generate_schema_name SEM prefixo do target
│   └── qualidade.sql      # auditoria / percentual / garantir_acesso
├── snapshots/
│   ├── dim_cliente.sql    # SCD2 -> snapshots.dim_cliente_snapshot
│   └── dim_produto.sql    # SCD2 -> snapshots.dim_produto_snapshot
└── models/
    ├── staging/
    │   ├── _sources.yml   # 22 sources + testes de unicidade/not_null
    │   ├── schema.yml     # descrições e testes
    │   └── {comum,vendas,financeiro,rh,comercial,marketing,logistica}/  # 22 views
    └── marts/
        ├── schema.yml     # descrições e testes
        └── {vendas,financeiro,rh,comercial,marketing,logistica,bi}/      # 33 tabelas
```

### Marts por time

| Schema | Models | Conteúdo |
|---|---|---|
| `mart_vendas` | 5 | `fatos_pedidos`, `vendas_mensais`, `vendas_por_categoria`, `vendas_por_cliente`, `atingimento_metas` |
| `mart_financeiro` | 4 | `aging_contas_receber`, `saldo_contas_receber`, `contas_pagar_aging`, `orcamento_vs_realizado` |
| `mart_rh` | 6 | `headcount`, `headcount_por_area`, `headcount_por_uf`, `custo_rh_mensal`, `horas_trabalhadas_mensal`, `ferias_mensal` |
| `mart_comercial` | 5 | `pipeline_por_etapa`, `pipeline_por_vendedor`, `conversao_mensal`, `win_rate_por_regiao`, `atividades_mensais` |
| `mart_marketing` | 4 | `campanhas_por_canal`, `campanhas_mensais`, `trafego_mensal`, `trafego_por_canal` |
| `mart_logistica` | 5 | `entregas_mensais`, `entregas_por_transportadora`, `entregas_por_regiao`, `estoque_abaixo_minimo`, `estoque_valor_por_categoria` |
| `mart_bi` | 4 | `receita_por_mes`, `receita_por_segmento`, `receita_por_canal`, `receita_por_uf` |

### SCD2 — snapshots

`dbt snapshot` mantém histórico de mudanças (Type 2) sobre os cadastros:

| Snapshot | Estratégia | Vigência |
|---|---|---|
| `snapshots.dim_cliente_snapshot` | `check` em (razao_social, segmento, uf, cidade, canal, status_cliente) | `dbt_valid_from` / `dbt_valid_to` |
| `snapshots.dim_produto_snapshot` | `check` em (descricao, categoria, preco_lista, ativo) | `dbt_valid_from` / `dbt_valid_to` |

```bash
docker compose run --rm dbt snapshot          # roda sozinho
```
O **`dbt build` já inclui os snapshots** (junto dos models e testes); o
`snapshot` avulso serve para rodadas extras fora da DAG.
`hard_deletes='invalidate'` mantém registros deletados
com `dbt_valid_to` preenchido em vez de removê-los.

### Materialização incremental

| Modelo | Estratégia | Comportamento |
|---|---|---|
| `mart_vendas.fatos_pedidos` | `incremental + merge` (unique `pedido_id`) | reprocessa o mês corrente + janela de 6 meses; mudanças viram update, não duplicam |
| `mart_financeiro.aging_contas_receber` | `incremental + merge` (unique `data_ref` + `faixa_aging`) | snapshot diário da carteira; rodadas no mesmo dia não duplicam |

**Atenção ao ler `aging_contas_receber`:** agora há um `data_ref` por dia —
use `where data_ref = (select max(data_ref) from …)` para ver a carteira corrente
(o card do Metabase "Carteira em aberto" já faz isso).

---

## 4. Acesso restrito por time

`sql/13_roles_por_time.sql` cria `app_vendas`, `app_financeiro`, `app_rh`,
`app_comercial`, `app_marketing`, `app_logistica`, `app_bi` — cada uma enxerga
**apenas** o seu schema `mart_*`. `raw` e `staging` ficam reservados à engenharia.

```sql
SET ROLE app_vendas;
SELECT * FROM mart_financeiro.aging_contas_receber;  -- permission denied
SELECT * FROM mart_vendas.vendas_mensais;            -- ok
RESET ROLE;
```

---

## 5. Orquestração

O Airflow roda uma imagem própria (`docker/airflow/Dockerfile` = `apache/airflow` +
`dbt-core` + `git`), então a DAG executa o dbt **dentro** do container do scheduler —
sem Docker socket e sem CLI externa.

DAG `dbt_warehouse` (`docker/airflow/dags/dbt_warehouse.py`), diária às 04:00 (BRT):

```
inicio → dbt_debug → dbt_build (--fail-fast, inclui snapshots SCD2) → dbt_docs → fim
```

```bash
# acompanhar
docker compose exec airflow-scheduler airflow dags list-runs -d dbt_warehouse -o plain
docker compose exec airflow-scheduler airflow tasks states-for-dag-run dbt_warehouse <run_id>

# forçar execução
docker compose exec airflow-scheduler airflow dags trigger dbt_warehouse
```

Detalhes de implementação:

- As opções globais do dbt 1.8 vêm **depois** do subcomando (`dbt build --profiles-dir …`).
- O `BashOperator` roda num diretório temporário → a task faz `cd /opt/dbt`.
- `DBT_LOG_PATH`/`DBT_TARGET_PATH` apontam para `/tmp` porque o bind mount
  `./dbt` é root e o Airflow roda como UID 50000.

### Alertas de falha

Toda task tem `on_failure_callback`:
- grava um relatório markdown em `data/alerts/<run_id>_<task>.md`
  (bind mount `./data`, fora do container);
- e, se `AIRFLOW_ALERT_WEBHOOK_URL` estiver definida no `.env`, faz um POST
  no webhook (ex.: Slack) com DAG, run, task e o erro. Sem dependência extra.

| Métrica | Valor |
|---|---|
| `docker compose up -d` | postgres healthy → `dbt-init` (`build` + `docs`, ~3 min) → airflow |
| `dbt-init` (boot) | 145/145 (55 models + 2 snapshots + 88 tests) |
| DAG run | `dbt_debug` + `dbt_build` + `dbt_docs` |

---

## 6. Metabase (BI)

O Metabase (**v0.49.6**, porta 3000) lê o Supabase com a role exclusiva `metabase_ro`
(somente SELECT nos `mart_*` — não enxerga `raw`/`staging`).

### Conexão e permissões

```bash
# cria a role metabase_ro (se faltar) e garante SELECT nos marts + default privileges
.\scripts\exec_sql.ps1 sql\14_metabase_ro.sql
```

O Metabase conecta via pooler Supabase com o usuário `metabase_ro.<project-ref>`
(**o sufixo `<role>.<ref>` é obrigatório** no pooler para roles não-admin).

> Rodar `sql/14_metabase_ro.sql` de novo **após cada `dbt run`**: os
> `ALTER DEFAULT PRIVILEGES` cobrem as tabelas novas automaticamente.

### Setup (uma vez)

```bash
# 1) cria admin (credenciais no .env) + cadastra o banco Supabase e sincroniza schema
.\scripts\metabase_bootstrap.ps1          # salva a sessão em scripts/.metabase_session.json

# 2) cria a árvore Data Enterprise: 7 collections + 18 cards + 7 dashboards (um por time)
.\scripts\metabase_dashboards.ps1         # idempotente — pode rodar de novo
```

| Domínio | Dashboard | Cards |
|---|---|---|
| BI | Dashboard - BI | receita por mês/segmento/UF/canal |
| Vendas | Dashboard - Vendas | evolução, metas, categoria, top clientes |
| Financeiro | Dashboard - Financeiro | aging, orçado vs realizado |
| RH | Dashboard - RH | custo, headcount por área |
| Comercial | Dashboard - Comercial | funil, win rate |
| Marketing | Dashboard - Marketing | ROI, tráfego mensal |
| Logística | Dashboard - Logística | OTIF, estoque abaixo do mínimo |

**Detalhe de API:** no Metabase 0.49.x o `POST /api/dashboard/{id}/cards` não existe
(404); o anexo de cards é feito por `PUT /api/dashboard/{id}/cards` com o array de
dashcards `{id, card_id, row, col, size_x, size_y}` (substituição completa por
dashboard, por isso o script agrupa os cards antes de chamar).

Acesso: `http://localhost:3000` → admin do `.env` (`METABASE_ADMIN_EMAIL` /
`METABASE_ADMIN_PASSWORD`).

---

## 7. Dados

Gerados por `scripts/gerar_dados.py` (pandas + numpy, seed fixa):

```bash
.venv\Scripts\python scripts\gerar_dados.py   # regenera data/*.csv
```

Período: **abr/2025 → set/2026** (18 competências).

### Camada manual legada

`sql/01..12_*.sql` é a versão pré-dbt do pipeline (staging + marts escritos à mão),
mantida como referência. **O pipeline canônico é o dbt** — não execute os dois
sobre o mesmo banco a não ser que queira comparar resultados.

---

## 8. Qualidade de dados

- **88 testes dbt**: unicidade/not_null de chaves, relações (`relationships`),
  valores aceitáveis e métricas de negócio (ex.: `custo_rh_mensal.dados_consistentes`).
- `store_failures: true` → falhas gravadas no schema `qualidade` para auditoria.
- `notebooks/eda_negocio.py` — EDA executável com achados priorizados.

Achado conhecido e tratado: o gerador produzia `custos_rh` com **1** competência e
`custo_total = 0`; corrigido para 18 competências e soma consistente
(folha + encargos + benefícios), com teste de regressão no mart.

---

## 9. Segurança

- Credenciais apenas em `.env` (gitignorado), injetadas por `env_file`/`env_var`.
- `raw` e `staging` sem grants para roles de negócio e para `anon`/`authenticated`.
- Colunas sensíveis (`salario_bruto`, `nome`) existem só em `staging`, nunca nos marts.

---

## 10. Roadmap

- [x] Pipeline dbt completo (55 models, 88 testes, docs + lineage).
- [x] Orquestração diária do dbt no Airflow (DAG `dbt_warehouse`).
- [x] Acesso restrito por time (`app_*` × `mart_*`) validado no Supabase.
- [x] Metabase conectado ao Supabase com a role `metabase_ro` (somente marts).
- [x] 7 dashboards por time no Metabase (18 cards, SQL nativo sobre `mart_*`).
- [x] Snapshots dbt (`dim_cliente`, `dim_produto`) para SCD2.
- [x] Materializações incremental nos fatos (`fatos_pedidos`, `aging_contas_receber`).
- [x] Alerts de falha de teste (webhook + relatório em `data/alerts`).

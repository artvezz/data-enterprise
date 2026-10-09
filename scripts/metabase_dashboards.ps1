<#
.SYNOPSIS
  Cria dashboards do Metabase por dominio de negocio (BI, Vendas, Financeiro,
  RH, Comercial, Marketing, Logistica) usando SQL nativo sobre os mart_*.

.DESCRIPTION
  Idempotente: reutiliza collections, cards e dashcards existentes.
  Nesta versao do Metabase (0.49.x) o endpoint de adicionar card e
  `PUT /api/dashboard/:id/cards` (upsert de dashcards por id + card_id).
  Requer scripts\.metabase_session.json (gerado pelo metabase_bootstrap.ps1).

.EXAMPLE
  .\scripts\metabase_dashboards.ps1
#>
[CmdletBinding()]
param(
    [string]$SessionFile
)

$ErrorActionPreference = 'Stop'

if (-not $SessionFile) { $SessionFile = Join-Path $PSScriptRoot '.metabase_session.json' }
if (-not (Test-Path -LiteralPath $SessionFile)) {
    throw "Sessao nao encontrada. Rode antes: .\scripts\metabase_bootstrap.ps1"
}
$state = Get-Content -LiteralPath $SessionFile -Raw | ConvertFrom-Json
$Url    = $state.url
$dbId   = $state.database_id
$headers = @{ 'X-Metabase-Session' = $state.session }

function Invoke-Mb($Method, $Path, $Body = $null) {
    $params = @{ Method = $Method; Uri = "$Url$Path"; Headers = $headers; TimeoutSec = 180 }
    if ($null -ne $Body) {
        $params.Body = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Depth 8 }
        $params.ContentType = 'application/json'
    }
    Invoke-RestMethod @params
}

# ------------------------------------------------------------- colecoes
function Get-Or-Create-Collection($ParentId, $Name) {
    $items = Invoke-Mb GET "/api/collection/$ParentId/items?models=collection&limit=100"
    $found = $items.data | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if ($found) { return $found.id }
    $payload = @{ name = $Name }
    if ($ParentId -ne 'root' -and $ParentId) { $payload.parent_id = $ParentId }
    $c = Invoke-Mb POST "/api/collection" $payload
    return $c.id
}

function Get-Or-Create-Dashboard($ParentId, $Name) {
    $items = Invoke-Mb GET "/api/collection/$ParentId/items?models=dashboard&limit=100"
    $found = $items.data | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if ($found) { return $found.id }
    $d = Invoke-Mb POST "/api/dashboard" @{ name = $Name; collection_id = $ParentId }
    return $d.id
}

function Get-Or-Create-Card($CollectionId, $Name, $Sql, $Display, $VizCol, $VizMetric) {
    $items = Invoke-Mb GET "/api/collection/$CollectionId/items?models=card&limit=100"
    $existing = $items.data | Where-Object { $_.name -eq $Name } | Select-Object -First 1
    if ($existing) { return $existing.id }

    $viz = @{}
    if ($Display -in @('line', 'bar')) {
        $viz['graph.dimensions'] = @($VizCol)
        $viz['graph.metrics']    = @($VizMetric)
    } elseif ($Display -eq 'pie') {
        $viz['pie.dimension'] = $VizCol
        $viz['pie.metric']    = $VizMetric
    }

    $payload = @{
        name                   = $Name
        display                = $Display
        collection_id          = $CollectionId
        visualization_settings = $viz
        dataset_query          = @{
            database   = $dbId
            type       = 'native'
            native     = @{ query = $Sql; 'template-tags' = @{} }
            parameters = @()
        }
    }
    return (Invoke-Mb POST "/api/card" $payload).id
}

# ------------------------------------------------------------- catalogo de cards
$cards = @(
    # ---------------- BI (visao geral) ----------------
    @{ t = 'BI';  n = 'Receita por mes';                 s = "select competencia, receita_liquida from mart_bi.receita_por_mes order by competencia"; d = 'line'; c = 'competencia'; m = 'receita_liquida'; x = 12; y = 7 },
    @{ t = 'BI';  n = 'Receita por segmento';            s = "select segmento, receita, receita_por_cliente from mart_bi.receita_por_segmento order by receita desc"; d = 'bar'; c = 'segmento'; m = 'receita'; x = 8; y = 7 },
    @{ t = 'BI';  n = 'Receita por UF';                  s = "select uf, regiao, receita, clientes from mart_bi.receita_por_uf order by receita desc"; d = 'bar'; c = 'uf'; m = 'receita'; x = 8; y = 7 },
    @{ t = 'BI';  n = 'Receita por canal';               s = "select canal, receita from mart_bi.receita_por_canal order by receita desc"; d = 'pie'; c = 'canal'; m = 'receita'; x = 8; y = 7 },

    # ---------------- Vendas ----------------
    @{ t = 'Vendas'; n = 'Evolucao de vendas';           s = "select competencia, receita_liquida, pedidos from mart_vendas.vendas_mensais order by competencia"; d = 'line'; c = 'competencia'; m = 'receita_liquida'; x = 12; y = 7 },
    @{ t = 'Vendas'; n = 'Top vendedores (realizado x meta)'; s = "select vendedor, sum(meta_valor) as meta_valor, sum(realizado) as realizado from mart_vendas.atingimento_metas group by 1 order by 2 desc limit 10"; d = 'bar'; c = 'vendedor'; m = 'realizado'; x = 8; y = 7 },
    @{ t = 'Vendas'; n = 'Vendas por categoria';         s = "select categoria, pedidos, receita, ticket_medio from mart_vendas.vendas_por_categoria order by receita desc"; d = 'bar'; c = 'categoria'; m = 'receita'; x = 8; y = 7 },
    @{ t = 'Vendas'; n = 'Top 10 clientes';               s = "select razao_social, segmento, uf, canal, pedidos, receita, ticket_medio from mart_vendas.vendas_por_cliente order by receita desc limit 10"; d = 'table'; x = 12; y = 6 },

    # ---------------- Financeiro ----------------
    @{ t = 'Financeiro'; n = 'Carteira em aberto (aging)'; s = "select faixa_aging, titulos, valor_total, pct_carteira from mart_financeiro.aging_contas_receber order by valor_total desc"; d = 'bar'; c = 'faixa_aging'; m = 'valor_total'; x = 10; y = 7 },
    @{ t = 'Financeiro'; n = 'Orcado vs realizado';       s = "select competencia, conta_contabil, tipo, centro_custo, valor_orcado, valor_realizado, coalesce(desvio_pct,0) as desvio_pct from mart_financeiro.orcamento_vs_realizado where desvio_pct is not null order by desvio_pct desc limit 25"; d = 'table'; x = 12; y = 8 },

    # ---------------- RH ----------------
    @{ t = 'RH'; n = 'Custo RH mensal';                    s = "select competencia, folha_bruta, encargos, beneficios, custo_total from mart_rh.custo_rh_mensal where dados_consistentes order by competencia"; d = 'line'; c = 'competencia'; m = 'custo_total'; x = 12; y = 7 },
    @{ t = 'RH'; n = 'Headcount por area';                 s = "select area, ativos, inativos, total, salario_medio_area from mart_rh.headcount_por_area order by total desc"; d = 'bar'; c = 'area'; m = 'total'; x = 8; y = 7 },

    # ---------------- Comercial ----------------
    @{ t = 'Comercial'; n = 'Funil do pipeline';           s = "select etapa, oportunidades, valor_total, valor_ponderado, probabilidade_media from mart_comercial.pipeline_por_etapa order by valor_total desc"; d = 'bar'; c = 'etapa'; m = 'valor_total'; x = 10; y = 7 },
    @{ t = 'Comercial'; n = 'Win rate por vendedor (top 10)'; s = "select vendedor, regiao, oportunidades, valor_ganho, round(win_rate*100,1) as win_rate_pct from mart_comercial.pipeline_por_vendedor order by win_rate desc limit 10"; d = 'bar'; c = 'vendedor'; m = 'win_rate_pct'; x = 8; y = 7 },

    # ---------------- Marketing ----------------
    @{ t = 'Marketing'; n = 'ROI por canal';               s = "select canal, investimento_total, receita_atribuida, roi, custo_por_lead from mart_marketing.campanhas_por_canal order by roi desc"; d = 'bar'; c = 'canal'; m = 'roi'; x = 10; y = 7 },
    @{ t = 'Marketing'; n = 'Trafego mensal x custo';      s = "select competencia, sessoes, pct_sessoes_pagas, investimento_estimado, custo_lead_medio from mart_marketing.trafego_mensal order by competencia"; d = 'table'; x = 12; y = 6 },

    # ---------------- Logistica ----------------
    @{ t = 'Logistica'; n = 'OTIF e atraso medio';        s = "select competencia, entregues, no_prazo, otif, atraso_medio_dias from mart_logistica.entregas_mensais order by competencia"; d = 'line'; c = 'competencia'; m = 'otif'; x = 10; y = 7 },
    @{ t = 'Logistica'; n = 'SKUs abaixo do minimo (top 10)'; s = "select produto, categoria, quantidade_estoque, estoque_minimo, falta_para_minimo, valor_estoque from mart_logistica.estoque_abaixo_minimo order by falta_para_minimo desc limit 10"; d = 'table'; x = 12; y = 7 }
)

# ------------------------------------------------------------- colecoes por time
# cria a pasta raiz "Data Enterprise" no topo (sem parent_id)
$root = Get-Or-Create-Collection 'root' "Data Enterprise"
$collections = @{}
$cards | ForEach-Object { $collections[$_.t] = Get-Or-Create-Collection $root $_.t }
$collections.GetEnumerator() | ForEach-Object {
    Write-Host ">> collection '$($_.Key)' -> id $($_.Value)" -ForegroundColor Cyan
}

# ------------------------------------------------------------- agrupa por dashboard
$byDash = @{}
foreach ($c in $cards) {
    if (-not $byDash.ContainsKey($c.t)) { $byDash[$c.t] = @() }
    $byDash[$c.t] += $c
}

# id de dashcard novo: alto para nao colidir com os que o banco ja gerou
$dashcardSeq = 500000

foreach ($t in ($byDash.Keys | Sort-Object)) {
    $dashId = Get-Or-Create-Dashboard $root "Dashboard - $t"

    # garante todos os cards do dominio (reutiliza se ja existir)
    $refs = @()
    foreach ($c in $byDash[$t]) {
        $cardId = Get-Or-Create-Card $collections[$t] $c.n $c.s $c.d $c.c $c.m
        $refs += @{ card = $c; cardId = $cardId }
        Write-Host ">> card: $($c.n) (id=$cardId)" -ForegroundColor Green
    }

    # dashcards atuais: mapeia card_id -> dashcard_id (para nao duplicar)
    $dash = Invoke-Mb GET "/api/dashboard/$dashId"
    $existing = @{}
    foreach ($dc in $dash.dashcards) {
        if ($dc.card_id) { $existing["$($dc.card_id)"] = $dc.id }
    }

    $payloadCards = @()
    $row = 0
    foreach ($ref in $refs) {
        $c = $ref.card
        if ($existing.ContainsKey("$($ref.cardId)")) {
            $dashcardId = $existing["$($ref.cardId)"]
        } else {
            $dashcardId = $dashcardSeq++
        }
        $payloadCards += @{
            id     = $dashcardId
            card_id = $ref.cardId
            row     = $row
            col     = 0
            size_x  = [int]$c.x
            size_y  = [int]$c.y
        }
        $row += [int]$c.y + 1
    }

    Invoke-Mb PUT "/api/dashboard/$dashId/cards" @{ cards = $payloadCards } | Out-Null
    Write-Host ">> dashboard '$t' atualizado ($($payloadCards.Count) cards)" -ForegroundColor DarkCyan
}

# ------------------------------------------------------------- resumo
$dashes = Invoke-Mb GET "/api/collection/$root/items?models=dashboard"
Write-Host ""
Write-Host ">> dashboards em 'Data Enterprise' (id=$root):" -ForegroundColor Green
$dashes.data | Sort-Object name | ForEach-Object {
    $d = Invoke-Mb GET "/api/dashboard/$($_.id)"
    Write-Host "   - $($_.name)  ($($d.dashcards.Count) cards)"
}
Write-Host ""
Write-Host "Acesse: $Url/dash  (login: .env METABASE_ADMIN_EMAIL / METABASE_ADMIN_PASSWORD)"
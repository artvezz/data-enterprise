<#
.SYNOPSIS
  Configura inicial do Metabase: admin + conexao ao Supabase com a role
  metabase_ro (somente leitura nos mart_*), e sincronizacao de schema.

.DESCRIPTION
  Idempotente: se o Metabase ja tiver usuario, apenas revalida a conexao
  e dispara o sync. Le credenciais do .env.

.EXAMPLE
  .\scripts\metabase_bootstrap.ps1
#>
[CmdletBinding()]
param(
    [string]$Url = "http://localhost:3000"
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# ------------------------------------------------------------- carrega .env
$envPath = Join-Path $root '.env'
if (-not (Test-Path -LiteralPath $envPath)) {
    throw ".env nao encontrado em $envPath - copie .env.example e preencha."
}
Get-Content -LiteralPath $envPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith('#') -and $line.Contains('=')) {
        $i = $line.IndexOf('=')
        Set-Item -Path "env:$($line.Substring(0, $i).Trim())" -Value $line.Substring($i + 1).Trim()
    }
}

$host_  = $env:DBT_SUPABASE_HOST
$port   = if ($env:DBT_SUPABASE_PORT) { $env:DBT_SUPABASE_PORT } else { '6543' }
# o pooler do Supabase resolve o tenant pelo sufixo "<role>.<project-ref>";
# roles nao-padrao precisam do mesmo sufixo no nome de usuario
$ref    = ($env:DBT_SUPABASE_USER -split '\.')[-1]
$dbUser = "metabase_ro.$ref"
$dbPass = $env:METABASE_DB_PASSWORD
$admin  = $env:METABASE_ADMIN_EMAIL
$adminPw= $env:METABASE_ADMIN_PASSWORD

foreach ($pair in @(@('DBT_SUPABASE_HOST', $host_), @('METABASE_DB_PASSWORD', $dbPass),
                    @('METABASE_ADMIN_EMAIL', $admin), @('METABASE_ADMIN_PASSWORD', $adminPw))) {
    if (-not $pair[1]) { throw "Variavel $($pair[0]) ausente no .env" }
}

$dbDetails = @{
    host              = $host_
    port              = [int]$port
    user              = $dbUser
    password          = $dbPass
    dbname            = 'postgres'
    ssl               = $true
    'advanced-options'= 'sslmode=require'
}

# ------------------------------------------------------------- aguarda boot
Write-Host ">> aguardando Metabase em $Url" -ForegroundColor Cyan
$ok = $false
for ($i = 0; $i -lt 60; $i++) {
    try {
        $p = Invoke-RestMethod -Uri "$Url/api/session/properties" -TimeoutSec 5
        $ok = $true; break
    } catch { Start-Sleep -Seconds 5 }
}
if (-not $ok) { throw "Metabase nao respondeu em $Url" }

$session = $null

if (-not $p.'has-user-setup') {
    if (-not $p.'setup-token') { throw "Metabase sem usuario e sem setup-token." }

    Write-Host ">> setup inicial (admin + banco)" -ForegroundColor Cyan
    $body = @{
        token   = $p.'setup-token'
        user    = @{
            first_name = 'Data'
            last_name  = 'Eng'
            email      = $admin
            password   = $adminPw
            site_name  = 'Data Enterprise'
        }
        prefs   = @{
            site_name       = 'Data Enterprise'
            site_locale     = 'pt-BR'
            allow_tracking  = $false
        }
        database = @{
            engine  = 'postgres'
            name    = 'Supabase (marts)'
            details = $dbDetails
        }
    } | ConvertTo-Json -Depth 6

    $r = Invoke-RestMethod -Method Post -Uri "$Url/api/setup" -Body $body `
            -ContentType 'application/json' -TimeoutSec 180
    $session = $r.id
    Write-Host ">> setup ok" -ForegroundColor Green
}
else {
    Write-Host ">> Metabase ja configurado, fazendo login" -ForegroundColor Cyan
    $body = @{ username = $admin; password = $adminPw } | ConvertTo-Json
    $r = Invoke-RestMethod -Method Post -Uri "$Url/api/session" -Body $body `
            -ContentType 'application/json' -TimeoutSec 60
    $session = $r.id
}

if (-not $session) { throw "Nao obteve sessao do Metabase." }
$headers = @{ 'X-Metabase-Session' = $session }

# ------------------------------------------------------------- banco
$dbs = Invoke-RestMethod -Uri "$Url/api/database" -Headers $headers
$db  = $dbs.data | Where-Object { $_.engine -eq 'postgres' } | Select-Object -First 1
if (-not $db) {
    Write-Host ">> criando conexao do banco" -ForegroundColor Cyan
    $create = @{ engine = 'postgres'; name = 'Supabase (marts)'; details = $dbDetails } |
              ConvertTo-Json -Depth 6
    $db = Invoke-RestMethod -Method Post -Uri "$Url/api/database" -Body $create `
            -ContentType 'application/json' -Headers $headers -TimeoutSec 180
}
Write-Host ">> banco id=$($db.id) name=$($db.name)" -ForegroundColor Green

# ------------------------------------------------------------- sync de schema
Write-Host ">> sync de schema" -ForegroundColor Cyan
Invoke-RestMethod -Method Post -Uri "$Url/api/database/$($db.id)/sync_schema" `
    -Headers $headers -TimeoutSec 60 | Out-Null

# esconde os schemas que nao sao de mart_* (defesa em profundidade:
# a role metabase_ro ja nao tem grant neles, aqui e so cosmético)
Invoke-RestMethod -Method Post -Uri "$Url/api/database/$($db.id)/rescan_values" `
    -Headers $headers -TimeoutSec 60 | Out-Null

Start-Sleep -Seconds 8
# o sync de schema roda em background; aguarda os schemas aparecerem
Write-Host ">> aguardando indexacao de schemas" -ForegroundColor Cyan
for ($i = 0; $i -lt 30; $i++) {
    $meta = Invoke-RestMethod -Uri "$Url/api/database/$($db.id)" -Headers $headers
    if ($meta.schemas.Count -gt 0) { break }
    Start-Sleep -Seconds 10
}
Write-Host ">> schemas indexados: $($meta.schemas.Count)" -ForegroundColor Green
$meta.schemas | Sort-Object | ForEach-Object { Write-Host "   - $_" }

# ------------------------------------------------------------- estado
$who = Invoke-RestMethod -Uri "$Url/api/database/$($db.id)/metadata" -Headers $headers
Write-Host ">> tabelas visiveis: $($who.tables.Count)" -ForegroundColor Green

# persiste a sessao para os proximos scripts
$state = @{ url = $Url; session = $session; database_id = $db.id } |
         ConvertTo-Json
Set-Content -LiteralPath (Join-Path $root 'scripts\.metabase_session.json') -Value $state
Write-Host ">> sessao salva em scripts\.metabase_session.json" -ForegroundColor Green

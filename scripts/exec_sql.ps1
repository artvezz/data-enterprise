<#
.SYNOPSIS
  Executa um arquivo .sql no Supabase via psql (container postgres:16-alpine).

.DESCRIPTION
  Le as credenciais do .env (nao versionado) e injeta MB_PASS como variavel
  psql, para que nenhum segredo fique em texto dentro dos arquivos .sql.

.EXAMPLE
  .\scripts\exec_sql.ps1 sql\14_metabase_ro.sql

  .\scripts\exec_sql.ps1 sql\13_roles_por_time.sql -EchoAll
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$File,

    [switch]$EchoAll
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

# carrega o .env (sem interpretar # como comentario do shell)
$envPath = Join-Path $root '.env'
if (-not (Test-Path -LiteralPath $envPath)) {
    throw ".env nao encontrado em $envPath - copie .env.example e preencha."
}
Get-Content -LiteralPath $envPath | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith('#') -and $line.Contains('=')) {
        $i = $line.IndexOf('=')
        $k = $line.Substring(0, $i).Trim()
        $v = $line.Substring($i + 1).Trim()
        Set-Item -Path "env:$k" -Value $v
    }
}

$required = 'DBT_SUPABASE_HOST', 'DBT_SUPABASE_USER', 'DBT_SUPABASE_PASSWORD', 'DBT_SUPABASE_DB'
foreach ($k in $required) {
    if (-not (Get-Item -Path "env:$k" -ErrorAction SilentlyContinue)) {
        throw "Variavel $k ausente no .env"
    }
}

$sqlAbs = (Resolve-Path -LiteralPath (Join-Path $root $File)).Path
$mountDir = Split-Path -Parent $sqlAbs
$mountName = Split-Path -Leaf $mountDir

$psqlArgs = @(
    '-h', $env:DBT_SUPABASE_HOST,
    '-p', $(if ($env:DBT_SUPABASE_PORT) { $env:DBT_SUPABASE_PORT } else { '6543' }),
    '-U', $env:DBT_SUPABASE_USER,
    '-d', $env:DBT_SUPABASE_DB,
    '-v', "ON_ERROR_STOP=1",
    '-v', "mb_pass=$($env:METABASE_DB_PASSWORD)"
)
if ($EchoAll) { $psqlArgs += @('-e') }
$psqlArgs += @('-f', "/sql/$mountName/$(Split-Path -Leaf $sqlAbs)")

$env:PGPASSWORD = $env:DBT_SUPABASE_PASSWORD

Write-Host ">> psql -f $File" -ForegroundColor Cyan
& docker run --rm `
    -e PGPASSWORD `
    -v "${mountDir}:/sql/${mountName}:ro" `
    postgres:16-alpine psql @psqlArgs
exit $LASTEXITCODE

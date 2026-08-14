# Compila, sobe o cliente por alguns segundos e relata erros de parsing de
# pacote. Serve para iterar em protocolo sem ter que olhar a tela: se um pacote
# do 15.25 esta sendo lido errado, aparece aqui.
#
# Quando ha falha, imprime tambem os ultimos opcodes antes dela -- que e o que
# diz QUAL pacote quebrou, nao so que quebrou.
#
# Uso (a partir da raiz do repo):
#   tools\test-login.ps1
#   tools\test-login.ps1 -Segundos 40      espera mais tempo logado
#   tools\test-login.ps1 -SemCompilar      pula o build

[CmdletBinding()]
param(
    [int]$Segundos = 22,
    [switch]$SemCompilar
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

if (-not $SemCompilar) {
    & "$root\compile-cmake.ps1" -Config Release 2>&1 |
        Select-String -Pattern 'error C|FAILED|Build OK' | Select-Object -First 5
    if ($LASTEXITCODE -ne 0) { Write-Host 'BUILD FALHOU' -ForegroundColor Red; exit 1 }
}

$exe = Join-Path $root 'NyxosClient.exe'
if (-not (Test-Path $exe)) { Write-Host "executavel nao encontrado: $exe" -ForegroundColor Red; exit 1 }

Stop-Process -Name 'NyxosClient*' -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 400

$log = Join-Path $root 'Nyxos.log'
Remove-Item $log -ErrorAction SilentlyContinue

Write-Host "rodando o cliente por ${Segundos}s..." -ForegroundColor Cyan
Start-Process -FilePath $exe -WorkingDirectory $root
Start-Sleep -Seconds $Segundos
Stop-Process -Name 'NyxosClient*' -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

if (-not (Test-Path $log)) { Write-Host 'nenhum log foi gerado' -ForegroundColor Red; exit 1 }
$linhas = Get-Content $log

$falhas = $linhas | Select-String 'parse message exception'
Write-Host "excecoes de parsing: $($falhas.Count)"

if ($falhas.Count -gt 0) {
    $idx = ($falhas | Select-Object -Last 1).LineNumber
    Write-Host "`n--- opcodes antes da ultima falha ---" -ForegroundColor Yellow
    $linhas[0..($idx - 1)] | Select-String '\[OPC\]' | Select-Object -Last 8 | ForEach-Object { $_.Line }
    Write-Host "`n--- a falha ---" -ForegroundColor Red
    $linhas[$idx - 1]
    exit 1
}

Write-Host 'nenhum erro de parsing' -ForegroundColor Green
# Sem erro nao quer dizer que entrou no jogo: se o cliente nem logou, nao havia
# pacote para quebrar. Por isso confirmamos que chegou ao mundo.
$linhas | Select-String 'now online|GameStart|enter game|processGameStart|SpriteSheetLoader: parsed' |
    ForEach-Object { $_.Line } | Select-Object -Last 3

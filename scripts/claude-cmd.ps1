# claude-cmd.ps1 — Launch Claude Code through the multi-backend proxy
# so commandcode.ai models serve requests when the Claude provider is limited.
#
# Usage:
#   .\scripts\claude-cmd.ps1                                  # interactive claude via proxy (commandcode-first)
#   .\scripts\claude-cmd.ps1 -Model cc/deepseek/deepseek-v4-flash -Prompt "hello"
#   .\scripts\claude-cmd.ps1 -ProxyOnly                       # just start the proxy
#   .\scripts\claude-cmd.ps1 -Status                          # show proxy health
#   .\scripts\claude-cmd.ps1 -Stop                            # stop the proxy
param(
    [string]$Model = "",
    [string]$Prompt = "",
    [string]$Backend = "commandcode,ollama,copilot,thaillm,local,openai",
    [int]$ProxyPort = 4322,
    [switch]$ProxyOnly,
    [switch]$Stop,
    [switch]$Status,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)

$ErrorActionPreference = "Stop"
$RepoRoot  = Split-Path -Parent $PSScriptRoot
$ProxyUrl  = "http://127.0.0.1:$ProxyPort"
$PidFile   = Join-Path $env:TEMP "multi-proxy.pid"

function Load-DotEnv {
    $envFile = Join-Path $RepoRoot ".env"
    if (-not (Test-Path $envFile)) { return }
    foreach ($line in Get-Content $envFile) {
        if ($line -match '^\s*#' -or $line -notmatch '=') { continue }
        $k, $v = $line -split '=', 2
        $k = $k.Trim(); $v = $v.Trim().Trim('"').Trim("'")
        if ($k -and -not [Environment]::GetEnvironmentVariable($k)) {
            Set-Item -Path "env:$k" -Value $v
        }
    }
}

function Get-ProxyHealth {
    try { return Invoke-RestMethod "$ProxyUrl/health" -TimeoutSec 3 } catch { return $null }
}

function Find-Python {
    foreach ($c in @("py", "python3", "python")) {
        try { & $c --version *> $null; if ($LASTEXITCODE -eq 0) { return $c } } catch {}
    }
    throw "Python not found (tried py/python3/python)"
}

function Stop-Proxy {
    if (Test-Path $PidFile) {
        $proxyPid = Get-Content $PidFile
        try { Stop-Process -Id $proxyPid -Force -Confirm:$false; Write-Host "🛑 Proxy stopped (PID $proxyPid)" }
        catch { Write-Host "Proxy PID $proxyPid not running" }
        Remove-Item $PidFile -Force
    } else {
        Write-Host "No PID file at $PidFile"
    }
}

function Start-ProxyIfNeeded {
    $h = Get-ProxyHealth
    if ($h) { Write-Host "[OK] Proxy already running ($($h.current_backend) first)"; return $h }

    $python = Find-Python
    Write-Host "Starting multi-proxy ($python) ..."
    $env:MULTI_BACKEND_ORDER = $Backend
    $env:MULTI_PROXY_PORT = "$ProxyPort"
    $proc = Start-Process $python -ArgumentList "`"$(Join-Path $RepoRoot 'scripts\multi-proxy.py')`"" `
        -WindowStyle Hidden -PassThru -WorkingDirectory $RepoRoot
    $proc.Id | Set-Content $PidFile

    foreach ($i in 1..10) {
        Start-Sleep -Milliseconds 500
        $h = Get-ProxyHealth
        if ($h) { Write-Host "[OK] Proxy up (PID $($proc.Id)) — backends: $($h.available -join ', ')"; return $h }
    }
    throw "Proxy failed to start within 5s — check: $python $RepoRoot\scripts\multi-proxy.py"
}

Load-DotEnv

if ($Stop)   { Stop-Proxy; exit 0 }
if ($Status) {
    $h = Get-ProxyHealth
    if ($h) { $h | ConvertTo-Json -Depth 4 } else { Write-Host "Proxy NOT running on $ProxyUrl" }
    exit 0
}

if (-not $env:COMMANDCODE_API_KEY) {
    Write-Warning "COMMANDCODE_API_KEY not set — commandcode lane will be skipped (fallbacks still work)"
}

$health = Start-ProxyIfNeeded
if ($ProxyOnly) { Write-Host "Proxy ready at $ProxyUrl (order: $($health.backend_order -join ' -> '))"; exit 0 }

# Route Claude Code through the proxy
$env:ANTHROPIC_BASE_URL = $ProxyUrl
$env:ANTHROPIC_API_KEY  = "multi-proxy"
if (-not $Model) { $Model = "cc/" + ($(if ($env:COMMANDCODE_MODEL) { $env:COMMANDCODE_MODEL } else { "deepseek/deepseek-v4-flash" })) }

$claudeArgs = @("--model", $Model)
if ($Prompt) { $claudeArgs += @("--print", $Prompt) }
if ($Rest)   { $claudeArgs += $Rest }

Write-Host "🚀 claude -> $ProxyUrl -> [$Model]  (failover: $($health.backend_order -join ' -> '))"
& claude @claudeArgs
exit $LASTEXITCODE

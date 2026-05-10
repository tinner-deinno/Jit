$bytes = [System.IO.File]::ReadAllBytes($PSCommandPath)
if ($bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
    [System.IO.File]::WriteAllBytes($PSCommandPath,
        ([byte[]](0xEF,0xBB,0xBF)) + $bytes)
    Write-Host "UTF-8 BOM added — please re-run"
    exit 0
}
# scripts/jarvis-life.ps1 — Windows JARVIS: Autonomous Life System
# ════════════════════════════════════════════════════════════════════
# รัน JIT-LIFE ทุก daemon พร้อมกันบน Windows:
#   Proxy (Python), Hermes-Discord (Node), MCP loop, Heartbeat
#   Discord reports ทุก N cycles
#
# Usage:
#   pwsh -File scripts/jarvis-life.ps1 -Action start
#   pwsh -File scripts/jarvis-life.ps1 -Action status
#   pwsh -File scripts/jarvis-life.ps1 -Action stop
#   pwsh -File scripts/jarvis-life.ps1 -Action discord
# ════════════════════════════════════════════════════════════════════

param(
    [string]$Action = "start",
    [int]$CycleSecs = 120,
    [int]$DiscordEvery = 10,
    [int]$SweepEvery = 30
)

$JIT_ROOT = Split-Path $PSScriptRoot -Parent
$ENV_FILE = Join-Path $JIT_ROOT ".env"
$LIFE_STATE = "$env:TEMP\jit-life-state.json"
$LIFE_LOG = "$env:TEMP\jit-life-$(Get-Date -Format yyyyMMdd).log"
$PROXY_PID_FILE = "$env:TEMP\ollama-proxy.pid"
$PROXY_PORT = 4321
$MCP_PORT = 7010
$ORACLE_PORT = 47778

# ─── Load .env ────────────────────────────────────────────────────────
if (Test-Path $ENV_FILE) {
    Get-Content $ENV_FILE | ForEach-Object {
        if ($_ -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $k = $matches[1]; $v = $matches[2].Trim('"').Trim("'")
            if (-not [System.Environment]::GetEnvironmentVariable($k)) {
                [System.Environment]::SetEnvironmentVariable($k, $v, "Process")
            }
        }
    }
}

$OLLAMA_TOKEN = $env:OLLAMA_TOKEN
$DISCORD_TOKEN = $env:DISCORD_TOKEN
$JIT_CHANNEL_ID = $env:JIT_REPORT_CHANNEL_ID
$INNOVA_BOT_PATH = $env:INNOVA_BOT_PATH

# ─── Helpers ─────────────────────────────────────────────────────────
function Log-Life($msg) {
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    $line = "[$ts] LIFE: $msg"
    Write-Host $line
    Add-Content $LIFE_LOG $line -Encoding UTF8
}

function Test-Url($url) {
    try {
        $r = Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        return $r.StatusCode -lt 400
    } catch { return $false }
}

function Get-Status($label, $url) {
    $ok = Test-Url $url
    $icon = if ($ok) { "✅" } else { "❌" }
    "$icon $label"
}

# ─── Multi-Proxy (port 4322, multi-backend) ──────────────────────────
function Start-MultiProxy {
    $alive = Test-Url "http://127.0.0.1:4322/health"
    if ($alive) { return }
    Log-Life "Starting multi-proxy (OpenAI+Copilot+Ollama) on :4322"
    $env:OPENAI_API_KEY   = $env:OPENAI_API_KEY
    $env:COPILOT_TOKEN    = $env:COPILOT_TOKEN
    $env:OLLAMA_TOKEN     = $OLLAMA_TOKEN
    $env:MULTI_PROXY_PORT = "4322"
    Start-Process python3 -ArgumentList @(
        "$JIT_ROOT\scripts\multi-proxy.py"
    ) -WindowStyle Hidden -RedirectStandardOutput "$env:TEMP\multi-proxy.log" 2>$null
    Start-Sleep 2
}

# ─── Ollama Proxy (port 4321, Ollama-only) ──────────────────────────
function Start-OllamaProxy {
    $alive = Test-Url "http://127.0.0.1:$PROXY_PORT/health"
    if ($alive) { return }

    Log-Life "Starting Ollama proxy on :$PROXY_PORT"
    $env:OLLAMA_TOKEN = $OLLAMA_TOKEN
    $env:PROXY_PORT = "$PROXY_PORT"
    $proc = Start-Process python3 -ArgumentList @(
        "$JIT_ROOT\scripts\ollama-proxy.py"
    ) -WindowStyle Hidden -PassThru
    $proc.Id | Set-Content $PROXY_PID_FILE -Encoding UTF8
    Start-Sleep 2
}

function Stop-OllamaProxy {
    if (Test-Path $PROXY_PID_FILE) {
        $pid = [int](Get-Content $PROXY_PID_FILE)
        try { Stop-Process $pid -Force -ErrorAction SilentlyContinue } catch {}
        Remove-Item $PROXY_PID_FILE -Force
        Log-Life "Ollama proxy stopped"
    }
}

# ─── Hermes Discord ───────────────────────────────────────────────────
function Start-HermesDiscord {
    $botJs = Join-Path $JIT_ROOT "hermes-discord\bot.js"
    if (-not (Test-Path $botJs)) { return }
    if (-not $DISCORD_TOKEN) { Log-Life "No DISCORD_TOKEN — skip hermes-discord"; return }

    $running = Get-Process node -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -match "hermes-discord" } |
        Select-Object -First 1
    if ($running) { return }

    Log-Life "Starting hermes-discord (bot.js)"
    $env:DISCORD_TOKEN = $DISCORD_TOKEN
    $env:OLLAMA_TOKEN = $OLLAMA_TOKEN
    $env:JIT_REPORT_CHANNEL_ID = $JIT_CHANNEL_ID
    Start-Process node -ArgumentList @("$botJs") `
        -WorkingDirectory "$JIT_ROOT\hermes-discord" `
        -WindowStyle Hidden -RedirectStandardOutput "$env:TEMP\hermes-discord.log" 2>$null
}

# ─── Discord Reporter ─────────────────────────────────────────────────
function Send-DiscordReport($cycle, $uptime) {
    if (-not ($DISCORD_TOKEN -and $JIT_CHANNEL_ID)) {
        Log-Life "Discord: no token/channel — skip"
        return
    }

    $ollamaStatus = Get-Status "Ollama" "https://ollama.mdes-innova.online/api/tags"
    $proxyStatus  = Get-Status "Proxy"  "http://127.0.0.1:$PROXY_PORT/health"
    $mcpStatus    = Get-Status "MCP"    "http://127.0.0.1:$MCP_PORT/health"
    $oracleStatus = Get-Status "Oracle" "http://127.0.0.1:$ORACLE_PORT/api/health"

    $uptimeFmt = [TimeSpan]::FromSeconds($uptime).ToString("hh\:mm\:ss")
    $msg = "♥ **innova heartbeat** (Windows)\nCycle: $cycle | Uptime: $uptimeFmt\n$ollamaStatus | $proxyStatus | $mcpStatus | $oracleStatus\n$(Get-Date -Format 'HH:mm:ss')"

    $payload = @{
        content = $msg
    } | ConvertTo-Json -Compress

    try {
        Invoke-RestMethod `
            -Uri "https://discord.com/api/v10/channels/$JIT_CHANNEL_ID/messages" `
            -Method POST `
            -Headers @{ Authorization = "Bot $DISCORD_TOKEN"; "Content-Type" = "application/json" } `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) `
            -ErrorAction SilentlyContinue | Out-Null
        Log-Life "Discord report sent (cycle $cycle)"
    } catch {
        Log-Life "Discord report failed: $_"
    }
}

function Send-DiscordAlert($message) {
    if (-not ($DISCORD_TOKEN -and $JIT_CHANNEL_ID)) { return }
    $payload = @{ content = "🚨 **Alert** $message" } | ConvertTo-Json -Compress
    try {
        Invoke-RestMethod `
            -Uri "https://discord.com/api/v10/channels/$JIT_CHANNEL_ID/messages" `
            -Method POST `
            -Headers @{ Authorization = "Bot $DISCORD_TOKEN"; "Content-Type" = "application/json" } `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) `
            -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

# ─── Save state ────────────────────────────────────────────────────────
function Save-LifeState($cycle, $uptime) {
    $data = @{
        status      = "alive"
        cycle       = $cycle
        uptime_secs = $uptime
        timestamp   = (Get-Date -Format "o")
        node        = $env:COMPUTERNAME
        agent       = "innova"
        platform    = "windows"
        services    = @{
            proxy   = (Test-Url "http://127.0.0.1:$PROXY_PORT/health")
            mcp     = (Test-Url "http://127.0.0.1:$MCP_PORT/health")
            oracle  = (Test-Url "http://127.0.0.1:$ORACLE_PORT/api/health")
        }
    }
    $data | ConvertTo-Json -Depth 5 | Set-Content $LIFE_STATE -Encoding UTF8
}

# ─── Status ───────────────────────────────────────────────────────────
function Show-Status {
    Write-Host ""
    Write-Host "🔍 JARVIS-LIFE Status — $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
    Write-Host ("━" * 50)

    # Services
    @(
        @{ Label="Ollama MDES"; Url="https://ollama.mdes-innova.online/api/tags" }
        @{ Label="Ollama Proxy"; Url="http://127.0.0.1:$PROXY_PORT/health" }
        @{ Label="MCP :$MCP_PORT";  Url="http://127.0.0.1:$MCP_PORT/health" }
        @{ Label="Oracle :$ORACLE_PORT";Url="http://127.0.0.1:$ORACLE_PORT/api/health" }
    ) | ForEach-Object {
        $s = Get-Status $_.Label $_.Url
        Write-Host "  $s"
    }

    # Proxy PID
    Write-Host ""
    if (Test-Path $PROXY_PID_FILE) {
        $ppid = Get-Content $PROXY_PID_FILE
        $alive = try { Get-Process -Id $ppid -ErrorAction Stop; $true } catch { $false }
        $icon = if ($alive) {"✅"} else {"❌"}
        Write-Host "  $icon Proxy process (PID $ppid)"
    } else {
        Write-Host "  ❌ Proxy not started"
    }

    # hermes-discord
    $nodeProcs = Get-Process node -ErrorAction SilentlyContinue
    if ($nodeProcs) {
        Write-Host "  ✅ Node.js running ($($nodeProcs.Count) process(es))"
    } else {
        Write-Host "  ❌ hermes-discord not detected"
    }

    # Life state
    if (Test-Path $LIFE_STATE) {
        $d = Get-Content $LIFE_STATE | ConvertFrom-Json
        Write-Host ""
        Write-Host "  Cycle  : $($d.cycle)"
        Write-Host "  Uptime : $($d.uptime_secs)s"
        Write-Host "  Time   : $($d.timestamp)"
    }

    Write-Host ("━" * 50)
}

# ─── Main Loop ────────────────────────────────────────────────────────
function Start-Life {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  🧠 JARVIS-LIFE (Windows) — Autonomous Life System       ║" -ForegroundColor Cyan
    Write-Host "║  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Cycle: ${CycleSecs}s               ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    $cycle = 0
    $startTime = [System.Diagnostics.Stopwatch]::StartNew()

    # Initial announce
    if ($DISCORD_TOKEN -and $JIT_CHANNEL_ID) {
        $msg = "🌅 **innova (จิต) ตื่นขึ้น** (Windows)\nJARVIS-LIFE started: $(Get-Date -Format 'HH:mm:ss')\nNode: $env:COMPUTERNAME | Cycle: ${CycleSecs}s"
        $pl = @{ content = $msg } | ConvertTo-Json -Compress
        try {
            Invoke-RestMethod -Uri "https://discord.com/api/v10/channels/$JIT_CHANNEL_ID/messages" `
                -Method POST -Headers @{ Authorization = "Bot $DISCORD_TOKEN"; "Content-Type" = "application/json" } `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($pl)) -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }

    while ($true) {
        $cycle++
        $uptime = [int]$startTime.Elapsed.TotalSeconds

        Log-Life "⚡ Cycle $cycle | Uptime ${uptime}s"

        # Ensure daemons alive
        try { Start-MultiProxy }    catch { Log-Life "Multi-proxy error: $_" }
        try { Start-OllamaProxy }   catch { Log-Life "Ollama proxy error: $_" }
        try { Start-HermesDiscord } catch { Log-Life "Discord bot error: $_" }

        # Discord report every N cycles
        if ($cycle % $DiscordEvery -eq 0) {
            try { Send-DiscordReport $cycle $uptime } catch { Log-Life "Discord report error: $_" }
        }

        # Save state
        try { Save-LifeState $cycle $uptime } catch {}

        Log-Life "💤 Sleeping ${CycleSecs}s"
        Start-Sleep $CycleSecs
    }
}

function Stop-Life {
    Log-Life "Stopping JARVIS-LIFE..."
    Stop-OllamaProxy

    if ($DISCORD_TOKEN -and $JIT_CHANNEL_ID) {
        $msg = "🌙 **innova (จิต) หลับ** — JARVIS-LIFE stopped $(Get-Date -Format 'HH:mm:ss')"
        $pl = @{ content = $msg } | ConvertTo-Json -Compress
        try {
            Invoke-RestMethod -Uri "https://discord.com/api/v10/channels/$JIT_CHANNEL_ID/messages" `
                -Method POST -Headers @{ Authorization = "Bot $DISCORD_TOKEN"; "Content-Type" = "application/json" } `
                -Body ([System.Text.Encoding]::UTF8.GetBytes($pl)) -ErrorAction SilentlyContinue | Out-Null
        } catch {}
    }
    Log-Life "Done"
}

# ─── Dispatch ─────────────────────────────────────────────────────────
switch ($Action.ToLower()) {
    "start"   { Start-Life }
    "stop"    { Stop-Life }
    "status"  { Show-Status }
    "discord" { Send-DiscordReport 0 0 }
    "proxy"   { Start-OllamaProxy; Log-Life "Proxy started" }
    default {
        Write-Host ""
        Write-Host "scripts/jarvis-life.ps1 — Windows JARVIS Autonomous Life"
        Write-Host ""
        Write-Host "  -Action start    Start life loop (never stops)"
        Write-Host "  -Action stop     Stop all daemons"
        Write-Host "  -Action status   Show status"
        Write-Host "  -Action discord  Send Discord report"
        Write-Host "  -Action proxy    Start Ollama proxy only"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -CycleSecs N     Loop interval (default: 120)"
        Write-Host "  -DiscordEvery N  Discord report every N cycles (default: 10)"
        Write-Host ""
    }
}

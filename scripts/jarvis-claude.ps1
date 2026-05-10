# JARVIS Claude — Windows PowerShell Daemon
# ════════════════════════════════════════════════════════════════════
# รัน Claude Code + MDES Ollama บน Windows แบบ JARVIS autonomous
#
# Features:
#   - Start Python proxy (Anthropic ↔ MDES Ollama bridge)
#   - Model pool: gemma4:26b, gemma4:e4b, qwen2.5-coder:7b, llama3.2
#   - Auto-restart proxy if it dies
#   - Auto-rotate model on token/quota errors
#   - JARVIS loop: keeps working forever
#   - Test 3-4 models with Q&A
#
# Usage:
#   .\scripts\jarvis-claude.ps1 -Action start
#   .\scripts\jarvis-claude.ps1 -Action test
#   .\scripts\jarvis-claude.ps1 -Action proxy
#   .\scripts\jarvis-claude.ps1 -Action jarvis
#   .\scripts\jarvis-claude.ps1 -Action status
#   .\scripts\jarvis-claude.ps1 -Action stop
# ════════════════════════════════════════════════════════════════════

param(
    [Parameter(Position=0)]
    [ValidateSet("start","test","proxy","jarvis","status","stop","help")]
    [string]$Action = "help",

    [string]$Task = "dev",
    [int]$ProxyPort = 4321
)

$ErrorActionPreference = "Continue"

# ─── Config ────────────────────────────────────────────────────────────
$JitRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path) -Parent
$EnvFile = Join-Path $JitRoot ".env"
$ProxyScript = Join-Path $JitRoot "scripts\ollama-proxy.py"
$ProxyPidFile = "$env:TEMP\ollama-proxy.pid"
$ProxyLog = "$env:TEMP\ollama-proxy.log"
$JarvisLog = "$env:TEMP\jarvis-claude.log"
$JarvisState = "$env:TEMP\jarvis-claude-state.json"
$ProxyUrl = "http://127.0.0.1:$ProxyPort"

# Model pool (4 models)
$ModelPool = @(
    "gemma4:26b",
    "gemma4:e4b",
    "qwen2.5-coder:7b",
    "llama3.2:latest"
)
$CurrentModelIdx = 0

# ─── Load .env ─────────────────────────────────────────────────────────
$OllamaBaseUrl = "https://ollama.mdes-innova.online"
$OllamaToken = ""
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match "^\s*([^#][^=]+)=(.+)$") {
            $key = $Matches[1].Trim()
            $val = $Matches[2].Trim().Trim('"').Trim("'")
            switch ($key) {
                "OLLAMA_BASE_URL" { $OllamaBaseUrl = $val }
                "OLLAMA_TOKEN"    { $OllamaToken = $val }
            }
        }
    }
}
# Also check environment variables
if ($env:OLLAMA_TOKEN)    { $OllamaToken = $env:OLLAMA_TOKEN }
if ($env:OLLAMA_BASE_URL) { $OllamaBaseUrl = $env:OLLAMA_BASE_URL }

# ─── Colors ────────────────────────────────────────────────────────────
function Write-OK   { param($m) Write-Host "  ✅ $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "  ⚠️  $m" -ForegroundColor Yellow }
function Write-Err  { param($m) Write-Host "  ❌ $m" -ForegroundColor Red }
function Write-Step { param($m) Write-Host "  → $m" -ForegroundColor Cyan }
function Write-Log  { param($m) 
    $line = "[$(Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')] JARVIS: $m"
    $line | Tee-Object -Append -FilePath $JarvisLog | Write-Host -ForegroundColor DarkGray
}

# ─── Proxy helpers ──────────────────────────────────────────────────────
function Get-ProxyRunning {
    if (Test-Path $ProxyPidFile) {
        $pid = (Get-Content $ProxyPidFile -ErrorAction SilentlyContinue) -as [int]
        if ($pid) {
            return ($null -ne (Get-Process -Id $pid -ErrorAction SilentlyContinue))
        }
    }
    return $false
}

function Get-ProxyHealth {
    try {
        $resp = Invoke-RestMethod -Uri "$ProxyUrl/health" -TimeoutSec 5 -ErrorAction Stop
        return $resp
    } catch { return $null }
}

function Start-OllamaProxy {
    if (Get-ProxyRunning) {
        Write-Warn "Proxy already running (PID $(Get-Content $ProxyPidFile))"
        return $true
    }
    Write-Step "Starting MDES Ollama proxy on port $ProxyPort..."

    # Set env vars for the child process (PS5.1 compatible)
    $env:OLLAMA_BASE_URL = $OllamaBaseUrl
    $env:OLLAMA_TOKEN    = $OllamaToken
    $env:PROXY_PORT      = "$ProxyPort"

    $proc = Start-Process python3 `
        -ArgumentList $ProxyScript `
        -RedirectStandardOutput $ProxyLog `
        -RedirectStandardError "$ProxyLog.err" `
        -PassThru `
        -WindowStyle Hidden

    if ($proc) {
        $proc.Id | Out-File $ProxyPidFile -Encoding ASCII
        Start-Sleep -Seconds 2
        $health = Get-ProxyHealth
        if ($health) {
            Write-OK "Proxy started (PID $($proc.Id)) — model: $($health.current_model)"
            return $true
        }
    }
    Write-Err "Proxy failed to start — check $ProxyLog"
    return $false
}

function Stop-OllamaProxy {
    if (Get-ProxyRunning) {
        $pid = (Get-Content $ProxyPidFile) -as [int]
        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
        Remove-Item $ProxyPidFile -Force -ErrorAction SilentlyContinue
        Write-OK "Proxy stopped (PID $pid)"
    } else {
        Write-Warn "Proxy not running"
    }
}

# ─── Ollama direct ping ──────────────────────────────────────────────────
function Invoke-OllamaPing {
    param([string]$Model = "gemma4:e4b", [string]$Prompt = "ping")
    try {
        $body = @{
            model    = $Model
            messages = @(@{ role="user"; content=$Prompt })
            stream   = $false
            options  = @{ num_predict = 10 }
        } | ConvertTo-Json -Depth 5

        $headers = @{
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer $OllamaToken"
        }

        $resp = Invoke-RestMethod `
            -Uri "$OllamaBaseUrl/api/chat" `
            -Method POST `
            -Body $body `
            -Headers $headers `
            -TimeoutSec 45
        return $resp.message.content
    } catch {
        return $null
    }
}

# ─── ACTION: test ────────────────────────────────────────────────────────
function Invoke-TestModels {
    Write-Host ""
    Write-Host "  🧪 Testing 4 MDES Ollama Models" -ForegroundColor Cyan
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

    $prompts = @{
        "gemma4:26b"       = "ตอบสั้นๆ ภาษาไทย: AI คืออะไร"
        "gemma4:e4b"       = "Reply in 1 word: color of sky"
        "qwen2.5-coder:7b" = "Print hello in Python one-liner"
        "llama3.2:latest"  = "Say MDES online only"
    }

    $passed = 0; $failed = 0

    foreach ($model in $ModelPool) {
        $prompt = if ($prompts.ContainsKey($model)) { $prompts[$model] } else { "ping" }
        Write-Host "  Testing $model..." -NoNewline

        $t0 = [DateTime]::Now
        $resp = Invoke-OllamaPing -Model $model -Prompt $prompt
        $elapsed = ([DateTime]::Now - $t0).TotalSeconds

        if ($resp) {
            $short = $resp.Substring(0, [Math]::Min(60, $resp.Length)).Replace("`n"," ")
            Write-Host " ✓ [$([int]$elapsed)s] `"$short`"" -ForegroundColor Green
            $passed++
        } else {
            Write-Host " ✗ [$([int]$elapsed)s] no response" -ForegroundColor Red
            $failed++
        }
    }

    # Test proxy if running
    if (Get-ProxyRunning) {
        Write-Host ""
        Write-Host "  Testing Anthropic↔Ollama Proxy..." -ForegroundColor Cyan
        try {
            $body = @{
                model      = "claude-3-sonnet"
                max_tokens = 30
                messages   = @(@{ role="user"; content="ตอบ 1 คำ: ระบบนี้ทำงานได้ไหม" })
            } | ConvertTo-Json -Depth 5

            $resp = Invoke-RestMethod `
                -Uri "$ProxyUrl/v1/messages" `
                -Method POST `
                -Body $body `
                -ContentType "application/json" `
                -Headers @{ "x-api-key"="mdes-ollama"; "anthropic-version"="2023-06-01" } `
                -TimeoutSec 90

            $text = $resp.content[0].text
            $model = $resp.model
            Write-OK "Proxy bridge: [$model] `"$($text.Substring(0,[Math]::Min(50,$text.Length)))`""
            $passed++
        } catch {
            Write-Warn "Proxy test failed: $_"
            $failed++
        }
    }

    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "  📊 $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Yellow" })
    Write-Host ""
}

# ─── ACTION: start ──────────────────────────────────────────────────────
function Invoke-StartClaude {
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║  🤖 Claude Code + MDES Ollama               ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # Start proxy
    if (-not (Start-OllamaProxy)) { return }

    # Ping test
    Write-Step "Pinging MDES Ollama (gemma4:e4b)..."
    $pong = Invoke-OllamaPing -Model "gemma4:e4b" -Prompt "reply: ready"
    if ($pong) { Write-OK "Ollama online: `"$pong`"" }
    else        { Write-Warn "Ollama not responding — proxy will rotate models" }

    # Set environment
    $env:ANTHROPIC_BASE_URL = $ProxyUrl
    $env:ANTHROPIC_API_KEY  = "mdes-ollama"

    Write-Host ""
    Write-Host "  🚀 Launching Claude Code" -ForegroundColor Yellow
    Write-Host "     ANTHROPIC_BASE_URL=$ProxyUrl" -ForegroundColor DarkGray
    Write-Host "     claude --dangerously-skip-permissions" -ForegroundColor DarkGray
    Write-Host ""

    if (Get-Command claude -ErrorAction SilentlyContinue) {
        claude --dangerously-skip-permissions
    } else {
        Write-Warn "claude CLI not found"
        Write-Host ""
        Write-Host "  To install:" -ForegroundColor Yellow
        Write-Host "    npm install -g @anthropic-ai/claude-code" -ForegroundColor White
        Write-Host ""
        Write-Host "  Then run manually:" -ForegroundColor Yellow
        Write-Host "    `$env:ANTHROPIC_BASE_URL='$ProxyUrl'" -ForegroundColor White
        Write-Host "    `$env:ANTHROPIC_API_KEY='mdes-ollama'" -ForegroundColor White
        Write-Host "    claude --dangerously-skip-permissions" -ForegroundColor White
        Write-Host ""
    }
}

# ─── ACTION: jarvis — autonomous loop ──────────────────────────────────
function Invoke-JarvisLoop {
    $cycle = 0
    $startTime = [DateTime]::Now

    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║  🤖 JARVIS — Claude Code + MDES Ollama Daemon        ║" -ForegroundColor Cyan
    Write-Host "  ║  Mode: autonomous | Never stops                       ║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    # Start proxy
    if (-not (Start-OllamaProxy)) { return }

    $env:ANTHROPIC_BASE_URL = $ProxyUrl
    $env:ANTHROPIC_API_KEY  = "mdes-ollama"

    Write-Log "JARVIS started. Proxy=$ProxyUrl"
    Write-Log "Model pool: $($ModelPool -join ', ')"

    while ($true) {
        $cycle++
        $uptime = [int]([DateTime]::Now - $startTime).TotalMinutes
        Write-Log "⚡ Cycle $cycle (uptime ${uptime}m) — checking system"

        # 1. Keep proxy alive
        if (-not (Get-ProxyRunning)) {
            Write-Log "🔴 Proxy died — restarting"
            Start-OllamaProxy | Out-Null
        }

        # 2. Check proxy health
        $health = Get-ProxyHealth
        if ($health) {
            Write-Log "✅ Proxy OK: model=$($health.current_model) requests=$($health.requests) rotations=$($health.rotations)"
        } else {
            Write-Log "⚠️ Proxy not responding — restarting"
            Stop-OllamaProxy
            Start-OllamaProxy | Out-Null
            Start-Sleep -Seconds 5
            continue
        }

        # 3. Check at least 1 Ollama model
        $ollamaOk = $false
        foreach ($model in $ModelPool) {
            $resp = Invoke-OllamaPing -Model $model -Prompt "ping"
            if ($resp) {
                Write-Log "✅ Ollama alive: $model → `"$($resp.Substring(0,[Math]::Min(40,$resp.Length)))`""
                $ollamaOk = $true
                break
            }
        }

        if (-not $ollamaOk) {
            Write-Log "⚠️ All Ollama models offline — waiting 60s"
            Start-Sleep -Seconds 60
            continue
        }

        # 4. Save JARVIS state
        $state = @{
            status     = "running"
            cycle      = $cycle
            uptime_min = $uptime
            proxy_url  = $ProxyUrl
            proxy_port = $ProxyPort
            timestamp  = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            models     = $ModelPool
            task_mode  = $Task
        } | ConvertTo-Json -Depth 3
        $state | Out-File $JarvisState -Encoding UTF8

        Write-Log "💤 Cycle $cycle complete — sleeping 120s"
        Start-Sleep -Seconds 120
    }
}

# ─── ACTION: status ────────────────────────────────────────────────────
function Show-Status {
    Write-Host ""
    Write-Host "  🔍 JARVIS / Ollama Bridge Status" -ForegroundColor Cyan
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

    # Proxy
    if (Get-ProxyRunning) {
        $pid = Get-Content $ProxyPidFile
        Write-OK "Proxy running (PID $pid) → $ProxyUrl"
        $h = Get-ProxyHealth
        if ($h) {
            Write-Host "    model     : $($h.current_model)" -ForegroundColor DarkGray
            Write-Host "    requests  : $($h.requests)" -ForegroundColor DarkGray
            Write-Host "    rotations : $($h.rotations)" -ForegroundColor DarkGray
            Write-Host "    uptime    : $($h.uptime_secs)s" -ForegroundColor DarkGray
        }
    } else {
        Write-Warn "Proxy not running"
    }

    # JARVIS state
    if (Test-Path $JarvisState) {
        Write-Host ""
        Write-Step "JARVIS state:"
        Get-Content $JarvisState | Write-Host -ForegroundColor DarkGray
    }

    # Model status
    Write-Host ""
    Write-Step "MDES Ollama models:"
    foreach ($model in $ModelPool) {
        Write-Host "  $model..." -NoNewline
        $resp = Invoke-OllamaPing -Model $model -Prompt "ping"
        if ($resp) { Write-Host " ✓" -ForegroundColor Green }
        else        { Write-Host " ✗" -ForegroundColor Red }
    }

    Write-Host ""
    Write-Host "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
    Write-Host "  Launch commands:" -ForegroundColor Yellow
    Write-Host "    `$env:ANTHROPIC_BASE_URL='$ProxyUrl'" -ForegroundColor White
    Write-Host "    `$env:ANTHROPIC_API_KEY='mdes-ollama'" -ForegroundColor White
    Write-Host "    claude --dangerously-skip-permissions" -ForegroundColor White
    Write-Host ""
}

# ─── Main dispatch ─────────────────────────────────────────────────────
Write-Host ""
Write-Host "  🤖 JARVIS Claude — MDES Ollama Bridge" -ForegroundColor Cyan
Write-Host "     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
Write-Host ""

switch ($Action) {
    "proxy"  { Start-OllamaProxy }
    "stop"   { Stop-OllamaProxy }
    "test"   { Invoke-TestModels }
    "start"  { Invoke-StartClaude }
    "jarvis" { Invoke-JarvisLoop }
    "status" { Show-Status }
    "help"   {
        Write-Host "  Actions:" -ForegroundColor Yellow
        Write-Host "    proxy   — Start Anthropic↔Ollama proxy (port $ProxyPort)" -ForegroundColor White
        Write-Host "    stop    — Stop proxy" -ForegroundColor White
        Write-Host "    test    — Test 4 models + Q&A" -ForegroundColor White
        Write-Host "    start   — Start proxy + claude --dangerously-skip-permissions" -ForegroundColor White
        Write-Host "    jarvis  — JARVIS autonomous daemon (never stops)" -ForegroundColor White
        Write-Host "    status  — Show all status" -ForegroundColor White
        Write-Host ""
        Write-Host "  Models: $($ModelPool -join ' | ')" -ForegroundColor DarkGray
        Write-Host "  Proxy:  $ProxyUrl" -ForegroundColor DarkGray
        Write-Host ""
    }
}

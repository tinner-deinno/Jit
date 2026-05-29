# jit-switch.ps1 — Interactive model switcher for multi-proxy + Claude Code
# Usage:
#   .\jit-switch menu           — interactive numbered menu
#   .\jit-switch use <model>    — select model directly (e.g. copilot/claude-sonnet-4.6)
#   .\jit-switch list           — show all available models
#   .\jit-switch status         — check all backend status
#   .\jit-switch validate       — smoke test all backends
#   .\jit-switch launch [model] — start proxy + Claude Code

param(
    [Parameter(Position=0)] [string]$Action = "menu",
    [Parameter(Position=1)] [string]$ModelArg = ""
)

$PROXY_PORT = 4322
$PROXY_HOST = "127.0.0.1"
$PROXY_URL  = "http://$PROXY_HOST`:$PROXY_PORT"
$SCRIPT_DIR = Split-Path $PSScriptRoot -Parent
$ENV_FILE   = Join-Path $SCRIPT_DIR ".env"
$PROXY_PY   = Join-Path $SCRIPT_DIR "scripts\multi-proxy.py"

# Load .env
if (Test-Path $ENV_FILE) {
    Get-Content $ENV_FILE | Where-Object { $_ -match '^[A-Z_]+=.+' } | ForEach-Object {
        $k, $v = $_ -split '=', 2
        if (-not [System.Environment]::GetEnvironmentVariable($k)) {
            [System.Environment]::SetEnvironmentVariable($k, $v.Trim('"'))
        }
    }
}

# ─── Model catalog ────────────────────────────────────────────────────
$MODELS = [ordered]@{
    # MDES Ollama (remote)
    "mdes/gemma4:26b"                                = @{ group="MDES Ollama (remote)"; desc="Gemma4 26B — default Thai/code" }
    "mdes/qwen3.5:27b"                               = @{ group="MDES Ollama (remote)"; desc="Qwen3.5 27B — long context" }
    "mdes/qwen3.5:9b"                                = @{ group="MDES Ollama (remote)"; desc="Qwen3.5 9B — fast" }
    "mdes/qwen2.5-coder:32b"                         = @{ group="MDES Ollama (remote)"; desc="Qwen2.5 Coder 32B — coding" }
    "mdes/gemma4:e4b"                                = @{ group="MDES Ollama (remote)"; desc="Gemma4 Edge 4B — ultra fast" }
    "mdes/gemma3:12b"                                = @{ group="MDES Ollama (remote)"; desc="Gemma3 12B" }

    # GitHub Copilot — Claude (bridged via Anthropic format)
    "copilot/claude-sonnet-4.6"                      = @{ group="Copilot Claude"; desc="Claude Sonnet 4.6 (latest)" }
    "copilot/claude-sonnet-4.5"                      = @{ group="Copilot Claude"; desc="Claude Sonnet 4.5" }
    "copilot/claude-haiku-4.5"                       = @{ group="Copilot Claude"; desc="Claude Haiku 4.5 — fast/cheap" }
    "copilot/claude-opus-4.7"                        = @{ group="Copilot Claude"; desc="Claude Opus 4.7 — powerful" }
    "copilot/claude-opus-4.5"                        = @{ group="Copilot Claude"; desc="Claude Opus 4.5" }

    # GitHub Copilot — GPT-5 series
    "copilot/gpt-5.5"                                = @{ group="Copilot GPT-5"; desc="GPT-5.5 — latest" }
    "copilot/gpt-5.4"                                = @{ group="Copilot GPT-5"; desc="GPT-5.4" }
    "copilot/gpt-5.3-codex"                          = @{ group="Copilot GPT-5"; desc="GPT-5.3 Codex — code" }
    "copilot/gpt-5.2"                                = @{ group="Copilot GPT-5"; desc="GPT-5.2" }
    "copilot/gpt-5.2-codex"                          = @{ group="Copilot GPT-5"; desc="GPT-5.2 Codex" }
    "copilot/gpt-5-mini"                             = @{ group="Copilot GPT-5"; desc="GPT-5 mini — fast" }

    # GitHub Copilot — GPT-4 series
    "copilot/gpt-4.1"                                = @{ group="Copilot GPT-4"; desc="GPT-4.1" }
    "copilot/gpt-4o"                                 = @{ group="Copilot GPT-4"; desc="GPT-4o" }
    "copilot/gpt-4o-mini"                            = @{ group="Copilot GPT-4"; desc="GPT-4o-mini — fast/cheap" }

    # GitHub Copilot — Gemini
    "copilot/gemini-2.5-pro"                         = @{ group="Copilot Gemini"; desc="Gemini 2.5 Pro" }

    # ThaiLLM — Typhoon (SCB 10X)
    "thaillm/typhoon-v2-70b-instruct"               = @{ group="ThaiLLM Typhoon"; desc="Typhoon v2 70B — best Thai" }
    "thaillm/typhoon-v2-8b-instruct"                = @{ group="ThaiLLM Typhoon"; desc="Typhoon v2 8B — fast Thai" }
    "thaillm/typhoon-v2-r1-70b"                     = @{ group="ThaiLLM Typhoon"; desc="Typhoon v2 R1 70B — reasoning" }
    "thaillm/typhoon-v1.5x-70b-instruct"            = @{ group="ThaiLLM Typhoon"; desc="Typhoon v1.5x 70B" }
    "thaillm/Typhoon-S-ThaiLLM-8B-Instruct"        = @{ group="ThaiLLM Typhoon"; desc="Typhoon-S 8B (SCB10X)" }

    # ThaiLLM — Other Thai models
    "thaillm/OpenThaiGPT-ThaiLLM-8B-Instruct-v7.2" = @{ group="ThaiLLM Other"; desc="OpenThaiGPT 8B v7.2 (AIEAT)" }
    "thaillm/Pathumma-ThaiLLM-qwen3-8b-think-3.0.0"= @{ group="ThaiLLM Other"; desc="Pathumma Qwen3 8B think (NECTEC)" }
    "thaillm/THaLLE-0.2-ThaiLLM-8B-fa"             = @{ group="ThaiLLM Other"; desc="THaLLE 0.2 8B (KBTG)" }

    # Local Ollama
    "local/qwen2.5-coder:7b"                         = @{ group="Local Ollama"; desc="Qwen2.5 Coder 7B — local code" }
    "local/qwen3:8b"                                 = @{ group="Local Ollama"; desc="Qwen3 8B — local general" }
    "local/llama3.2"                                 = @{ group="Local Ollama"; desc="Llama 3.2 — local general" }
}

function EnsureProxyRunning {
    try {
        $resp = Invoke-RestMethod -Uri "$PROXY_URL/health" -TimeoutSec 2 -ErrorAction Stop
        return $true
    } catch {}

    Write-Host "[jit-switch] Starting multi-proxy.py..." -ForegroundColor Cyan
    $logDir = Join-Path $SCRIPT_DIR "tmp_multi_proxy.log"
    $pyCmd = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { "python" }
    Start-Process $pyCmd -ArgumentList @($PROXY_PY) `
        -WorkingDirectory $SCRIPT_DIR `
        -RedirectStandardOutput $logDir `
        -WindowStyle Hidden

    Start-Sleep 3
    try {
        $resp = Invoke-RestMethod -Uri "$PROXY_URL/health" -TimeoutSec 3 -ErrorAction Stop
        Write-Host "[jit-switch] Proxy ready ✓" -ForegroundColor Green
        return $true
    } catch {
        Write-Warning "[jit-switch] Proxy did not start. Check $logDir"
        return $false
    }
}

function SetModelEnv($model) {
    $env:ANTHROPIC_API_KEY  = "multi-proxy"
    $env:OPENAI_API_KEY     = "multi-proxy"
    $env:ANTHROPIC_BASE_URL = $PROXY_URL
    $env:OPENAI_BASE_URL    = $PROXY_URL
    $env:CLAUDE_MODEL       = $model
    Write-Host ""
    Write-Host "  ANTHROPIC_BASE_URL = $PROXY_URL" -ForegroundColor DarkGray
    Write-Host "  OPENAI_BASE_URL    = $PROXY_URL" -ForegroundColor DarkGray
    Write-Host "  ANTHROPIC_API_KEY  = multi-proxy" -ForegroundColor DarkGray
    Write-Host "  OPENAI_API_KEY     = multi-proxy" -ForegroundColor DarkGray
    Write-Host "  CLAUDE_MODEL       = $model" -ForegroundColor DarkGray
    Write-Host ""
}

function LaunchWithModel($model) {
    EnsureProxyRunning | Out-Null
    SetModelEnv $model
    Write-Host "[jit-switch] Launching Claude Code with model: $model" -ForegroundColor Yellow
    & claude --model $model --dangerously-skip-permissions
}

function ShowList {
    Write-Host ""
    Write-Host "  Available models (use with .\jit-switch use <id>):" -ForegroundColor Cyan
    $currentGroup = ""
    foreach ($key in $MODELS.Keys) {
        $info = $MODELS[$key]
        if ($info.group -ne $currentGroup) {
            $currentGroup = $info.group
            Write-Host ""
            Write-Host "  [$currentGroup]" -ForegroundColor Blue
        }
        Write-Host "    $key" -ForegroundColor White -NoNewline
        Write-Host "  — $($info.desc)" -ForegroundColor DarkGray
    }
    Write-Host ""
}

function ShowMenu {
    $items = @($MODELS.Keys)
    $num = 1
    $groupNums = [ordered]@{}
    $currentGroup = ""

    Write-Host ""
    Write-Host "  🤖 Jit Model Switcher — pick a model:" -ForegroundColor Cyan
    Write-Host ""

    foreach ($key in $items) {
        $info = $MODELS[$key]
        if ($info.group -ne $currentGroup) {
            $currentGroup = $info.group
            Write-Host "  [$currentGroup]" -ForegroundColor Blue
        }
        Write-Host "    " -NoNewline
        Write-Host "$num" -ForegroundColor Yellow -NoNewline
        Write-Host ") $key" -ForegroundColor White -NoNewline
        Write-Host " — $($info.desc)" -ForegroundColor DarkGray
        $num++
    }

    Write-Host ""
    Write-Host -NoNewline "  Enter number (or q to quit): "
    $choice = Read-Host

    if ($choice -eq "q" -or $choice -eq "") { return }
    $idx = [int]$choice - 1
    if ($idx -lt 0 -or $idx -ge $items.Count) {
        Write-Warning "Invalid choice."
        return
    }

    $selected = $items[$idx]
    Write-Host ""
    Write-Host "  ✓ Selected: $selected" -ForegroundColor Green
    LaunchWithModel $selected
}

function ShowStatus {
    Write-Host ""
    Write-Host "  Checking backends..." -ForegroundColor Cyan

    # MDES Ollama
    try {
        $r = Invoke-RestMethod -Uri "https://ollama.mdes-innova.online/api/tags" `
            -Headers @{ Authorization = "Bearer $env:OLLAMA_TOKEN" } -TimeoutSec 5
        Write-Host "  MDES Ollama     : ✓ online ($($r.models.Count) models)" -ForegroundColor Green
    } catch { Write-Host "  MDES Ollama     : ✗ $($_.Exception.Message)" -ForegroundColor Red }

    # GitHub Copilot
    try {
        $token = & gh auth token 2>$null
        if ($token) {
            # Resolve Copilot bearer token
            $h = @{ Authorization = "token $token"; "editor-version" = "vscode/1.89.0" }
            $tokResp = Invoke-RestMethod -Uri "https://api.github.com/copilot_internal/v2/token" -Headers $h -TimeoutSec 5
            Write-Host "  GitHub Copilot  : ✓ token OK" -ForegroundColor Green
        } else { Write-Host "  GitHub Copilot  : ✗ gh auth not configured" -ForegroundColor Red }
    } catch { Write-Host "  GitHub Copilot  : ✗ $($_.Exception.Message)" -ForegroundColor Red }

    # ThaiLLM
    if ($env:THAILLM_TOKEN) {
        try {
            $r = Invoke-RestMethod -Uri "$env:THAILLM_BASE_URL/v1/models" `
                -Headers @{ Authorization = "Bearer $env:THAILLM_TOKEN" } -TimeoutSec 5
            Write-Host "  ThaiLLM         : ✓ $($r.data.Count) models" -ForegroundColor Green
        } catch { Write-Host "  ThaiLLM         : ✗ $($_.Exception.Message)" -ForegroundColor Red }
    } else {
        Write-Host "  ThaiLLM         : ○ no THAILLM_TOKEN in .env" -ForegroundColor Yellow
    }

    # Local Ollama
    try {
        $r = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 3
        Write-Host "  Local Ollama    : ✓ $($r.models.Count) models installed" -ForegroundColor Green
    } catch { Write-Host "  Local Ollama    : ○ not running (start with: ollama serve)" -ForegroundColor Yellow }

    # Proxy
    try {
        $r = Invoke-RestMethod -Uri "$PROXY_URL/health" -TimeoutSec 2
        Write-Host "  Proxy :$PROXY_PORT     : ✓ active=$($r.current_backend) reqs=$($r.requests)" -ForegroundColor Green
    } catch { Write-Host "  Proxy :$PROXY_PORT     : ○ not running (.\jit-switch launch to start)" -ForegroundColor Yellow }

    Write-Host ""
}

function RunValidate {
    EnsureProxyRunning | Out-Null
    SetModelEnv "mdes/gemma4:26b"

    $testModels = @(
        "mdes/gemma4:26b",
        "copilot/claude-haiku-4.5",
        "copilot/gpt-4o"
    )

    if ($env:THAILLM_TOKEN) { $testModels += "thaillm/typhoon-v2-8b-instruct" }

    foreach ($m in $testModels) {
        Write-Host -NoNewline "  Testing $m ... "
        $out = & claude --model $m --dangerously-skip-permissions -p "Reply with only: OK" 2>&1
        if ($LASTEXITCODE -eq 0 -and $out -match "OK") {
            Write-Host "✓" -ForegroundColor Green
        } else {
            Write-Host "✗ exit=$LASTEXITCODE output=$out" -ForegroundColor Red
        }
    }
    Write-Host ""
}

# ─── Main dispatch ────────────────────────────────────────────────────
switch ($Action.ToLower()) {
    "menu"     { ShowMenu }
    "list"     { ShowList }
    "status"   { ShowStatus }
    "validate" { RunValidate }

    "use" {
        if (-not $ModelArg) { Write-Warning "Usage: .\jit-switch use <model>"; exit 1 }
        EnsureProxyRunning | Out-Null
        SetModelEnv $ModelArg
        Write-Host "[jit-switch] Environment set. Run: claude --model $ModelArg --dangerously-skip-permissions" -ForegroundColor Green
    }

    "launch" {
        $m = if ($ModelArg) { $ModelArg } else { "mdes/gemma4:26b" }
        LaunchWithModel $m
    }

    default {
        Write-Host "jit-switch — Jit multi-model launcher" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  USAGE:" -ForegroundColor White
        Write-Host "    .\jit-switch menu                   — interactive model picker + launch"
        Write-Host "    .\jit-switch use copilot/gpt-4o     — set env for a specific model"
        Write-Host "    .\jit-switch launch [model]         — start proxy + claude with model"
        Write-Host "    .\jit-switch list                   — show all models"
        Write-Host "    .\jit-switch status                 — check all backends"
        Write-Host "    .\jit-switch validate               — smoke test models"
        Write-Host ""
        Write-Host "  BACKENDS:" -ForegroundColor White
        Write-Host "    mdes/       MDES Ollama (gemma4:26b, qwen3.5, qwen2.5-coder)"
        Write-Host "    copilot/    GitHub Copilot (Claude, GPT-5, GPT-4, Gemini)"
        Write-Host "    thaillm/    Thai LLMs (Typhoon, OpenThaiGPT, Pathumma, THaLLE)"
        Write-Host "    local/      Local Ollama (must be running: ollama serve)"
        Write-Host ""
    }
}

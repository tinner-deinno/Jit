# openclaude-mdes.ps1 — Launch OpenClaude with mdes.ollama backend
#
# Usage:
#   .\scripts\openclaude-mdes.ps1              # default: gemma4:26b
#   .\scripts\openclaude-mdes.ps1 -Model code  # qwen2.5-coder:32b (code)
#   .\scripts\openclaude-mdes.ps1 -Model deep  # deepseek-coder:33b
#   .\scripts\openclaude-mdes.ps1 -Model fast  # gemma4:e4b (fast)
#   .\scripts\openclaude-mdes.ps1 -Model coder # qwen2.5-coder:32b
#   .\scripts\openclaude-mdes.ps1 -Github      # Switch to GitHub Copilot
#
# Available mdes.ollama models:
#   gemma4:26b          — Thai/General (หลัก) ← default
#   gemma4:e4b          — fast + lightweight
#   qwen2.5-coder:32b   — code generation specialist
#   deepseek-coder:33b  — deep code analysis
#   qwen3.5:9b          — fast, Thai+EN

param(
    [ValidateSet("default","fast","code","deep","coder","smart","vision","")]
    [string]$Model = "default",
    [switch]$Github
)

$JitRoot = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $JitRoot ".env"

# Load token from .env (NOT hardcoded)
$OllamaToken = ""
$OllamaUrl   = "https://ollama.mdes-innova.online"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') {
            $k = $Matches[1].Trim(); $v = $Matches[2].Trim()
            if ($k -eq "OLLAMA_TOKEN")    { $OllamaToken = $v }
            if ($k -eq "OLLAMA_BASE_URL") { $OllamaUrl   = $v }
        }
    }
}

$models = @{
    default = "gemma4:26b"
    fast    = "gemma4:e4b"
    code    = "qwen2.5-coder:32b"
    coder   = "qwen2.5-coder:32b"
    deep    = "deepseek-coder:33b"
    smart   = "qwen3.5:9b"
    vision  = "qwen3-vl:8b"
}

Write-Host ""

# ── GitHub Copilot mode ───────────────────────────────────────────
if ($Github) {
    Write-Host "=== OpenClaude + GitHub Copilot ===" -ForegroundColor Magenta
    Write-Host "  Auth: OAuth (no token in env)" -ForegroundColor Cyan
    Write-Host "  Note: run /onboard-github on first launch" -ForegroundColor Yellow
    Write-Host ""

    $env:CLAUDE_CODE_USE_GITHUB = "1"
    $GhToken = (gh auth token 2>$null)
    if ($GhToken -and $LASTEXITCODE -eq 0) {
        $env:GITHUB_TOKEN = $GhToken
        Write-Host "  ✅ gh CLI token loaded" -ForegroundColor Green
    }
    Remove-Item Env:CLAUDE_CODE_USE_OPENAI -ErrorAction SilentlyContinue
    Remove-Item Env:OPENAI_API_KEY         -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_API_KEY      -ErrorAction SilentlyContinue
}
# ── MDES Ollama mode ──────────────────────────────────────────────
else {
    if (-not $OllamaToken) {
        Write-Host "❌ OLLAMA_TOKEN not found in .env" -ForegroundColor Red
        exit 1
    }
    $chosenModel = $models[$Model]
    Write-Host "=== OpenClaude + mdes.ollama ===" -ForegroundColor Magenta
    Write-Host "  Backend : $OllamaUrl/v1" -ForegroundColor Cyan
    Write-Host "  Model   : $chosenModel  (profile: $Model)" -ForegroundColor Cyan
    Write-Host "  Change  : /model inside TUI" -ForegroundColor DarkGray
    Write-Host ""

    $env:CLAUDE_CODE_USE_OPENAI = "1"
    $env:OPENAI_BASE_URL        = "$OllamaUrl/v1"
    $env:OPENAI_API_KEY         = $OllamaToken
    $env:OPENAI_MODEL           = $chosenModel
    Remove-Item Env:CLAUDE_CODE_USE_GITHUB -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_API_KEY      -ErrorAction SilentlyContinue
}

# ── Launch (try global npm install first, then source build) ──────
$GcOC  = Get-Command openclaude -ErrorAction SilentlyContinue
$OCCmd = if ($GcOC) { $GcOC.Source } else { $null }
$SrcDist = "C:\Users\admin\DEV\openclaude\dist\cli.mjs"

if ($OCCmd) {
    & openclaude
} elseif (Test-Path $SrcDist) {
    Write-Host "  (running from source build)" -ForegroundColor DarkGray
    Push-Location "C:\Users\admin\DEV\openclaude"
    node $SrcDist
    Pop-Location
} else {
    Write-Host "❌ openclaude not found. Install:" -ForegroundColor Red
    Write-Host "   npm install -g @gitlawb/openclaude" -ForegroundColor Yellow
    Write-Host "   OR: .\scripts\setup-openclaude-win.ps1 (source build)" -ForegroundColor Yellow
}

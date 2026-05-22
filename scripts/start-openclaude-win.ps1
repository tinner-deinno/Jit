<#
.SYNOPSIS
    Launch OpenClaude TUI with MDES Ollama or GitHub Copilot (Windows)

.DESCRIPTION
    Reads token from Jit/.env, sets up env vars, launches openclaude.
    Supports profile selection without putting secrets in .env permanently.

.USAGE
    .\scripts\start-openclaude-win.ps1               # Interactive model picker
    .\scripts\start-openclaude-win.ps1 -Profile mdes # MDES Ollama (gemma4:26b)
    .\scripts\start-openclaude-win.ps1 -Profile mdes -Model qwen2.5-coder:32b
    .\scripts\start-openclaude-win.ps1 -Profile github   # GitHub Copilot (no token needed)
    .\scripts\start-openclaude-win.ps1 -Profile local    # Local Ollama

.NOTES
    First-time GitHub Copilot: run with -Profile github, then type /onboard-github
#>

param(
    [ValidateSet("mdes", "github", "local", "")]
    [string]$Profile = "",
    [string]$Model = ""
)

$OpenClaudeDir = "C:\Users\admin\DEV\openclaude"
$DistPath = "$OpenClaudeDir\dist\cli.mjs"
$JitRoot = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $JitRoot ".env"

function Write-Green($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Yellow($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Red($msg) { Write-Host $msg -ForegroundColor Red }
function Write-Cyan($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Magenta($msg) { Write-Host $msg -ForegroundColor Magenta }

Write-Cyan "`n🤖 OpenClaude Launcher — Jit (จิต)"
Write-Cyan "=====================================`n"

# ── Check build ──────────────────────────────────────────────────
if (-not (Test-Path $DistPath)) {
    Write-Red "❌ openclaude not built yet."
    Write-Yellow "   Run: .\scripts\setup-openclaude-win.ps1"
    exit 1
}

# ── Load Jit .env ────────────────────────────────────────────────
$OllamaToken = ""
$OllamaUrl   = "https://ollama.mdes-innova.online"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') {
            $k = $Matches[1].Trim(); $v = $Matches[2].Trim()
            if ($k -eq "OLLAMA_TOKEN")   { $OllamaToken = $v }
            if ($k -eq "OLLAMA_BASE_URL") { $OllamaUrl   = $v }
        }
    }
    Write-Green "✅ Loaded Jit .env"
}

# ── Available MDES models ─────────────────────────────────────────
$MdesModels = @(
    [PSCustomObject]@{ Name="gemma4:26b";          Label="gemma4:26b        — Thai/General (หลัก)" }
    [PSCustomObject]@{ Name="qwen2.5-coder:32b";   Label="qwen2.5-coder:32b — Coding specialist" }
    [PSCustomObject]@{ Name="deepseek-coder:33b";  Label="deepseek-coder:33b— Deep code analysis" }
    [PSCustomObject]@{ Name="gemma4:e4b";          Label="gemma4:e4b        — Lightweight/Fast" }
)

# ── Interactive profile picker ────────────────────────────────────
if (-not $Profile) {
    Write-Host "Select provider:"
    Write-Host "  [1] MDES Ollama  — $OllamaUrl"
    Write-Host "  [2] GitHub Copilot — Claude Sonnet via Copilot (ไม่ต้องใส่ token)"
    Write-Host "  [3] Local Ollama — http://127.0.0.1:11434"
    Write-Host ""
    $choice = Read-Host "Choice [1-3]"
    switch ($choice) {
        "1" { $Profile = "mdes" }
        "2" { $Profile = "github" }
        "3" { $Profile = "local" }
        default { $Profile = "mdes" }
    }
}

# ── Profile: MDES Ollama ─────────────────────────────────────────
if ($Profile -eq "mdes") {
    if (-not $OllamaToken -or $OllamaToken -eq "your_mdes_ollama_token_here") {
        Write-Red "❌ OLLAMA_TOKEN not set in Jit .env"
        Write-Yellow "   Edit: $EnvFile"
        Write-Yellow "   Add:  OLLAMA_TOKEN=9e34679b9d60d8b984005ec46508579c"
        exit 1
    }

    # Model picker if not specified
    if (-not $Model) {
        Write-Host "`nAvailable MDES Ollama models:"
        for ($i = 0; $i -lt $MdesModels.Count; $i++) {
            Write-Host "  [$($i+1)] $($MdesModels[$i].Label)"
        }
        Write-Host "  (Enter = gemma4:26b)"
        $mChoice = Read-Host "`nModel [1-$($MdesModels.Count)]"
        if ($mChoice -match '^\d+$' -and [int]$mChoice -ge 1 -and [int]$mChoice -le $MdesModels.Count) {
            $Model = $MdesModels[[int]$mChoice - 1].Name
        } else {
            $Model = "gemma4:26b"
        }
    }

    Write-Magenta "`n🦙 MDES Ollama → $Model"

    # Set env vars (session only, NOT written to any file)
    $env:CLAUDE_CODE_USE_OPENAI = "1"
    $env:OPENAI_BASE_URL        = "$OllamaUrl/v1"
    $env:OPENAI_API_KEY         = $OllamaToken
    $env:OPENAI_MODEL           = $Model
    # Clear conflicting vars
    Remove-Item Env:CLAUDE_CODE_USE_GITHUB -ErrorAction SilentlyContinue
    Remove-Item Env:GITHUB_TOKEN          -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_API_KEY     -ErrorAction SilentlyContinue
}

# ── Profile: GitHub Copilot ───────────────────────────────────────
elseif ($Profile -eq "github") {
    Write-Magenta "`n🐙 GitHub Copilot mode (token-free auth)"
    Write-Host "   ℹ️  First time? Type /onboard-github inside TUI to authenticate"
    Write-Host "   ℹ️  Stored credentials are used automatically after that`n"

    $env:CLAUDE_CODE_USE_GITHUB = "1"
    # Clear OPENAI/Anthropic vars to avoid conflicts
    Remove-Item Env:CLAUDE_CODE_USE_OPENAI -ErrorAction SilentlyContinue
    Remove-Item Env:OPENAI_API_KEY         -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_API_KEY      -ErrorAction SilentlyContinue

    # Try gh CLI token as fallback (if user has gh auth status)
    $GhToken = (gh auth token 2>$null)
    if ($GhToken -and $GhToken -notmatch "error") {
        $env:GITHUB_TOKEN = $GhToken
        Write-Green "   ✅ GitHub token loaded from gh CLI"
    } else {
        Write-Yellow "   ⚠️  gh token not found — use /onboard-github inside TUI"
    }
}

# ── Profile: Local Ollama ─────────────────────────────────────────
elseif ($Profile -eq "local") {
    if (-not $Model) { $Model = "qwen2.5:0.5b" }
    Write-Magenta "`n🏠 Local Ollama → $Model"

    # Test local ollama
    $ProgressPreference = 'SilentlyContinue'
    try {
        $r = Invoke-WebRequest "http://127.0.0.1:11434/api/tags" -UseBasicParsing -TimeoutSec 3
        Write-Green "   ✅ Local Ollama is running"
    } catch {
        Write-Red "   ❌ Local Ollama not running"
        Write-Yellow "   Start it first: ollama serve"
        exit 1
    }

    $env:CLAUDE_CODE_USE_OPENAI = "1"
    $env:OPENAI_BASE_URL        = "http://127.0.0.1:11434/v1"
    $env:OPENAI_API_KEY         = "ollama"
    $env:OPENAI_MODEL           = $Model
    Remove-Item Env:CLAUDE_CODE_USE_GITHUB -ErrorAction SilentlyContinue
    Remove-Item Env:ANTHROPIC_API_KEY      -ErrorAction SilentlyContinue
}

# ── Launch ────────────────────────────────────────────────────────
Write-Host ""
Write-Green "🚀 Starting OpenClaude..."
Write-Host "   Tip: /model → switch model   /provider → change provider   /onboard-github → GitHub auth"
Write-Host ""

# Try global npm install first, then source build
$GcOC  = Get-Command openclaude -ErrorAction SilentlyContinue
$OCCmd = if ($GcOC) { $GcOC.Source } else { $null }
if ($OCCmd) {
    openclaude @args
} elseif (Test-Path $DistPath) {
    Push-Location $OpenClaudeDir
    node $DistPath @args
    Pop-Location
} else {
    Write-Red "❌ openclaude not installed. Run:"
    Write-Yellow "   npm install -g @gitlawb/openclaude"
    Write-Yellow "   OR: .\scripts\setup-openclaude-win.ps1 (source build)"
    exit 1
}

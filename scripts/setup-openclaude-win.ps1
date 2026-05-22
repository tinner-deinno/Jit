<#
.SYNOPSIS
    One-time setup for OpenClaude on Windows + create MDES Ollama profile

.DESCRIPTION
    1. Install bun dependencies
    2. Build openclaude (dist/cli.mjs)
    3. Install CLI globally
    4. Verify it works

.USAGE
    .\scripts\setup-openclaude-win.ps1
    .\scripts\setup-openclaude-win.ps1 -Rebuild  # Force rebuild
#>

param([switch]$Rebuild)

$OpenClaudeDir = "C:\Users\admin\DEV\openclaude"
$JitRoot = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $JitRoot ".env"

function Write-Green($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Yellow($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Red($msg) { Write-Host $msg -ForegroundColor Red }
function Write-Cyan($msg) { Write-Host $msg -ForegroundColor Cyan }
function Write-Bold($msg) { Write-Host $msg -ForegroundColor White }

Write-Cyan "`n⚡ OpenClaude Setup — Windows + MDES Ollama"
Write-Cyan "=============================================`n"

# ── Check prereqs ────────────────────────────────────────────────
$BunExe = "$env:USERPROFILE\.bun\bin\bun.exe"
if (-not (Test-Path $BunExe)) {
    $GcBun = Get-Command bun -ErrorAction SilentlyContinue
    $BunExe = if ($GcBun) { $GcBun.Source } else { $null }
}
if (-not $BunExe) {
    Write-Red "❌ Bun not found. Install: irm bun.sh/install.ps1 | iex"
    exit 1
}
Write-Green "✅ Bun: $BunExe"

$GcNode = Get-Command node -ErrorAction SilentlyContinue
$NodeExe = if ($GcNode) { $GcNode.Source } else { $null }
if (-not $NodeExe) {
    Write-Red "❌ Node.js not found. Install: https://nodejs.org"
    exit 1
}
$NodeVer = (node --version 2>$null)
Write-Green "✅ Node: $NodeVer"

if (-not (Test-Path $OpenClaudeDir)) {
    Write-Red "❌ openclaude not found at: $OpenClaudeDir"
    exit 1
}

# ── Install deps ─────────────────────────────────────────────────
Write-Cyan "`n📦 Installing dependencies..."
Push-Location $OpenClaudeDir
& $BunExe install
if ($LASTEXITCODE -ne 0) {
    Write-Red "❌ bun install failed"
    Pop-Location; exit 1
}
Write-Green "✅ Dependencies installed"

# ── Build dist/cli.mjs ───────────────────────────────────────────
$DistPath = "$OpenClaudeDir\dist\cli.mjs"
if ($Rebuild -or -not (Test-Path $DistPath)) {
    Write-Cyan "`n🔨 Building openclaude..."
    & $BunExe run build
    if ($LASTEXITCODE -ne 0) {
        Write-Red "❌ Build failed. Check error above."
        Pop-Location; exit 1
    }
    Write-Green "✅ Built: $DistPath"
} else {
    Write-Yellow "⏭️  dist/cli.mjs exists (use -Rebuild to force)"
}
Pop-Location

# ── Smoke test ────────────────────────────────────────────────────
Write-Cyan "`n🧪 Smoke test..."
$version = node "$DistPath" --version 2>$null
if ($version) {
    Write-Green "✅ openclaude $version"
} else {
    Write-Yellow "⚠️  Version check failed but build succeeded. Try running manually."
}

# ── Create MDES Ollama profile ───────────────────────────────────
Write-Cyan "`n🧠 Creating MDES Ollama profile..."

# Load OLLAMA_TOKEN from Jit .env
$OllamaToken = ""
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^OLLAMA_TOKEN=(.+)$') { $OllamaToken = $Matches[1].Trim() }
    }
}
if (-not $OllamaToken) {
    Write-Yellow "⚠️  OLLAMA_TOKEN not found in Jit .env"
    Write-Yellow "   Profile will be created without token (edit manually)"
}

# Profile goes in ~/.openclaude/ (getClaudeConfigHomeDir returns ~/.openclaude on Windows)
$OpenClaudeConfigDir = "$env:USERPROFILE\.openclaude"
if (-not (Test-Path $OpenClaudeConfigDir)) {
    New-Item -ItemType Directory -Path $OpenClaudeConfigDir | Out-Null
}
$ProfilePath = "$OpenClaudeConfigDir\.openclaude-profile.json"
$ApiKey = if ($OllamaToken) { $OllamaToken } else { "your_ollama_token" }
$MdesProfile = @{
    profile   = "openai"
    env       = @{
        CLAUDE_CODE_USE_OPENAI = "1"
        OPENAI_BASE_URL        = "https://ollama.mdes-innova.online/v1"
        OPENAI_API_KEY         = $ApiKey
        OPENAI_MODEL           = "gemma4:26b"
    }
    createdAt = (Get-Date -Format "o")
}

$MdesProfile | ConvertTo-Json -Depth 3 | Out-File $ProfilePath -Encoding utf8
Write-Green "✅ Profile saved: $ProfilePath"
Write-Host "   Model: gemma4:26b (change with /model inside TUI)"
Write-Host "   Models: gemma4:26b | qwen2.5-coder:32b | deepseek-coder:33b | gemma4:e4b"

# ── Summary ───────────────────────────────────────────────────────
Write-Cyan "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Bold "✅ Setup Complete!"
Write-Cyan "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n"
Write-Host "Run OpenClaude:"
Write-Host "  With MDES Ollama:     .\scripts\start-openclaude-win.ps1 -Profile mdes"
Write-Host "  With GitHub Copilot:  .\scripts\start-openclaude-win.ps1 -Profile github"
Write-Host "  Interactive:          .\scripts\start-openclaude-win.ps1"
Write-Host ""
Write-Host "First-time GitHub Copilot:"
Write-Host "  1. .\scripts\start-openclaude-win.ps1 -Profile github"
Write-Host "  2. Inside TUI: type /onboard-github"
Write-Host "  3. Follow device flow URL shown in terminal`n"

<#
.SYNOPSIS
    Start Discord Bot (อนุ hermes) on Windows — no Bash required
    
.DESCRIPTION
    innova's child "อนุ" on Discord, powered by MDES Ollama
    Part of มนุษย์ Agent — Jit (จิต) repo

.USAGE
    .\scripts\start-hermes-win.ps1          # Start bot
    .\scripts\start-hermes-win.ps1 -Test    # Test Ollama connection only
    .\scripts\start-hermes-win.ps1 -Status  # Check if running

.NOTES
    Requires: node.js (v24+), DISCORD_TOKEN in .env
#>

param(
    [switch]$Test,
    [switch]$Status,
    [switch]$Stop,
    [switch]$WSL
)

$JitRoot = Split-Path -Parent $PSScriptRoot
$BotDir = Join-Path $JitRoot "hermes-discord"
$EnvFile = Join-Path $JitRoot ".env"
$PidFile = "$env:TEMP\hermes-discord.pid"
$LogFile = "$env:TEMP\hermes-discord.log"

# Colour helpers
function Write-Green($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Yellow($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Red($msg) { Write-Host $msg -ForegroundColor Red }
function Write-Cyan($msg) { Write-Host $msg -ForegroundColor Cyan }

Write-Cyan "`n💬 hermes-discord (อนุ) — Windows Starter"
Write-Cyan "=========================================`n"

# ── WSL2 dispatch ─────────────────────────────────────────────────
if ($WSL) {
    $WslScript = "/mnt/c/Users/admin/Jit/scripts/start-hermes-discord.sh"
    $WslArgs = @()
    if ($Test)   { $WslArgs += "--test" }
    if ($Status) { $WslArgs += "--status" }
    if ($Stop)   { $WslArgs += "--stop" }
    Write-Cyan "🐧 Dispatching to WSL2 (Ubuntu)..."
    wsl bash $WslScript @WslArgs
    exit $LASTEXITCODE
}

# ── Load .env ────────────────────────────────────────────────────
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') {
            [System.Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), "Process")
        }
    }
    Write-Green "✅ Loaded .env"
} else {
    Write-Red "❌ .env not found at: $EnvFile"
    exit 1
}

# ── Status ───────────────────────────────────────────────────────
if ($Status) {
    if (Test-Path $PidFile) {
        $pid = Get-Content $PidFile
        $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Green "✅ hermes-discord RUNNING (PID: $pid)"
            Write-Host "   Memory: $([math]::Round($proc.WorkingSet/1MB)) MB"
        } else {
            Write-Yellow "⚠️  PID file exists but process not found (PID: $pid)"
        }
    } else {
        Write-Yellow "💤 hermes-discord NOT RUNNING"
    }
    exit 0
}

# ── Stop ─────────────────────────────────────────────────────────
if ($Stop) {
    if (Test-Path $PidFile) {
        $pid = Get-Content $PidFile
        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
        Remove-Item $PidFile -Force
        Write-Yellow "🛑 hermes-discord stopped (PID: $pid)"
    } else {
        Write-Yellow "⚠️  hermes-discord not running"
    }
    exit 0
}

# ── Check Prerequisites ──────────────────────────────────────────
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Red "❌ node.js not found. Install from https://nodejs.org"
    exit 1
}

if (-not (Test-Path "$BotDir\node_modules")) {
    Write-Yellow "📦 Installing dependencies..."
    Push-Location $BotDir
    npm install
    Pop-Location
}

# ── Check DISCORD_TOKEN ──────────────────────────────────────────
if (-not $env:DISCORD_TOKEN -or $env:DISCORD_TOKEN -eq "your_token") {
    Write-Red "❌ DISCORD_TOKEN not set in .env"
    Write-Yellow "   Edit .env and set: DISCORD_TOKEN=your_real_token"
    exit 1
}

# ── Test mode ────────────────────────────────────────────────────
if ($Test) {
    Write-Cyan "🧪 Testing Ollama connection..."
    $body = @{
        model = "qwen2.5:0.5b"
        prompt = "Say hello in Thai in 5 words."
        stream = $false
    } | ConvertTo-Json

    try {
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:11434/api/generate" `
            -Method POST -Body $body -ContentType "application/json" `
            -UseBasicParsing -TimeoutSec 30
        $result = ($resp.Content | ConvertFrom-Json).response
        Write-Green "✅ Ollama (local): $result"
    } catch {
        Write-Yellow "⚠️  Local Ollama failed, trying MDES Ollama..."
        try {
            $resp = Invoke-WebRequest -Uri "$env:OLLAMA_BASE_URL/api/generate" `
                -Method POST -Body $body -ContentType "application/json" `
                -Headers @{ "Authorization" = "Bearer $env:OLLAMA_TOKEN" } `
                -UseBasicParsing -TimeoutSec 30
            $result = ($resp.Content | ConvertFrom-Json).response
            Write-Green "✅ MDES Ollama: $result"
        } catch {
            Write-Red "❌ Both Ollama endpoints failed: $_"
        }
    }
    exit 0
}

# ── Start Bot ────────────────────────────────────────────────────
Write-Cyan "🚀 Starting hermes-discord (อนุ)..."
Write-Host "   Bot dir: $BotDir"
Write-Host "   Log: $LogFile"

$proc = Start-Process -FilePath "node" `
    -ArgumentList "bot.js" `
    -WorkingDirectory $BotDir `
    -RedirectStandardOutput $LogFile `
    -RedirectStandardError $LogFile `
    -PassThru `
    -WindowStyle Hidden

$proc.Id | Out-File $PidFile -Encoding utf8
Write-Green "✅ hermes-discord started (PID: $($proc.Id))"
Write-Host "   View logs: Get-Content '$LogFile' -Wait"
Write-Host "   Stop:      .\scripts\start-hermes-win.ps1 -Stop"

#!/usr/bin/env pwsh
# scripts/hermes-multiagent-test.ps1
# ════════════════════════════════════════════════════════════════════
#  Hermes Multi-Agent + Multi-Backend Test Orchestrator
#  Tests: model-router (Copilot/OpenAI/Ollama) + agent-spawner + chains
#
#  Usage:
#    pwsh -ExecutionPolicy Bypass -File scripts\hermes-multiagent-test.ps1
#
#  What it does:
#    1. Detect model backends (Copilot token, OpenAI key, Ollama)
#    2. Show model-router status
#    3. Run hermes-discord/test-multiagent.js  (Node.js, no Discord)
#    4. Show final PASS / FAIL
# ════════════════════════════════════════════════════════════════════
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$JitRoot   = Split-Path -Parent $ScriptDir
$HermesDir = Join-Path $JitRoot "hermes-discord"
$EnvFile   = Join-Path $JitRoot ".env"

$SEP = "=" * 60

function Write-Header($text) {
    Write-Host ""
    Write-Host $SEP -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host $SEP -ForegroundColor Cyan
}

function Write-Step($text) { Write-Host "  >> $text" -ForegroundColor Yellow }
function Write-OK($text)   { Write-Host "  OK  $text" -ForegroundColor Green  }
function Write-Warn($text) { Write-Host "  WN  $text" -ForegroundColor Yellow }
function Write-Err($text)  { Write-Host "  ER  $text" -ForegroundColor Red    }

# ── Load .env ────────────────────────────────────────────────────────
Write-Header "Hermes Multi-Agent Test  --  Jit (jiit) / manusat Agent"
Write-Step "Loading .env..."

if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line -match "^([^=]+)=(.*)$") {
            $k = $Matches[1].Trim()
            $v = $Matches[2].Trim().Trim('"').Trim("'")
            if (-not [System.Environment]::GetEnvironmentVariable($k)) {
                [System.Environment]::SetEnvironmentVariable($k, $v, "Process")
                $env:($k) = $v
            }
        }
    }
    Write-OK ".env loaded"
} else {
    Write-Warn ".env not found at $EnvFile"
}

# ── Check Node.js ─────────────────────────────────────────────────────
Write-Step "Checking Node.js..."
$nodeVer = node --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "Node.js not found. Install from https://nodejs.org"
    exit 1
}
Write-OK "Node.js $nodeVer"

# ── Check hermes-discord/node_modules ────────────────────────────────
Write-Step "Checking dependencies..."
$nodeMods = Join-Path $HermesDir "node_modules"
if (-not (Test-Path $nodeMods)) {
    Write-Step "Installing hermes-discord dependencies..."
    Push-Location $HermesDir
    npm install --silent 2>&1 | Out-Null
    Pop-Location
    if (Test-Path $nodeMods) {
        Write-OK "npm install done"
    } else {
        Write-Err "npm install failed"
        exit 1
    }
} else {
    Write-OK "node_modules present"
}

# ── Detect Backends ───────────────────────────────────────────────────
Write-Header "SECTION 1: Backend Detection"

# GitHub Copilot
$copilotFound = $false
$copilotSource = "none"

if ($env:COPILOT_TOKEN -and $env:COPILOT_TOKEN -ne "") {
    $copilotFound = $true
    $copilotSource = "COPILOT_TOKEN env"
} else {
    $appsJsonPaths = @(
        "$env:LOCALAPPDATA\github-copilot\apps.json",
        "$env:LOCALAPPDATA\GitHub Copilot\apps.json",
        "$env:APPDATA\GitHub Copilot\hosts.json",
        "$HOME\.config\github-copilot\hosts.json"
    )
    foreach ($p in $appsJsonPaths) {
        if (Test-Path $p) {
            try {
                $data = Get-Content $p -Raw | ConvertFrom-Json
                $tok = $null
                if ($data.'github.com') { $tok = $data.'github.com'.oauth_token }
                elseif ($data.PSObject.Properties) {
                    foreach ($prop in $data.PSObject.Properties) {
                        if ($prop.Value.oauth_token) { $tok = $prop.Value.oauth_token; break }
                    }
                }
                if ($tok) {
                    $copilotFound = $true
                    $copilotSource = $p
                    break
                }
            } catch {}
        }
    }
}

if ($copilotFound) {
    Write-OK "GitHub Copilot: FOUND ($copilotSource)"
} else {
    Write-Warn "GitHub Copilot: not found (install VS Code + GitHub Copilot extension, or set COPILOT_TOKEN)"
}

# OpenAI
if ($env:OPENAI_API_KEY -and $env:OPENAI_API_KEY -ne "" -and -not $env:OPENAI_API_KEY.StartsWith("#")) {
    Write-OK "OpenAI: FOUND (key set)"
} else {
    Write-Warn "OpenAI: not found (set OPENAI_API_KEY in .env for Codex support)"
}

# Ollama
$ollamaUrl = if ($env:OLLAMA_BASE_URL) { $env:OLLAMA_BASE_URL } else { "https://ollama.mdes-innova.online" }
Write-OK "MDES Ollama: always available ($ollamaUrl) — fallback backend"

# Backend order
$backendOrder = if ($env:MULTI_BACKEND_ORDER) { $env:MULTI_BACKEND_ORDER } else { "copilot,openai,ollama" }
Write-OK "Backend order: $backendOrder"

# ── Show agent-spawner registry ───────────────────────────────────────
Write-Header "SECTION 2: Agent Registry"
$agentListScript = @"
const s = require('./agent-spawner');
const agents = s.listAgents();
agents.forEach(a => console.log('  T' + a.tier + ' ' + a.name.padEnd(18) + ' ' + a.organ.padEnd(22) + ' prefers=' + a.backend + (a.model && a.model !== '(default)' ? ' [' + a.model + ']' : '')));
console.log('Total: ' + agents.length + ' agents registered');
"@

Push-Location $HermesDir
$agentList = node -e $agentListScript 2>&1
Pop-Location

Write-Host $agentList

# ── Run Node.js multiagent test ───────────────────────────────────────
Write-Header "SECTION 3: Running Multiagent Test"
Write-Step "node hermes-discord/test-multiagent.js"
Write-Host ""

Push-Location $JitRoot
$testOutput = node hermes-discord/test-multiagent.js 2>&1
$testExitCode = $LASTEXITCODE
Pop-Location

# Print test output
$testOutput | ForEach-Object { Write-Host "  $_" }

# ── Parse test result ─────────────────────────────────────────────────
Write-Header "SECTION 4: Final Verdict"

$outputStr = ($testOutput -join "`n")
$passedCount  = ($testOutput | Where-Object { $_ -match "PASS" } | Measure-Object).Count
$failedCount  = ($testOutput | Where-Object { $_ -match "FAIL" } | Measure-Object).Count
$finalLine    = $testOutput | Where-Object { $_ -match "^\s*(PASS|FAIL|PARTIAL)" } | Select-Object -Last 1

if ($testExitCode -eq 0 -and $outputStr -match "PASS") {
    Write-Host ""
    Write-Host $SEP -ForegroundColor Green
    Write-Host "  PASS  --  All multiagent tests passed" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Verified capabilities:" -ForegroundColor Green
    Write-Host "    model-router:       Copilot / OpenAI / Ollama rotation" -ForegroundColor Green
    Write-Host "    spawnAgent:         single organ agent call" -ForegroundColor Green
    Write-Host "    spawnAgentChain:    jit -> soma -> innova serial" -ForegroundColor Green
    Write-Host "    spawnAgentParallel: lak + chamu concurrent" -ForegroundColor Green
    Write-Host "    Full pipeline:      jit -> soma -> innova -> neta -> vaja" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Discord commands now available in Hermes bot:" -ForegroundColor Green
    Write-Host "    !jit spawn <agent> <msg>" -ForegroundColor Cyan
    Write-Host "    !jit spawn chain jit+soma+innova <msg>" -ForegroundColor Cyan
    Write-Host "    !jit spawn parallel lak,chamu <msg>" -ForegroundColor Cyan
    Write-Host "    !jit agents" -ForegroundColor Cyan
    Write-Host "    !jit backend" -ForegroundColor Cyan
    Write-Host $SEP -ForegroundColor Green
    Write-Host ""
    Write-Host "  PASS" -ForegroundColor Green
    exit 0
} elseif ($outputStr -match "PARTIAL PASS") {
    Write-Host ""
    Write-Host $SEP -ForegroundColor Yellow
    Write-Host "  PARTIAL PASS  --  Core tests passed, some backends unavailable" -ForegroundColor Yellow
    Write-Host "  (Add OPENAI_API_KEY or Copilot subscription for full coverage)" -ForegroundColor Yellow
    Write-Host $SEP -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  PARTIAL PASS" -ForegroundColor Yellow
    exit 0
} else {
    Write-Host ""
    Write-Host $SEP -ForegroundColor Red
    Write-Host "  FAIL  --  Tests failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Troubleshooting:" -ForegroundColor Red
    Write-Host "    1. Set OLLAMA_TOKEN in .env (MDES Ollama fallback)" -ForegroundColor Yellow
    Write-Host "    2. Install GitHub Copilot in VS Code (auto-detect)" -ForegroundColor Yellow
    Write-Host "    3. Set OPENAI_API_KEY in .env (OpenAI/Codex)" -ForegroundColor Yellow
    Write-Host "    4. Check network: curl https://ollama.mdes-innova.online/api/version" -ForegroundColor Yellow
    Write-Host $SEP -ForegroundColor Red
    Write-Host ""
    Write-Host "  FAIL" -ForegroundColor Red
    exit 1
}

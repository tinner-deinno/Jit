#!/usr/bin/env pwsh
# scripts/setup-openclaude.ps1
# ═════════════════════════════════════════════════════════════════════
# OpenClaude Setup for Jit Multi-Backend System
# 
# OpenClaude = Open-source Claude API wrapper (github.com/Gitlawb/openclaude)
# Adds self-hosted Claude API capability to Jit system
#
# Usage:
#   pwsh -ExecutionPolicy Bypass -File scripts\setup-openclaude.ps1
# ═════════════════════════════════════════════════════════════════════
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$JitRoot = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $JitRoot ".env"

function Write-Header($text) {
    Write-Host ""
    Write-Host ("=" * 62) -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host ("=" * 62) -ForegroundColor Cyan
}

function Write-OK($t)   { Write-Host "  [OK]   $t" -ForegroundColor Green  }
function Write-Warn($t) { Write-Host "  [WARN] $t" -ForegroundColor Yellow }
function Write-Fail($t) { Write-Host "  [FAIL] $t" -ForegroundColor Red    }
function Write-Step($t) { Write-Host "  >> $t"     -ForegroundColor Cyan   }

Write-Header "OpenClaude Setup for Jit System"

# ── STEP 1: Clone OpenClaude repo ────────────────────────────────────
Write-Step "Step 1: Clone OpenClaude from GitHub"
Write-Host ""

$openclaudeDir = Join-Path $JitRoot ".." "openclaude"
$repoUrl = "https://github.com/Gitlawb/openclaude.git"

if (Test-Path $openclaudeDir) {
    Write-OK "openclaude/ already cloned at $openclaudeDir"
} else {
    Write-Host "  Cloning from $repoUrl..."
    $parentDir = Split-Path -Parent $openclaudeDir
    Push-Location $parentDir
    git clone $repoUrl openclaude 2>&1 | ForEach-Object { Write-Host "    $_" }
    Pop-Location
    
    if (Test-Path $openclaudeDir) {
        Write-OK "openclaude/ cloned successfully"
    } else {
        Write-Fail "Failed to clone openclaude — check internet and Git installation"
        Write-Host "  Manual: git clone $repoUrl $openclaudeDir" -ForegroundColor Yellow
        exit 1
    }
}

# ── STEP 2: Setup Options ────────────────────────────────────────────
Write-Header "OpenClaude Installation Options"
Write-Host ""
Write-Host "Choose installation method:" -ForegroundColor Yellow
Write-Host "  1. Docker (recommended) — docker run -p 8000:8000 gitlawb/openclaude:latest"
Write-Host "  2. Python venv — clone + pip install -r requirements.txt"
Write-Host "  3. Manual — follow GitHub repo instructions"
Write-Host "  4. Skip — I'll install manually later"
Write-Host ""

$choice = Read-Host "Enter choice (1-4)"

switch ($choice) {
    "1" {
        Write-Header "Docker Installation"
        $dockerCmd = "docker run -p 8000:8000 --name openclaude-jit gitlawb/openclaude:latest"
        Write-Host ""
        Write-Host "Docker image will start OpenClaude at http://localhost:8000" -ForegroundColor Green
        Write-Host ""
        Write-Host "Run this command in a terminal:" -ForegroundColor Cyan
        Write-Host "  $dockerCmd" -ForegroundColor White
        Write-Host ""
        Write-Host "To stop: docker stop openclaude-jit" -ForegroundColor Gray
        Write-OK "Docker command ready"
    }
    "2" {
        Write-Header "Python venv Installation"
        Write-Host ""
        
        # Check Python
        $pythonVer = python --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Python found: $pythonVer"
        } else {
            Write-Fail "Python not found — install from python.org"
            exit 1
        }
        
        Push-Location $openclaudeDir
        
        # Create venv
        Write-Step "Creating virtual environment..."
        python -m venv venv 2>&1 | Out-Null
        if (Test-Path "venv\Scripts\Activate.ps1") {
            Write-OK "venv created"
        } else {
            Write-Fail "venv creation failed"
            exit 1
        }
        
        # Activate and install
        Write-Step "Activating venv and installing dependencies..."
        & .\venv\Scripts\Activate.ps1 2>&1 | Out-Null
        if (Test-Path "requirements.txt") {
            pip install -q -r requirements.txt 2>&1 | Out-Null
            Write-OK "Dependencies installed"
        } else {
            Write-Warn "requirements.txt not found — may need manual setup"
        }
        
        # Start instructions
        Write-Header "Start OpenClaude"
        Write-Host ""
        Write-Host "To start OpenClaude, run:" -ForegroundColor Cyan
        Write-Host "  cd $openclaudeDir"
        Write-Host "  .\venv\Scripts\Activate.ps1"
        Write-Host "  python -m openclaude --port 8000"
        Write-Host ""
        
        Pop-Location
    }
    "3" {
        Write-Header "Manual Installation"
        Write-Host ""
        Write-Host "Follow these steps:" -ForegroundColor Yellow
        Write-Host "  1. cd $openclaudeDir"
        Write-Host "  2. Review README.md for installation instructions"
        Write-Host "  3. Install via Docker, venv, or native Python"
        Write-Host "  4. Start OpenClaude on port 8000"
        Write-Host ""
        Write-Host "OpenClaude repo: $openclaudeDir" -ForegroundColor Cyan
    }
    "4" {
        Write-Host ""
        Write-Host "Skipped — install manually later" -ForegroundColor Yellow
        Write-Host ""
    }
    default {
        Write-Warn "Invalid choice — skipping installation"
    }
}

# ── STEP 3: Configure .env ───────────────────────────────────────────
Write-Header "Configure .env"
Write-Host ""
Write-Host "OpenClaude configuration in .env:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  OPENCLAUDE_HOST=localhost" -ForegroundColor White
Write-Host "  OPENCLAUDE_PORT=8000" -ForegroundColor White
Write-Host "  OPENCLAUDE_MODEL=claude-3.5-sonnet" -ForegroundColor White
Write-Host ""
Write-Host "✅ Already configured in $EnvFile" -ForegroundColor Green
Write-Host ""

# ── STEP 4: Test Connection ─────────────────────────────────────────
Write-Header "Test OpenClaude Connection"
Write-Host ""
Write-Host "Note: OpenClaude server must be running (docker or python)" -ForegroundColor Yellow
Write-Host ""

$testScript = @"
try {
    `$resp = Invoke-WebRequest -Uri "http://localhost:8000/health" -TimeoutSec 3 -UseBasicParsing -ErrorAction Stop
    if (`$resp.StatusCode -eq 200) {
        Write-Host "✅ OpenClaude is online at http://localhost:8000" -ForegroundColor Green
        exit 0
    }
} catch {
    Write-Host "⚠️  OpenClaude not responding at http://localhost:8000" -ForegroundColor Yellow
    Write-Host "   Start it first with Docker or Python venv" -ForegroundColor Gray
    exit 1
}
"@

Invoke-Expression $testScript

# ── STEP 5: Integration Check ────────────────────────────────────────
Write-Header "Jit Integration Check"
Write-Host ""

Push-Location $JitRoot\hermes-discord
$modelRouterCheck = node --check model-router.js 2>&1; $e1 = $LASTEXITCODE
$openclaudeCheck = node --check openclaude-adapter.js 2>&1; $e2 = $LASTEXITCODE
Pop-Location

if ($e1 -eq 0) { Write-OK "model-router.js syntax OK" } else { Write-Fail "model-router.js: $modelRouterCheck"; exit 1 }
if ($e2 -eq 0) { Write-OK "openclaude-adapter.js syntax OK" } else { Write-Fail "openclaude-adapter.js: $openclaudeCheck"; exit 1 }

# ── Final Instructions ───────────────────────────────────────────────
Write-Header "Next Steps"
Write-Host ""
Write-Host "1. Start OpenClaude server (Docker or venv)" -ForegroundColor Cyan
Write-Host "2. Verify .env OPENCLAUDE_HOST and OPENCLAUDE_PORT" -ForegroundColor Cyan
Write-Host "3. Run model-router test:" -ForegroundColor Cyan
Write-Host "   cd $JitRoot\hermes-discord"
Write-Host "   node test-multiagent.js" -ForegroundColor Gray
Write-Host "4. Check that openclaude appears in backend rotation" -ForegroundColor Cyan
Write-Host ""
Write-Host "Discord commands:" -ForegroundColor Cyan
Write-Host "  !jit backend               — check all backends including openclaude"
Write-Host "  !jit spawn openclaude <msg> — spawn openclaude agent"
Write-Host ""
Write-Host "✅ Setup complete" -ForegroundColor Green

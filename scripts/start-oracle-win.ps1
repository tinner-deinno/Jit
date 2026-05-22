<#
.SYNOPSIS
    Start Arra Oracle V3 on Windows — requires Bun or Node.js
    
.DESCRIPTION
    Oracle knowledge base server for innova (Jit mind system)
    Port: 47778 (default)

.USAGE
    .\scripts\start-oracle-win.ps1          # Start Oracle
    .\scripts\start-oracle-win.ps1 -Status  # Check health
    .\scripts\start-oracle-win.ps1 -Stop    # Stop Oracle
    .\scripts\start-oracle-win.ps1 -Search "query"  # Quick search

.NOTES
    Requires: bun (preferred) or bun-compatible runtime
    Oracle repo: C:\Users\admin\ghq\github.com\Soul-Brews-Studio\arra-oracle-v3
    OR: /workspaces/arra-oracle-v3 (Codespace)
#>

param(
    [switch]$Status,
    [switch]$Stop,
    [string]$Search = "",
    [int]$Port = 47778
)

$JitRoot = "C:\Users\admin\Jit"
$PidFile = "$env:TEMP\arra-oracle.pid"
$LogFile = "$env:TEMP\arra-oracle.log"
$OracleHealth = "http://127.0.0.1:$Port/api/health"

# Possible Oracle repo locations
$OracleRepoPaths = @(
    "C:\Users\admin\arra-oracle-v3",
    "C:\Users\admin\DEV\arra-oracle-v3",
    "C:\Users\admin\ghq\github.com\Soul-Brews-Studio\arra-oracle-v3"
)

function Write-Green($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Yellow($msg) { Write-Host $msg -ForegroundColor Yellow }
function Write-Red($msg) { Write-Host $msg -ForegroundColor Red }
function Write-Cyan($msg) { Write-Host $msg -ForegroundColor Cyan }

function Test-OracleHealth {
    $ProgressPreference = 'SilentlyContinue'
    try {
        $r = Invoke-WebRequest -Uri $OracleHealth -UseBasicParsing -TimeoutSec 3
        return $r.StatusCode -eq 200
    } catch { return $false }
}

Write-Cyan "`n🧠 Arra Oracle V3 — Windows Starter"
Write-Cyan "=====================================`n"

# ── Status ───────────────────────────────────────────────────────
if ($Status) {
    if (Test-OracleHealth) {
        Write-Green "✅ Oracle RUNNING at $OracleHealth"
        $ProgressPreference = 'SilentlyContinue'
        try {
            $resp = Invoke-WebRequest -Uri $OracleHealth -UseBasicParsing
            Write-Host ($resp.Content)
        } catch {}
    } else {
        Write-Yellow "💤 Oracle NOT RUNNING (port $Port)"
    }
    exit 0
}

# ── Stop ─────────────────────────────────────────────────────────
if ($Stop) {
    if (Test-Path $PidFile) {
        $pid = Get-Content $PidFile
        Stop-Process -Id $pid -Force -ErrorAction SilentlyContinue
        Remove-Item $PidFile -Force
        Write-Yellow "🛑 Oracle stopped (PID: $pid)"
    } else {
        Write-Yellow "⚠️  Oracle not running (no PID file)"
    }
    exit 0
}

# ── Search (if already running) ──────────────────────────────────
if ($Search -ne "") {
    if (-not (Test-OracleHealth)) {
        Write-Red "❌ Oracle not running. Start it first."
        exit 1
    }
    $ProgressPreference = 'SilentlyContinue'
    $resp = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/api/search?q=$([uri]::EscapeDataString($Search))" `
        -UseBasicParsing
    Write-Host ($resp.Content | ConvertFrom-Json | ConvertTo-Json -Depth 3)
    exit 0
}

# ── Check if already running ─────────────────────────────────────
if (Test-OracleHealth) {
    Write-Green "✅ Oracle already running at $OracleHealth"
    exit 0
}

# ── Find Oracle repo ─────────────────────────────────────────────
$OracleRepo = $null
foreach ($path in $OracleRepoPaths) {
    if (Test-Path $path) {
        $OracleRepo = $path
        break
    }
}

if (-not $OracleRepo) {
    Write-Red "❌ Arra Oracle V3 repo not found."
    Write-Yellow "   Searched:"
    $OracleRepoPaths | ForEach-Object { Write-Yellow "   - $_" }
    Write-Yellow ""
    Write-Yellow "   Clone it:"
    Write-Yellow "   git clone https://github.com/Soul-Brews-Studio/arra-oracle-v3 C:\Users\admin\arra-oracle-v3"
    Write-Yellow "   Then install Bun: https://bun.sh"
    exit 1
}

Write-Host "   Oracle repo: $OracleRepo"

# ── Check Bun ────────────────────────────────────────────────────
$BunPaths = @(
    "$env:USERPROFILE\.bun\bin\bun.exe",
    "C:\Users\admin\.bun\bin\bun.exe",
    (Get-Command bun -ErrorAction SilentlyContinue)?.Source
)

$BunExe = $null
foreach ($p in $BunPaths) {
    if ($p -and (Test-Path $p)) {
        $BunExe = $p
        break
    }
}

if (-not $BunExe) {
    Write-Red "❌ Bun not found."
    Write-Yellow "   Install Bun: https://bun.sh"
    Write-Yellow "   Or: irm bun.sh/install.ps1 | iex"
    
    # Fallback: try with node if package.json has start script
    Write-Yellow ""
    Write-Yellow "   Trying Node.js fallback..."
    $NodeExe = (Get-Command node -ErrorAction SilentlyContinue)?.Source
    if ($NodeExe) {
        Write-Yellow "   Found node at: $NodeExe"
        Write-Yellow "   NOTE: Oracle may not work without Bun. Try anyway? (y/N)"
        $yn = Read-Host
        if ($yn -ne "y") { exit 1 }
        $RuntimeExe = $NodeExe
        $RuntimeArgs = "src/server.ts"
    } else {
        Write-Red "❌ Neither Bun nor Node.js found."
        exit 1
    }
} else {
    Write-Green "✅ Found Bun: $BunExe"
    $RuntimeExe = $BunExe
    $RuntimeArgs = "run src/server.ts"
}

# ── Start Oracle ─────────────────────────────────────────────────
Write-Cyan "🚀 Starting Oracle on port $Port..."

$env:ORACLE_PORT = $Port.ToString()
$proc = Start-Process -FilePath $RuntimeExe `
    -ArgumentList $RuntimeArgs `
    -WorkingDirectory $OracleRepo `
    -Environment @{ ORACLE_PORT = $Port.ToString() } `
    -RedirectStandardOutput $LogFile `
    -RedirectStandardError $LogFile `
    -PassThru `
    -WindowStyle Hidden

$proc.Id | Out-File $PidFile -Encoding utf8
Write-Host "   PID: $($proc.Id)"
Write-Host "   Log: $LogFile"

# Wait for startup
Write-Host "   Waiting for Oracle to start..."
$maxWait = 10
for ($i = 0; $i -lt $maxWait; $i++) {
    Start-Sleep -Seconds 1
    if (Test-OracleHealth) {
        Write-Green "✅ Oracle ONLINE at $OracleHealth"
        Write-Host "   Stop: .\scripts\start-oracle-win.ps1 -Stop"
        Write-Host "   Search: .\scripts\start-oracle-win.ps1 -Search 'query'"
        exit 0
    }
    Write-Host "   ($($i+1)/$maxWait) Waiting..."
}

Write-Yellow "⚠️  Oracle started but health check timed out."
Write-Yellow "   Check log: Get-Content '$LogFile' -Last 20"

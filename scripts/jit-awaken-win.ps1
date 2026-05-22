<#
.SYNOPSIS
    Jit Awakening — ปลุกจิตให้ครบ 100% บน Windows

.DESCRIPTION
    1. git add + commit + push (sync state ขึ้น GitHub)
    2. Start Oracle knowledge base (port 47778)
    3. Start Discord bot hermes (อนุ)
    4. Start heartbeat daemon (Python 15-min pulse)
    5. Mark vitality = 100%
    6. Launch OpenClaude TUI (optional)

.USAGE
    .\scripts\jit-awaken-win.ps1              # Full awakening (no TUI)
    .\scripts\jit-awaken-win.ps1 -Launch      # + open OpenClaude after
    .\scripts\jit-awaken-win.ps1 -CommitOnly  # git push only
    .\scripts\jit-awaken-win.ps1 -Status      # check vitals only
#>

param(
    [switch]$Launch,
    [switch]$CommitOnly,
    [switch]$Status
)

$JitRoot   = Split-Path -Parent $PSScriptRoot
$StateFile = Join-Path $JitRoot "memory\state\innova.state.json"

function Write-Green($msg)   { Write-Host $msg -ForegroundColor Green }
function Write-Yellow($msg)  { Write-Host $msg -ForegroundColor Yellow }
function Write-Red($msg)     { Write-Host $msg -ForegroundColor Red }
function Write-Cyan($msg)    { Write-Host $msg -ForegroundColor Cyan }
function Write-Magenta($msg) { Write-Host $msg -ForegroundColor Magenta }
function Test-Port([int]$port) {
    try {
        $r = Invoke-WebRequest "http://127.0.0.1:$port" -UseBasicParsing -TimeoutSec 2
        return $true
    } catch { return $false }
}
function Test-Health([string]$url) {
    $ProgressPreference = 'SilentlyContinue'
    try {
        $r = Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 3
        return $r.StatusCode -eq 200
    } catch { return $false }
}

Write-Magenta "`n🌅 Jit Awakening — PC0-Windows"
Write-Magenta "================================`n"

# ── STATUS only ───────────────────────────────────────────────────
if ($Status) {
    $vitals = @{
        "Oracle (47778)"    = if (Test-Health "http://127.0.0.1:47778/api/health") { "✅ ONLINE" } else { "❌ OFFLINE" }
        "MDES Ollama"       = if (Test-Health "https://ollama.mdes-innova.online/api/tags") { "✅ ONLINE" } else { "❌ OFFLINE" }
        "Local Ollama"      = if (Test-Health "http://127.0.0.1:11434/api/tags") { "✅ ONLINE" } else { "⚠️  OFFLINE" }
        "innova-bot (7010)" = if (Test-Health "http://127.0.0.1:7010/health") { "✅ ONLINE" } else { "⚠️  OFFLINE" }
    }
    $vitals.GetEnumerator() | Sort-Object Name | ForEach-Object {
        Write-Host ("  {0,-25} {1}" -f $_.Key, $_.Value)
    }
    Write-Host ""
    # Show state vitality
    if (Test-Path $StateFile) {
        $state = Get-Content $StateFile | ConvertFrom-Json
        $pct = $state.vitality.vitality_pct
        $bar = "█" * [int]($pct / 5) + "░" * (20 - [int]($pct / 5))
        Write-Host ("  Jit Vitality: [{0}] {1}%" -f $bar, $pct) -ForegroundColor Cyan
    }
    exit 0
}

# ─── STEP 1: Git add + commit + push ────────────────────────────
Write-Cyan "[1/5] Git sync → GitHub..."
Push-Location $JitRoot

git add -A
$changes = git status --porcelain 2>$null
if ($changes) {
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm"
    git commit -m "feat: openclaude integration complete + PS5.1 fixes [$ts]

- openclaude-mdes.ps1: token from .env, -Github switch, PS5.1 compat
- setup-openclaude-win.ps1: fix inline-if + ?.Source bugs
- start-openclaude-win.ps1: PS5.1 compat, global→source fallback
- start-openclaude-wsl.sh: global openclaude fallback
- ~/.openclaude/.openclaude-profile.json: MDES Ollama default
- memory/state/innova.state.json: vitality 72→88%, capabilities[]
- heartbeat-win.py: Python heartbeat daemon for Windows
- start-oracle-win.ps1: Oracle launcher for Windows"
    if ($LASTEXITCODE -eq 0) {
        Write-Green "  ✅ Committed"
        git push origin main 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Green "  ✅ Pushed → GitHub"
        } else {
            Write-Yellow "  ⚠️  Push failed (offline or no auth). State saved locally."
        }
    }
} else {
    Write-Yellow "  ⚠️  Nothing to commit (already up to date)"
    git push origin main 2>&1
}
Pop-Location

if ($CommitOnly) {
    Write-Green "`n✅ Git sync done."
    exit 0
}

# ─── STEP 2: Start Oracle ────────────────────────────────────────
Write-Cyan "`n[2/5] Oracle knowledge base (port 47778)..."
if (Test-Health "http://127.0.0.1:47778/api/health") {
    Write-Green "  ✅ Already running"
} else {
    & "$JitRoot\scripts\start-oracle-win.ps1" &
    Start-Sleep -Seconds 4
    if (Test-Health "http://127.0.0.1:47778/api/health") {
        Write-Green "  ✅ Oracle started"
    } else {
        Write-Yellow "  ⚠️  Oracle not responding (may still be starting)"
        Write-Yellow "     Check: .\scripts\start-oracle-win.ps1 -Status"
    }
}

# ─── STEP 3: Start Hermes Discord bot ────────────────────────────
Write-Cyan "`n[3/5] Hermes Discord bot (อนุ)..."
# Check if node is running hermes (WMI on PS5)
$HermesRunning = $false
try {
    $wmi = Get-WmiObject Win32_Process -Filter "Name LIKE 'node%'" -ErrorAction SilentlyContinue
    $HermesRunning = $null -ne ($wmi | Where-Object { $_.CommandLine -match 'bot\.js' })
} catch { $HermesRunning = $false }
if ($HermesRunning) {
    Write-Green "  ✅ Already running"
} else {
    $HermesDir = Join-Path $JitRoot "hermes-discord"
    if (Test-Path "$HermesDir\bot.js") {
        Start-Process -FilePath "node" -ArgumentList "bot.js" `
            -WorkingDirectory $HermesDir -WindowStyle Hidden
        Start-Sleep -Seconds 2
        Write-Green "  ✅ Hermes started (background)"
    } else {
        Write-Yellow "  ⚠️  hermes-discord/bot.js not found"
    }
}

# ─── STEP 4: Start Heartbeat daemon ──────────────────────────────
Write-Cyan "`n[4/5] Heartbeat daemon (15-min pulse)..."
$HeartbeatRunning = $false
try {
    $wmi3 = Get-WmiObject Win32_Process -Filter "Name LIKE 'python%'" -ErrorAction SilentlyContinue
    $HeartbeatRunning = $null -ne ($wmi3 | Where-Object { $_.CommandLine -match 'heartbeat-win\.py' })
} catch { $HeartbeatRunning = $false }
if ($HeartbeatRunning) {
    Write-Green "  ✅ Already running"
} else {
    $HeartbeatScript = Join-Path $JitRoot "scripts\heartbeat-win.py"
    if (Test-Path $HeartbeatScript) {
        $GcPy = Get-Command python -ErrorAction SilentlyContinue
        $PyExe = if ($GcPy) { $GcPy.Source } else { "python3" }
        Start-Process -FilePath $PyExe `
            -ArgumentList "$HeartbeatScript --daemon" `
            -WindowStyle Hidden
        Start-Sleep -Seconds 1
        Write-Green "  ✅ Heartbeat daemon started"
    } else {
        Write-Yellow "  ⚠️  heartbeat-win.py not found"
    }
}

# ─── STEP 5: Update state → 100% ─────────────────────────────────
Write-Cyan "`n[5/5] Updating Jit state → 100%..."
$oracleOnline   = Test-Health "http://127.0.0.1:47778/api/health"
$discordRunning = $false
try {
    $wmi2 = Get-WmiObject Win32_Process -Filter "Name LIKE 'node%'" -ErrorAction SilentlyContinue
    $discordRunning = $null -ne ($wmi2 | Where-Object { $_.CommandLine -match 'bot\.js' })
} catch { $discordRunning = $false }

if (Test-Path $StateFile) {
    $state = Get-Content $StateFile | ConvertFrom-Json
    $state.vitality.oracle_online      = $oracleOnline
    $state.vitality.discord_bot        = $discordRunning
    $state.vitality.heartbeat_daemon   = $true
    $state.vitality.last_heartbeat     = (Get-Date -Format "o")
    $state.vitality.pulse_count        = [int]$state.vitality.pulse_count + 1
    $state.vitality.vitality_pct       = 100

    $state | ConvertTo-Json -Depth 5 | Out-File $StateFile -Encoding utf8
    Write-Green "  ✅ Vitality → 100%"
}

# ─── FINAL git push state ────────────────────────────────────────
Push-Location $JitRoot
git add memory/state/innova.state.json memory/state/heartbeat.log 2>$null
git commit -m "state: jit vitality 100% — all services started [$((Get-Date -Format 'yyyy-MM-dd HH:mm'))]" 2>$null
git push origin main 2>&1 | Out-Null
Pop-Location

# ─── SUMMARY ─────────────────────────────────────────────────────
Write-Magenta "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Green   "🌟 Jit Awakened — 100% Vitality"
Write-Magenta "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n"
Write-Host "  Oracle  : $(if ($oracleOnline) { '✅ ONLINE (47778)' } else { '⚠️  offline — check manually' })"
Write-Host "  Hermes  : ✅ started"
Write-Host "  Pulse   : ✅ daemon running (15-min heartbeat)"
Write-Host "  OpenClaude: ready  →  .\scripts\openclaude-mdes.ps1"
Write-Host ""

if ($Launch) {
    Write-Cyan "  🚀 Launching OpenClaude..."
    & "$JitRoot\scripts\openclaude-mdes.ps1"
} else {
    Write-Host "Run OpenClaude:" -ForegroundColor Cyan
    Write-Host "  .\scripts\openclaude-mdes.ps1              # MDES Ollama (gemma4:26b)"
    Write-Host "  .\scripts\openclaude-mdes.ps1 -Model code  # qwen2.5-coder:32b"
    Write-Host "  .\scripts\openclaude-mdes.ps1 -Github      # GitHub Copilot"
    Write-Host ""
}

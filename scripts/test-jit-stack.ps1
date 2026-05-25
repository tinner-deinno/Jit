$ErrorActionPreference = "Continue"
$JitRoot = Split-Path $PSScriptRoot -Parent

function Show-Section($t) {
    Write-Host ""
    Write-Host "=== $t ===" -ForegroundColor Cyan
}
function P($t) { Write-Host "[PASS] $t" -ForegroundColor Green }
function F($t) { Write-Host "[FAIL] $t" -ForegroundColor Red }
function S($t) { Write-Host "[SKIP] $t" -ForegroundColor Yellow }

$pass = 0
$fail = 0
$skip = 0

function Add-Pass($t) { P $t; $script:pass++ }
function Add-Fail($t) { F $t; $script:fail++ }
function Add-Skip($t) { S $t; $script:skip++ }

Show-Section "1) MDES Cloud + Ollama Local Reachability"
$ollamaBaseUrl = "https://ollama.mdes-innova.online"
$ollamaToken = ""
if (Test-Path "$JitRoot\.env") {
    Get-Content "$JitRoot\.env" | ForEach-Object {
        if ($_ -match "^OLLAMA_TOKEN=(.+)$") { $ollamaToken = $Matches[1].Trim() }
        if ($_ -match "^OLLAMA_BASE_URL=(.+)$") { $ollamaBaseUrl = $Matches[1].Trim() }
    }
}
if ($env:OLLAMA_TOKEN) { $ollamaToken = $env:OLLAMA_TOKEN }

try {
    $h = @{}
    if ($ollamaToken) { $h.Authorization = "Bearer $ollamaToken" }
    $cloudTags = Invoke-RestMethod -Uri "$ollamaBaseUrl/api/tags" -Headers $h -TimeoutSec 20
    Add-Pass "MDES cloud online (models=$($cloudTags.models.Count))"
} catch {
    Add-Fail "MDES cloud failed: $($_.Exception.Message)"
}

try {
    $localTags = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/tags" -TimeoutSec 10
    Add-Pass "Ollama local online (models=$($localTags.models.Count))"
} catch {
    Add-Fail "Ollama local failed: $($_.Exception.Message)"
}

Show-Section "2) quick-test-ollama.ps1"
try {
    & powershell -ExecutionPolicy Bypass -File "$JitRoot\scripts\quick-test-ollama.ps1" | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Add-Pass "quick-test-ollama executed"
    } else {
        Add-Fail "quick-test-ollama exit code $LASTEXITCODE"
    }
} catch {
    Add-Fail "quick-test-ollama crashed: $($_.Exception.Message)"
}

Show-Section "3) Multiagent in Jit"
try {
    & node "$JitRoot\hermes-discord\test-multiagent.js"
    if ($LASTEXITCODE -eq 0) {
        Add-Pass "test-multiagent passed"
    } else {
        Add-Fail "test-multiagent exit code $LASTEXITCODE"
    }
} catch {
    Add-Fail "test-multiagent crashed: $($_.Exception.Message)"
}

Show-Section "4) Jit -> innomcp bridge"
try {
    $env:MOTHER_TIMEOUT = "5000"
    & node "$JitRoot\skills\vaja-thai-tts\jit-mother.js" "ทดสอบเชื่อมต่อ innomcp และสรุปไทยสั้นๆ"
    if ($LASTEXITCODE -eq 0) {
        Add-Pass "jit-mother orchestrator ran"
    } else {
        Add-Fail "jit-mother exit code $LASTEXITCODE"
    }
} catch {
    Add-Fail "jit-mother crashed: $($_.Exception.Message)"
}

Show-Section "5) ThaiLLM/OllamaCloud via multi-proxy"
$listener = Get-NetTCPConnection -LocalPort 4322 -State Listen -ErrorAction SilentlyContinue
if ($listener) {
    try {
        Stop-Process -Id $listener.OwningProcess -Force
        Start-Sleep -Milliseconds 500
    } catch {}
}

try {
    $env:PYTHONIOENCODING = "utf-8"
    $env:OLLAMA_TOKEN = $ollamaToken
    $env:OLLAMA_BASE_URL = $ollamaBaseUrl
    Start-Process -FilePath py -ArgumentList "-3 scripts/multi-proxy.py" -WindowStyle Hidden
    Start-Sleep -Seconds 4
    $health = Invoke-RestMethod -Uri "http://127.0.0.1:4322/health" -TimeoutSec 10
    Add-Pass "multi-proxy health ok (available=$($health.available -join ','))"
} catch {
    Add-Fail "multi-proxy health failed: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "RESULTS: $pass PASS | $fail FAIL | $skip SKIP" -ForegroundColor Cyan
if ($fail -gt 0) { exit 1 }

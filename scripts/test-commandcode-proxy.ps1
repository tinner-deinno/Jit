# test-commandcode-proxy.ps1 — Verify the Claude→CommandCode failover proxy end-to-end.
# Runs 6 tests: syntax, health, non-streaming, streaming SSE, count_tokens, claude --print.
param(
    [int]$ProxyPort = 4322,
    [string]$Model = "cc/deepseek/deepseek-v4-flash",
    [switch]$SkipClaude   # skip the full claude CLI test (slowest)
)

$ErrorActionPreference = "Continue"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ProxyUrl = "http://127.0.0.1:$ProxyPort"
$results = @()

function Report($name, $pass, $detail) {
    $script:results += [pscustomobject]@{ Test = $name; Pass = $pass; Detail = $detail }
    $icon = if ($pass) { "✅" } else { "❌" }
    Write-Host "$icon $name — $detail"
}

# ── Test 1: Python syntax ────────────────────────────────────────────
$python = $null
foreach ($c in @("py", "python3", "python")) {
    try { & $c --version *> $null; if ($LASTEXITCODE -eq 0) { $python = $c; break } } catch {}
}
if (-not $python) { Report "1-syntax" $false "no python found"; exit 1 }
& $python -m py_compile (Join-Path $RepoRoot "scripts\multi-proxy.py")
Report "1-syntax" ($LASTEXITCODE -eq 0) "py_compile multi-proxy.py"

# ── Test 2: Health ───────────────────────────────────────────────────
$health = $null
try { $health = Invoke-RestMethod "$ProxyUrl/health" -TimeoutSec 3 } catch {}
if (-not $health) {
    Write-Host "Proxy not running — starting via claude-cmd.ps1 -ProxyOnly ..."
    & (Join-Path $RepoRoot "scripts\claude-cmd.ps1") -ProxyOnly -ProxyPort $ProxyPort
    try { $health = Invoke-RestMethod "$ProxyUrl/health" -TimeoutSec 3 } catch {}
}
$ccRegistered = $health -and $health.available -contains "commandcode"
Report "2-health" ([bool]$health) "status=$($health.status); available=$($health.available -join ',')"
if (-not $ccRegistered) { Write-Warning "commandcode NOT in available backends (COMMANDCODE_API_KEY missing?)" }

# ── Test 3: Non-streaming message ────────────────────────────────────
$body = @{
    model = $Model; max_tokens = 50
    messages = @(@{ role = "user"; content = "Reply with exactly: PROXY_OK" })
} | ConvertTo-Json -Depth 5
try {
    $r = Invoke-RestMethod -Uri "$ProxyUrl/v1/messages" -Method POST `
        -Headers @{ "Content-Type" = "application/json"; "x-api-key" = "multi-proxy" } `
        -Body $body -TimeoutSec 120
    $text = ($r.content | Where-Object { $_.type -eq "text" } | ForEach-Object text) -join ""
    Report "3-nonstream" ($text -match "PROXY_OK") "model=$($r.model); reply=$($text.Substring(0, [Math]::Min(60,$text.Length)))"
} catch {
    Report "3-nonstream" $false "ERROR: $($_.Exception.Message)"
}

# ── Test 4: Streaming SSE ────────────────────────────────────────────
$body = @{
    # reasoning models (deepseek) spend tokens on thinking first — give headroom
    model = $Model; max_tokens = 256; stream = $true
    messages = @(@{ role = "user"; content = "Reply with exactly: STREAM_OK" })
} | ConvertTo-Json -Depth 5
try {
    $resp = Invoke-WebRequest -Uri "$ProxyUrl/v1/messages" -Method POST `
        -Headers @{ "Content-Type" = "application/json"; "x-api-key" = "multi-proxy" } `
        -Body $body -TimeoutSec 120 -UseBasicParsing
    $isSSE   = $resp.Headers["Content-Type"] -match "text/event-stream"
    $events  = ($resp.Content -split "`n" | Where-Object { $_ -match "^event:" } | ForEach-Object { ($_ -replace "^event:\s*", "").Trim() })
    $hasCore = ($events -contains "message_start") -and ($events -contains "content_block_delta") -and ($events -contains "message_stop")
    Report "4-stream" ($isSSE -and $hasCore) "SSE=$isSSE; events=$(($events | Select-Object -Unique) -join ',')"
} catch {
    Report "4-stream" $false "ERROR: $($_.Exception.Message)"
}

# ── Test 5: count_tokens stub ────────────────────────────────────────
$body = @{ model = $Model; messages = @(@{ role = "user"; content = "hello world" }) } | ConvertTo-Json -Depth 5
try {
    $r = Invoke-RestMethod -Uri "$ProxyUrl/v1/messages/count_tokens" -Method POST `
        -Headers @{ "Content-Type" = "application/json"; "x-api-key" = "multi-proxy" } `
        -Body $body -TimeoutSec 10
    Report "5-count-tokens" ($r.input_tokens -ge 1) "input_tokens=$($r.input_tokens)"
} catch {
    Report "5-count-tokens" $false "ERROR: $($_.Exception.Message)"
}

# ── Test 6: Full claude --print via proxy ────────────────────────────
if ($SkipClaude) {
    Report "6-claude-cli" $true "SKIPPED (-SkipClaude)"
} else {
    $env:ANTHROPIC_BASE_URL = $ProxyUrl
    $env:ANTHROPIC_API_KEY  = "multi-proxy"
    try {
        $out = & claude --print "Reply with exactly: CLAUDE_CMD_OK" --model $Model 2>&1 | Out-String
        Report "6-claude-cli" ($out -match "CLAUDE_CMD_OK") "output=$($out.Trim().Substring(0, [Math]::Min(80, $out.Trim().Length)))"
    } catch {
        Report "6-claude-cli" $false "ERROR: $($_.Exception.Message)"
    } finally {
        Remove-Item env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
        Remove-Item env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
    }
}

# ── Summary ──────────────────────────────────────────────────────────
Write-Host ""
$passed = ($results | Where-Object Pass).Count
Write-Host ("═" * 50)
Write-Host "RESULT: $passed/$($results.Count) tests passed"
$results | Format-Table -AutoSize
if ($passed -lt $results.Count) { exit 1 } else { exit 0 }

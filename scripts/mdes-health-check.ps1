# mdes-health-check.ps1 — Daily health check for all mdes.ollama models
#
# Tests each model SEQUENTIALLY (one server, cannot run concurrent heavy inference)
# Writes report to scripts/health-reports/YYYY-MM-DD.md and commits to git
#
# Schedule: run daily via Task Scheduler or cron
#   schtasks /create /tn "mdes-health" /tr "powershell -File C:\Users\admin\Jit\scripts\mdes-health-check.ps1" /sc daily /st 03:00
#
# Usage:
#   .\scripts\mdes-health-check.ps1                    # full check (all models)
#   .\scripts\mdes-health-check.ps1 -Quick             # only fast models (<10B)
#   .\scripts\mdes-health-check.ps1 -Model qwen3.5:9b  # single model test
#   .\scripts\mdes-health-check.ps1 -NoGit             # skip git push

param(
    [switch]$Quick,
    [string]$Model = "",
    [switch]$NoGit,
    [int]$TimeoutPerModel = 300   # 5 minutes per model (single machine, slow inference)
)

$TOKEN   = "9e34679b9d60d8b984005ec46508579c"
$BASE    = "https://ollama.mdes-innova.online"
$REPORT_DIR = "C:\Users\admin\Jit\scripts\health-reports"
$TODAY   = (Get-Date).ToString("yyyy-MM-dd")
$NOW     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
$REPORT  = "$REPORT_DIR\$TODAY.md"

# Models to test — sorted small→large so fast ones confirm server is alive first
$ALL_MODELS = @(
    @{ name="qwen3.5:9b";         size="9b";  type="general";   prompt="Reply with only: pong" },
    @{ name="gemma4:e4b";         size="4b";  type="general";   prompt="Reply with only: pong" },
    @{ name="llama3.1:8b";        size="8b";  type="general";   prompt="Reply with only: pong" },
    @{ name="phi3:medium";        size="14b"; type="general";   prompt="Reply with only: pong" },
    @{ name="gemma3:12b";         size="12b"; type="general";   prompt="Reply with only: pong" },
    @{ name="gemma4:26b";         size="26b"; type="general";   prompt="Reply with only: pong" },
    @{ name="qwen3.5:27b";        size="27b"; type="code";      prompt="def add(a,b): return" },
    @{ name="qwen2.5-coder:32b";  size="32b"; type="code";      prompt="def add(a,b): return" },
    @{ name="deepseek-coder:33b"; size="33b"; type="code";      prompt="def add(a,b): return" },
    @{ name="qwen3-vl:8b";        size="8b";  type="vision";    prompt="Describe: what is 1+1?" },
    @{ name="qwen3-vl:32b";       size="32b"; type="vision";    prompt="Describe: what is 1+1?" }
)

$QUICK_MODELS = $ALL_MODELS | Where-Object { [int]($_.size -replace 'b','') -le 14 }

# ── Select model list ────────────────────────────────────────────────────────
if ($Model) {
    $TEST_MODELS = $ALL_MODELS | Where-Object { $_.name -eq $Model }
    if (-not $TEST_MODELS) {
        $TEST_MODELS = @(@{ name=$Model; size="?"; type="custom"; prompt="Reply: pong" })
    }
} elseif ($Quick) {
    $TEST_MODELS = $QUICK_MODELS
} else {
    $TEST_MODELS = $ALL_MODELS
}

# ── Helper: test one model ───────────────────────────────────────────────────
function Test-Model {
    param($modelName, $prompt, $timeout)

    $body = @{
        model   = $modelName
        messages = @(@{ role="user"; content=$prompt })
        stream  = $false
        options = @{ num_predict=30; temperature=0 }
    } | ConvertTo-Json -Depth 5 -Compress

    $start = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-RestMethod `
            -Uri "$BASE/v1/chat/completions" `
            -Method Post `
            -Headers @{ Authorization="Bearer $TOKEN"; "Content-Type"="application/json" } `
            -Body $body `
            -TimeoutSec $timeout `
            -ErrorAction Stop
        $elapsed = $start.Elapsed.TotalSeconds
        $reply   = ($resp.choices[0].message.content -replace '\s+',' ').Trim()
        if ($reply.Length -gt 60) { $reply = $reply.Substring(0,60) + "..." }
        return @{ ok=$true; elapsed=[Math]::Round($elapsed,1); reply=$reply; error="" }
    } catch {
        $elapsed = $start.Elapsed.TotalSeconds
        $err = $_.Exception.Message -replace '\r?\n',' '
        if ($err.Length -gt 80) { $err = $err.Substring(0,80) }
        return @{ ok=$false; elapsed=[Math]::Round($elapsed,1); reply=""; error=$err }
    }
}

# ── Run checks ───────────────────────────────────────────────────────────────
New-Item -ItemType Directory -Force $REPORT_DIR | Out-Null

Write-Host ""
Write-Host "=== mdes.ollama Daily Health Check ===" -ForegroundColor Magenta
Write-Host "Date    : $NOW" -ForegroundColor Cyan
Write-Host "Models  : $($TEST_MODELS.Count) to test (sequential)" -ForegroundColor Cyan
Write-Host "Timeout : ${TimeoutPerModel}s per model" -ForegroundColor Cyan
Write-Host ""

$results = @()
foreach ($m in $TEST_MODELS) {
    Write-Host "  Testing $($m.name) ($($m.size))..." -NoNewline -ForegroundColor Yellow
    $r = Test-Model -modelName $m.name -prompt $m.prompt -timeout $TimeoutPerModel
    $status = if ($r.ok) { "OK  " } else { "FAIL" }
    $color  = if ($r.ok) { "Green" } else { "Red" }
    Write-Host " [$status] $($r.elapsed)s  $($r.reply)$($r.error)" -ForegroundColor $color
    $results += @{
        name    = $m.name
        size    = $m.size
        type    = $m.type
        ok      = $r.ok
        elapsed = $r.elapsed
        reply   = $r.reply
        error   = $r.error
    }
    # Wait between models — single machine needs cooldown
    if ($TEST_MODELS.Count -gt 1) { Start-Sleep 3 }
}

# ── Write Markdown report ────────────────────────────────────────────────────
$ok_count   = ($results | Where-Object { $_.ok }).Count
$fail_count = ($results | Where-Object { -not $_.ok }).Count
$avg_time   = if ($ok_count -gt 0) { [Math]::Round(($results | Where-Object { $_.ok } | Measure-Object -Property elapsed -Average).Average, 1) } else { 0 }

$md = @"
# mdes.ollama Health Report — $TODAY

**Checked**: $NOW
**Results**: $ok_count OK / $fail_count FAIL / $($results.Count) total
**Avg response** (OK models): ${avg_time}s
**Timeout per model**: ${TimeoutPerModel}s

## Model Status

| Model | Size | Type | Status | Time (s) | Reply / Error |
|-------|------|------|--------|----------|---------------|
"@

foreach ($r in $results) {
    $statusEmoji = if ($r.ok) { "✅ OK" } else { "❌ FAIL" }
    $detail = if ($r.ok) { $r.reply } else { $r.error }
    $md += "`n| $($r.name) | $($r.size) | $($r.type) | $statusEmoji | $($r.elapsed) | $detail |"
}

$md += @"


## Summary

- **Fast models (<12B)**: $(($results | Where-Object { [int]($_.size -replace 'b','') -le 12 -and $_.ok }).Count) OK
- **Medium models (12-20B)**: $(($results | Where-Object { [int]($_.size -replace 'b','') -gt 12 -and [int]($_.size -replace 'b','') -le 20 -and $_.ok }).Count) OK
- **Large models (>20B)**: $(($results | Where-Object { [int]($_.size -replace 'b','') -gt 20 -and $_.ok }).Count) OK

> Note: Single-machine inference — models share GPU/CPU. Run sequentially, not in parallel.
> High timeout ($($TimeoutPerModel)s) needed for large models with cold start.

---
*Generated by: C:\Users\admin\Jit\scripts\mdes-health-check.ps1*
"@

$md | Out-File $REPORT -Encoding UTF8
Write-Host ""
Write-Host "Report saved: $REPORT" -ForegroundColor Green

# ── Git commit + push ────────────────────────────────────────────────────────
if (-not $NoGit) {
    Write-Host ""
    Write-Host "Committing report to git..." -ForegroundColor Cyan
    $gitRoot = "C:\Users\admin\Jit"
    $relPath = "scripts/health-reports/$TODAY.md"

    Set-Location $gitRoot
    git add $relPath 2>&1 | Out-Null
    $msg = "health($TODAY): mdes.ollama check $ok_count/$($results.Count) OK"
    git commit -m $msg 2>&1 | Out-Null
    $pushResult = git push origin jarvis-plus/phase-0 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Pushed: $msg" -ForegroundColor Green
    } else {
        Write-Host "Push failed (commit still local): $pushResult" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Magenta

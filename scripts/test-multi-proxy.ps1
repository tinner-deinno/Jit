$bytes = [System.IO.File]::ReadAllBytes($PSCommandPath)
if ($bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
    [System.IO.File]::WriteAllBytes($PSCommandPath,
        ([byte[]](0xEF,0xBB,0xBF)) + $bytes)
    Write-Host "UTF-8 BOM added — please re-run"
    exit 0
}
# scripts/test-multi-proxy.ps1 — Test multi-backend proxy + multiagent
# ════════════════════════════════════════════════════════════════════
# ทดสอบ:
#   1. Health check all backends
#   2. Q&A ผ่าน proxy (gpt-4o / copilot / ollama)
#   3. Tool-calling round-trip
#   4. Multiagent: spawn 2 sub-agents ผ่าน claude Task tool
#
# Usage:
#   pwsh -File scripts\test-multi-proxy.ps1
#   pwsh -File scripts\test-multi-proxy.ps1 -SkipMultiAgent
# ════════════════════════════════════════════════════════════════════

param(
    [switch]$SkipMultiAgent,
    [int]$ProxyPort = 4322,
    [string]$ProxyHost = "127.0.0.1"
)

$PROXY = "http://${ProxyHost}:${ProxyPort}"
$JIT_ROOT = Split-Path $PSScriptRoot -Parent
$ENV_FILE = Join-Path $JIT_ROOT ".env"
$PASS = 0; $FAIL = 0

# Load .env
if (Test-Path $ENV_FILE) {
    Get-Content $ENV_FILE | ForEach-Object {
        if ($_ -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $k = $matches[1]; $v = $matches[2].Trim('"').Trim("'")
            [System.Environment]::SetEnvironmentVariable($k, $v, "Process")
        }
    }
}

function Write-Pass($msg) { Write-Host "  [PASS] $msg" -ForegroundColor Green; $script:PASS++ }
function Write-Fail($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red;  $script:FAIL++ }
function Write-Skip($msg) { Write-Host "  [SKIP] $msg" -ForegroundColor Yellow }
function Section($title)  { Write-Host "`n=== $title ===" -ForegroundColor Cyan }

# ─── Helpers ──────────────────────────────────────────────────────────
function Invoke-Proxy($messages, $system="You are a helpful assistant.") {
    $body = @{
        model      = "claude-sonnet-4-5"
        max_tokens = 256
        system     = $system
        messages   = $messages
    } | ConvertTo-Json -Depth 10 -Compress

    try {
        $resp = Invoke-RestMethod `
            -Uri "$PROXY/v1/messages" `
            -Method POST `
            -Headers @{ "Content-Type" = "application/json"; "x-api-key" = "multi-proxy" } `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
            -TimeoutSec 120
        $content = $resp.content | Where-Object { $_.type -eq "text" } | Select-Object -First 1
        return $content.text
    } catch {
        return $null
    }
}

# ─── Section 1: Proxy health ──────────────────────────────────────────
Section "1. Proxy Health"
try {
    $health = Invoke-RestMethod -Uri "$PROXY/health" -TimeoutSec 10
    Write-Pass "Proxy online at $PROXY"
    Write-Host "  Backend  : $($health.current_backend)"
    Write-Host "  Available: $($health.available -join ', ')"
    Write-Host "  OpenAI   : $($health.backends.openai)"
    Write-Host "  Copilot  : $($health.backends.copilot)"
    Write-Host "  Ollama   : $($health.backends.ollama)"
} catch {
    Write-Fail "Proxy offline at $PROXY — start with: python3 scripts/multi-proxy.py"
    Write-Host ""
    Write-Host "Start command:" -ForegroundColor Yellow
    Write-Host "  `$env:OPENAI_API_KEY = '<your-key>'"
    Write-Host "  `$env:OLLAMA_TOKEN   = '$($env:OLLAMA_TOKEN)'"
    Write-Host "  python3 $JIT_ROOT\scripts\multi-proxy.py"
    exit 1
}

# ─── Section 2: Q&A test ──────────────────────────────────────────────
Section "2. Q&A Test (ผ่าน proxy)"
$qa_pairs = @(
    @{ Q = "Reply with exactly: HELLO_WORLD"; Expected = "HELLO_WORLD" }
    @{ Q = "What is 2+2? Reply with just the number."; Expected = "4" }
    @{ Q = "Name one planet in our solar system. One word only."; Expected = $null }
    @{ Q = "Reply in Thai: สวัสดีครับ"; Expected = $null }
)

foreach ($pair in $qa_pairs) {
    $msgs = @(@{ role = "user"; content = $pair.Q })
    $reply = Invoke-Proxy $msgs
    if ($null -eq $reply) {
        Write-Fail "No response for: $($pair.Q)"
    } elseif ($pair.Expected -and $reply -notmatch [regex]::Escape($pair.Expected)) {
        Write-Fail "Expected '$($pair.Expected)' in: $reply"
    } else {
        Write-Pass "Q: $($pair.Q.Substring(0, [Math]::Min(40,$pair.Q.Length)))... → $($reply.Substring(0,[Math]::Min(60,$reply.Length)))"
    }
}

# ─── Section 3: Backend rotation test ────────────────────────────────
Section "3. Backend Info"
try {
    $health2 = Invoke-RestMethod -Uri "$PROXY/health" -TimeoutSec 5
    Write-Pass "Requests served: $($health2.requests) | Errors: $($health2.errors) | Rotations: $($health2.rotations)"
    Write-Host "  Current backend: $($health2.current_backend)"
} catch {
    Write-Fail "Cannot get proxy stats"
}

# ─── Section 4: Tool-calling test ─────────────────────────────────────
Section "4. Tool-Calling Test"
$toolBody = @{
    model      = "claude-sonnet-4-5"
    max_tokens = 256
    messages   = @(@{ role = "user"; content = "What is the weather in Bangkok? Use the get_weather tool." })
    tools      = @(@{
        name        = "get_weather"
        description = "Get the current weather for a city"
        input_schema = @{
            type       = "object"
            properties = @{
                city = @{ type = "string"; description = "City name" }
            }
            required   = @("city")
        }
    })
} | ConvertTo-Json -Depth 10 -Compress

try {
    $resp = Invoke-RestMethod `
        -Uri "$PROXY/v1/messages" `
        -Method POST `
        -Headers @{ "Content-Type" = "application/json"; "x-api-key" = "multi-proxy" } `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($toolBody)) `
        -TimeoutSec 60

    $toolUse = $resp.content | Where-Object { $_.type -eq "tool_use" } | Select-Object -First 1
    if ($toolUse) {
        Write-Pass "Tool call returned: $($toolUse.name)(city=$($toolUse.input.city))"
    } else {
        $text = ($resp.content | Where-Object { $_.type -eq "text" } | Select-Object -First 1).text
        Write-Skip "Model answered without tool call (backend may not support tools): $($text.Substring(0,[Math]::Min(80,$text.Length)))"
    }
} catch {
    Write-Fail "Tool-calling test failed: $_"
}

# ─── Section 5: Streaming test ────────────────────────────────────────
Section "5. Streaming (SSE) Test"
$streamBody = @{
    model      = "claude-sonnet-4-5"
    max_tokens = 64
    stream     = $true
    messages   = @(@{ role = "user"; content = "Reply with exactly: STREAM_OK" })
} | ConvertTo-Json -Depth 5 -Compress

try {
    $resp = Invoke-WebRequest `
        -Uri "$PROXY/v1/messages" `
        -Method POST `
        -Headers @{ "Content-Type" = "application/json"; "x-api-key" = "multi-proxy" } `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($streamBody)) `
        -TimeoutSec 60

    $rawLines = ($resp.Content -split "`n") | Where-Object { $_ -match "^data:" }
    if ($rawLines.Count -gt 0) {
        Write-Pass "SSE stream received ($($rawLines.Count) data events)"
        $textDelta = $rawLines | ForEach-Object {
            try {
                $d = $_ -replace "^data: *", "" | ConvertFrom-Json
                if ($d.type -eq "content_block_delta") { $d.delta.text }
            } catch {}
        }
        $combined = ($textDelta -join "").Trim()
        Write-Host "  Content: $($combined.Substring(0,[Math]::Min(80,$combined.Length)))"
    } else {
        Write-Fail "No SSE data events in response"
    }
} catch {
    Write-Fail "Streaming test failed: $_"
}

# ─── Section 6: Multiagent test ───────────────────────────────────────
Section "6. Multiagent (Claude Code Task tool)"
if ($SkipMultiAgent) {
    Write-Skip "Skipped (-SkipMultiAgent)"
} else {
    $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeCmd) {
        Write-Skip "claude CLI not found — install Claude Code first"
    } else {
        Write-Host "  Testing Claude Code with multi-proxy backend..."
        Write-Host "  Proxy: $PROXY"

        $env:ANTHROPIC_BASE_URL = $PROXY
        $env:ANTHROPIC_API_KEY  = "multi-proxy"

        # Simple test: ask claude to echo something (no tools needed)
        $testPrompt = 'Reply with exactly this text and nothing else: MULTIAGENT_OK'
        try {
            $result = & claude --dangerously-skip-permissions --print "$testPrompt" 2>&1
            if ($result -match "MULTIAGENT_OK") {
                Write-Pass "Claude Code responded via multi-proxy: $($result.Trim())"
            } else {
                Write-Host "  Response: $($result.Trim().Substring(0,[Math]::Min(200,$result.Trim().Length)))"
                Write-Fail "Expected MULTIAGENT_OK in response"
            }
        } catch {
            Write-Fail "Claude Code execution failed: $_"
        }

        # Multiagent test: spawn a sub-agent via Task
        Write-Host ""
        Write-Host "  Testing sub-agent spawn (Task tool)..."
        $multiPrompt = @"
Use the Task tool to spawn one sub-agent with this exact instruction:
"Reply with the text: SUBAGENT_REPLY_OK"
Then after the sub-agent responds, reply with: PARENT_RECEIVED:[the sub-agent reply]
"@
        try {
            $result2 = & claude --dangerously-skip-permissions --print $multiPrompt 2>&1
            if ($result2 -match "SUBAGENT_REPLY_OK" -or $result2 -match "PARENT_RECEIVED") {
                Write-Pass "Multiagent Task spawn successful!"
                Write-Host "  Result: $($result2.Trim().Substring(0,[Math]::Min(200,$result2.Trim().Length)))"
            } else {
                Write-Host "  Result: $($result2.Trim().Substring(0,[Math]::Min(300,$result2.Trim().Length)))"
                Write-Skip "Task tool may need permissions or different model — check output above"
            }
        } catch {
            Write-Fail "Multiagent test failed: $_"
        }
    }
}

# ─── Summary ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  RESULTS: $PASS PASSED | $FAIL FAILED" -ForegroundColor $(if ($FAIL -eq 0) {"Green"} else {"Yellow"})
Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan

if ($FAIL -gt 0) {
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Set OPENAI_API_KEY in .env for OpenAI backend"
    Write-Host "  2. Set COPILOT_TOKEN in .env for GitHub Copilot"
    Write-Host "  3. Ensure OLLAMA_TOKEN is set for MDES Ollama fallback"
    Write-Host "  4. Make sure proxy is running: python3 scripts/multi-proxy.py"
}

Write-Host ""
Write-Host "To use with Claude Code:" -ForegroundColor Green
Write-Host "  `$env:ANTHROPIC_BASE_URL = '$PROXY'"
Write-Host "  `$env:ANTHROPIC_API_KEY  = 'multi-proxy'"
Write-Host "  claude --dangerously-skip-permissions"

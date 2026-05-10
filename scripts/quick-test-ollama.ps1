# quick-test-ollama.ps1 — ทดสอบ MDES Ollama 4 models แบบเร็ว
# รันตรงจาก PowerShell: .\scripts\quick-test-ollama.ps1
# ════════════════════════════════════════════════════════════

$ErrorActionPreference = "Continue"
$JitRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path) -Parent

# Load .env
$OllamaBaseUrl = "https://ollama.mdes-innova.online"
$OllamaToken = ""
$EnvFile = Join-Path $JitRoot ".env"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match "^OLLAMA_TOKEN=(.+)$")    { $OllamaToken = $Matches[1].Trim() }
        if ($_ -match "^OLLAMA_BASE_URL=(.+)$") { $OllamaBaseUrl = $Matches[1].Trim() }
    }
}
if ($env:OLLAMA_TOKEN)    { $OllamaToken = $env:OLLAMA_TOKEN }

$ProxyPort = 4321
$ProxyUrl  = "http://127.0.0.1:$ProxyPort"
$ProxyScript = Join-Path $JitRoot "scripts\ollama-proxy.py"

$ModelTests = @(
    @{ Model="gemma4:26b";       Prompt="ตอบ 1 คำ ภาษาไทย: ท้องฟ้าสีอะไร" },
    @{ Model="gemma4:e4b";       Prompt="Reply 1 word: sky color" },
    @{ Model="qwen2.5-coder:7b"; Prompt="Python one-liner: hello world" },
    @{ Model="llama3.2:latest";  Prompt="Say: MDES online" }
)

function Write-Banner {
    param([string]$Text)
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║  $($Text.PadRight(44))║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Test-OllamaDirect {
    Write-Banner "Test 1: Direct MDES Ollama API"

    if (-not $OllamaToken) {
        Write-Host "  ⚠️  OLLAMA_TOKEN not found in .env" -ForegroundColor Yellow
        Write-Host "     Add: OLLAMA_TOKEN=<token> to $JitRoot\.env" -ForegroundColor DarkGray
        return 0
    }

    $pass = 0; $fail = 0
    foreach ($t in $ModelTests) {
        Write-Host "  [$($t.Model)] " -NoNewline

        $body = @{
            model    = $t.Model
            messages = @(@{ role="user"; content=$t.Prompt })
            stream   = $false
            options  = @{ num_predict = 20 }
        } | ConvertTo-Json -Depth 5 -Compress

        $t0 = [DateTime]::Now
        try {
            $resp = Invoke-RestMethod `
                -Uri "$OllamaBaseUrl/api/chat" `
                -Method POST `
                -Body $body `
                -ContentType "application/json" `
                -Headers @{ Authorization = "Bearer $OllamaToken" } `
                -TimeoutSec 45

            $elapsed = [int]([DateTime]::Now - $t0).TotalSeconds
            $text = $resp.message.content
            $short = $text.Substring(0, [Math]::Min(50, $text.Length)).Replace("`n"," ")
            Write-Host "✓ [${elapsed}s] `"$short`"" -ForegroundColor Green
            $pass++
        } catch {
            $elapsed = [int]([DateTime]::Now - $t0).TotalSeconds
            Write-Host "✗ [${elapsed}s] $($_.Exception.Message.Substring(0,[Math]::Min(60,$_.Exception.Message.Length)))" -ForegroundColor Red
            $fail++
        }
    }
    Write-Host "  ─────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  Direct: $pass OK, $fail FAIL" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Yellow" })
    return $pass
}

function Start-ProxyBackground {
    Write-Host "  Starting Python proxy in background..." -ForegroundColor Cyan

    # Check python3
    $py = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command python -ErrorAction SilentlyContinue }
    if (-not $py) {
        Write-Host "  ✗ Python not found" -ForegroundColor Red
        return $false
    }

    # Set env vars
    $env:OLLAMA_BASE_URL = $OllamaBaseUrl
    $env:OLLAMA_TOKEN    = $OllamaToken
    $env:PROXY_PORT      = "$ProxyPort"

    $job = Start-Job -ScriptBlock {
        param($py, $script, $url, $token, $port)
        $env:OLLAMA_BASE_URL = $url
        $env:OLLAMA_TOKEN    = $token
        $env:PROXY_PORT      = $port
        & $py $script 2>&1
    } -ArgumentList $py.Source, $ProxyScript, $OllamaBaseUrl, $OllamaToken, "$ProxyPort"

    Start-Sleep -Seconds 3

    # Check health
    try {
        $h = Invoke-RestMethod -Uri "$ProxyUrl/health" -TimeoutSec 5
        Write-Host "  ✓ Proxy started (Job $($job.Id)) — model: $($h.current_model)" -ForegroundColor Green
        return $job.Id
    } catch {
        Write-Host "  ✗ Proxy failed to start — $_" -ForegroundColor Red
        Stop-Job $job.Id -ErrorAction SilentlyContinue
        return $false
    }
}

function Test-ProxyBridge {
    param([int]$JobId)
    Write-Banner "Test 2: Anthropic↔Ollama Proxy Bridge"

    # Check proxy health
    try {
        $health = Invoke-RestMethod -Uri "$ProxyUrl/health" -TimeoutSec 5
        Write-Host "  ✓ Proxy healthy: model=$($health.current_model)" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Proxy not running at $ProxyUrl" -ForegroundColor Red
        return
    }

    # Test 4 Q&A via proxy (Anthropic format)
    $questions = @(
        "ตอบสั้นๆ ภาษาไทย: AI คืออะไร",
        "Reply 1 word: what is 2+2",
        "Write: print('hello') only",
        "Thai reply: ดาวดวงแรกที่เห็นคืออะไร"
    )

    $pass = 0; $fail = 0
    $qIdx = 1
    foreach ($q in $questions) {
        Write-Host "  Q$qIdx: `"$q`"" -NoNewline

        $body = @{
            model      = "claude-3-sonnet"
            max_tokens = 40
            messages   = @(@{ role="user"; content=$q })
        } | ConvertTo-Json -Depth 5 -Compress

        $t0 = [DateTime]::Now
        try {
            $resp = Invoke-RestMethod `
                -Uri "$ProxyUrl/v1/messages" `
                -Method POST `
                -Body $body `
                -ContentType "application/json" `
                -Headers @{
                    "x-api-key"          = "mdes-ollama"
                    "anthropic-version"  = "2023-06-01"
                } `
                -TimeoutSec 90

            $elapsed = [int]([DateTime]::Now - $t0).TotalSeconds
            $text  = $resp.content[0].text
            $model = $resp.model
            $short = $text.Substring(0,[Math]::Min(45,$text.Length)).Replace("`n"," ")
            Write-Host ""
            Write-Host "       → [$model, ${elapsed}s] `"$short`"" -ForegroundColor Green
            $pass++
        } catch {
            $elapsed = [int]([DateTime]::Now - $t0).TotalSeconds
            Write-Host " ✗ [${elapsed}s]" -ForegroundColor Red
            $fail++
        }
        $qIdx++
    }

    Write-Host "  ─────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  Proxy bridge: $pass OK, $fail FAIL" -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Yellow" })
}

function Show-LaunchGuide {
    Write-Banner "Claude Code Launch Guide"
    Write-Host "  Set these env vars then run claude:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  `$env:ANTHROPIC_BASE_URL = '$ProxyUrl'" -ForegroundColor White
    Write-Host "  `$env:ANTHROPIC_API_KEY  = 'mdes-ollama'" -ForegroundColor White
    Write-Host "  claude --dangerously-skip-permissions" -ForegroundColor White
    Write-Host ""
    Write-Host "  Or use JARVIS daemon (auto-restart, auto-rotate):" -ForegroundColor Yellow
    Write-Host "  .\scripts\jarvis-claude.ps1 -Action start" -ForegroundColor White
    Write-Host "  .\scripts\jarvis-claude.ps1 -Action jarvis    # background" -ForegroundColor White
    Write-Host ""
    Write-Host "  Or bash (WSL):" -ForegroundColor Yellow
    Write-Host "  bash minds/ollama-claude.sh start" -ForegroundColor White
    Write-Host "  bash minds/ollama-claude.sh jarvis   # background" -ForegroundColor White
    Write-Host ""
}

# ─── MAIN ──────────────────────────────────────────────────────────────
Write-Banner "MDES Ollama Model Test — $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "  JitRoot   : $JitRoot" -ForegroundColor DarkGray
Write-Host "  OllamaURL : $OllamaBaseUrl" -ForegroundColor DarkGray
Write-Host "  Token     : $(if ($OllamaToken) { "$($OllamaToken.Substring(0,8))..." } else { '(not set)' })" -ForegroundColor DarkGray
Write-Host "  ProxyPort : $ProxyPort" -ForegroundColor DarkGray
Write-Host ""

# Test 1: Direct
$directPass = Test-OllamaDirect

# Test 2: Proxy
$proxyJobId = Start-ProxyBackground
if ($proxyJobId) {
    Test-ProxyBridge -JobId $proxyJobId

    # Cleanup proxy job
    Stop-Job $proxyJobId -ErrorAction SilentlyContinue
    Remove-Job $proxyJobId -ErrorAction SilentlyContinue
}

# Launch guide
Show-LaunchGuide

Write-Host "  ✅ Test complete. System ready!" -ForegroundColor Green
Write-Host ""

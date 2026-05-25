$ErrorActionPreference = "Continue"
$JitRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path) -Parent

$OllamaBaseUrl = "https://ollama.mdes-innova.online"
$OllamaToken = ""
$EnvFile = Join-Path $JitRoot ".env"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match "^OLLAMA_TOKEN=(.+)$") { $OllamaToken = $Matches[1].Trim() }
        if ($_ -match "^OLLAMA_BASE_URL=(.+)$") { $OllamaBaseUrl = $Matches[1].Trim() }
    }
}
if ($env:OLLAMA_TOKEN) { $OllamaToken = $env:OLLAMA_TOKEN }

$ProxyPort = 4321
$ProxyUrl = "http://127.0.0.1:$ProxyPort"
$ProxyScript = Join-Path $JitRoot "scripts\ollama-proxy.py"

$ModelTests = @(
    @{ Model = "gemma4:26b"; Prompt = "Reply one word: sky color" },
    @{ Model = "gemma4:e4b"; Prompt = "Reply one word: cloud color" },
    @{ Model = "qwen2.5-coder:7b"; Prompt = "Python one-liner hello world" },
    @{ Model = "llama3.2:latest"; Prompt = "Say: MDES online" }
)

function Write-Banner {
    param([string]$Text)
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
}

function Get-PythonCommand {
    if (Get-Command py -ErrorAction SilentlyContinue) {
        return @{ File = "py"; Args = @("-3") }
    }
    if (Get-Command python3 -ErrorAction SilentlyContinue) {
        return @{ File = "python3"; Args = @() }
    }
    if (Get-Command python -ErrorAction SilentlyContinue) {
        return @{ File = "python"; Args = @() }
    }
    return $null
}

function Test-OllamaDirect {
    Write-Banner "Test 1: Direct MDES Ollama API"
    if (-not $OllamaToken) {
        Write-Host "OLLAMA_TOKEN not set; skip direct cloud chat test." -ForegroundColor Yellow
        return 0
    }

    $pass = 0
    $fail = 0
    foreach ($t in $ModelTests) {
        Write-Host "[$($t.Model)] " -NoNewline
        $body = @{
            model = $t.Model
            messages = @(@{ role = "user"; content = $t.Prompt })
            stream = $false
            options = @{ num_predict = 20 }
        } | ConvertTo-Json -Depth 5 -Compress

        $t0 = Get-Date
        try {
            $resp = Invoke-RestMethod -Uri "$OllamaBaseUrl/api/chat" -Method POST -Body $body -ContentType "application/json" -Headers @{ Authorization = "Bearer $OllamaToken" } -TimeoutSec 45
            $elapsed = [int]((Get-Date) - $t0).TotalSeconds
            $text = [string]$resp.message.content
            $short = $text.Substring(0, [Math]::Min(50, $text.Length)).Replace("`n", " ")
            Write-Host "OK (${elapsed}s) `"$short`"" -ForegroundColor Green
            $pass++
        } catch {
            $elapsed = [int]((Get-Date) - $t0).TotalSeconds
            Write-Host "FAIL (${elapsed}s) $($_.Exception.Message)" -ForegroundColor Red
            $fail++
        }
    }
    Write-Host "Direct summary: $pass OK, $fail FAIL" -ForegroundColor DarkGray
    return $pass
}

function Start-ProxyBackground {
    Write-Host "Starting proxy in background..." -ForegroundColor Cyan
    $pyCmd = Get-PythonCommand
    if (-not $pyCmd) {
        Write-Host "Python not found." -ForegroundColor Red
        return $false
    }

    $env:OLLAMA_BASE_URL = $OllamaBaseUrl
    $env:OLLAMA_TOKEN = $OllamaToken
    $env:PROXY_PORT = "$ProxyPort"
    $env:PYTHONIOENCODING = "utf-8"

    $job = Start-Job -ScriptBlock {
        param($pyFile, $pyArgs, $script, $url, $token, $port)
        $env:OLLAMA_BASE_URL = $url
        $env:OLLAMA_TOKEN = $token
        $env:PROXY_PORT = $port
        $env:PYTHONIOENCODING = "utf-8"
        & $pyFile @pyArgs $script 2>&1
    } -ArgumentList $pyCmd.File, $pyCmd.Args, $ProxyScript, $OllamaBaseUrl, $OllamaToken, "$ProxyPort"

    Start-Sleep -Seconds 3
    try {
        $h = Invoke-RestMethod -Uri "$ProxyUrl/health" -TimeoutSec 5
        Write-Host "Proxy started (job=$($job.Id), model=$($h.current_model))" -ForegroundColor Green
        return $job.Id
    } catch {
        Write-Host "Proxy startup failed: $($_.Exception.Message)" -ForegroundColor Red
        Stop-Job $job.Id -ErrorAction SilentlyContinue
        return $false
    }
}

function Test-ProxyBridge {
    Write-Banner "Test 2: Proxy Bridge"
    try {
        $health = Invoke-RestMethod -Uri "$ProxyUrl/health" -TimeoutSec 5
        Write-Host "Proxy healthy: model=$($health.current_model)" -ForegroundColor Green
    } catch {
        Write-Host "Proxy not running at $ProxyUrl" -ForegroundColor Red
        return
    }

    $questions = @(
        "Reply short: what is AI",
        "Reply one word: 2+2",
        "Write: print('hello') only"
    )

    $pass = 0
    $fail = 0
    foreach ($q in $questions) {
        Write-Host "Q: $q ... " -NoNewline
        $body = @{
            model = "claude-3-sonnet"
            max_tokens = 40
            messages = @(@{ role = "user"; content = $q })
        } | ConvertTo-Json -Depth 5 -Compress

        try {
            $resp = Invoke-RestMethod -Uri "$ProxyUrl/v1/messages" -Method POST -Body $body -ContentType "application/json" -Headers @{ "x-api-key" = "mdes-ollama"; "anthropic-version" = "2023-06-01" } -TimeoutSec 90
            $text = [string]$resp.content[0].text
            Write-Host "OK `"$($text.Substring(0, [Math]::Min(45, $text.Length)))`"" -ForegroundColor Green
            $pass++
        } catch {
            Write-Host "FAIL" -ForegroundColor Red
            $fail++
        }
    }
    Write-Host "Proxy summary: $pass OK, $fail FAIL" -ForegroundColor DarkGray
}

Write-Banner "MDES Ollama Quick Test - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "JitRoot:   $JitRoot" -ForegroundColor DarkGray
Write-Host "OllamaURL: $OllamaBaseUrl" -ForegroundColor DarkGray
Write-Host "TokenSet:  $([bool]$OllamaToken)" -ForegroundColor DarkGray
Write-Host "ProxyPort: $ProxyPort" -ForegroundColor DarkGray

$null = Test-OllamaDirect
$proxyJobId = Start-ProxyBackground
if ($proxyJobId) {
    Test-ProxyBridge
    Stop-Job $proxyJobId -ErrorAction SilentlyContinue
    Remove-Job $proxyJobId -ErrorAction SilentlyContinue
}

Write-Host "Quick test complete." -ForegroundColor Green

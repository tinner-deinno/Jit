param(
  [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Checks = [System.Collections.Generic.List[object]]::new()

function Add-Check {
  param(
    [string]$Name,
    [string]$State,
    [string]$Evidence,
    [bool]$Critical = $true,
    [object]$Details = $null
  )
  $Checks.Add([pscustomobject]@{
    name = $Name
    state = $State
    critical = $Critical
    evidence = $Evidence
    details = $Details
  }) | Out-Null
}

function Invoke-Tool {
  param(
    [string]$File,
    [string[]]$Arguments = @(),
    [string]$WorkingDirectory = $Root
  )
  $previous = Get-Location
  try {
    Set-Location $WorkingDirectory
    $output = & $File @Arguments 2>&1
    $code = if ($null -eq $global:LASTEXITCODE) { 0 } else { $global:LASTEXITCODE }
    return [pscustomobject]@{
      ok = ($code -eq 0)
      code = $code
      text = (($output | Select-Object -First 8) -join "`n").Trim()
    }
  } catch {
    return [pscustomobject]@{ ok = $false; code = 1; text = $_.Exception.Message }
  } finally {
    Set-Location $previous
  }
}

function Test-CommandVersion {
  param(
    [string]$Name,
    [string[]]$Arguments = @("--version"),
    [bool]$Critical = $true
  )
  $cmd = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Add-Check $Name "offline" "not on PATH" $Critical
    return
  }
  $result = Invoke-Tool $cmd.Source $Arguments
  $state = if ($result.ok) { "ready" } else { "degraded" }
  Add-Check $Name $state $result.text $Critical @{ path = $cmd.Source; exitCode = $result.code }
}

function Test-PathAny {
  param(
    [string]$Name,
    [string[]]$Candidates,
    [bool]$Critical = $true
  )
  $existing = @($Candidates | Where-Object { $_ -and (Test-Path $_) })
  if ($existing.Count -gt 0) {
    Add-Check $Name "ready" $existing[0] $Critical @{ candidates = $Candidates; existing = $existing }
  } else {
    Add-Check $Name "offline" "missing all candidates" $Critical @{ candidates = $Candidates }
  }
}

function Test-HttpHead {
  param(
    [string]$Name,
    [string]$Url,
    [bool]$Critical = $false
  )
  try {
    $request = [System.Net.WebRequest]::Create($Url)
    $request.Method = "GET"
    $request.Timeout = 2500
    $response = $request.GetResponse()
    try {
      Add-Check $Name "ready" "$Url status $([int]$response.StatusCode)" $Critical
    } finally {
      $response.Dispose()
    }
  } catch {
    Add-Check $Name "degraded" "$Url $($_.Exception.Message)" $Critical
  }
}

Test-CommandVersion "codex"
Test-CommandVersion "claude"
Test-CommandVersion "bun"
Test-CommandVersion "node"
Test-CommandVersion "git"
Test-CommandVersion "tmux" @("-V")
Test-CommandVersion "wsl" @("tmux", "-V") $false
Test-CommandVersion "py" @("--version") $false

$PsiRoot = Join-Path $Root ([char]0x03C8)
Test-PathAny "psi-memory" @($PsiRoot, (Join-Path $Root "psi"))

$skillsCliRoot = "C:\Users\USER-NT\DEV\arra-oracle-skills-cli"
$skillsCli = Join-Path $skillsCliRoot "src\cli\index.ts"
if ((Test-Path $skillsCli) -and (Get-Command bun -ErrorAction SilentlyContinue)) {
  $version = Invoke-Tool "bun" @("--bun", $skillsCli, "--version") $skillsCliRoot
  $state = if ($version.ok) { "ready" } else { "degraded" }
  Add-Check "arra-oracle-skills-cli" $state $version.text $true @{ root = $skillsCliRoot; source = $skillsCli }
} else {
  Add-Check "arra-oracle-skills-cli" "offline" "source cli or bun missing" $true @{ root = $skillsCliRoot; source = $skillsCli }
}
Test-PathAny "awaken-skill" @("C:\Users\USER-NT\.claude\skills\awaken\SKILL.md", "C:\Users\USER-NT\.codex\skills\awaken\SKILL.md")

$mawRoot = "C:\Users\USER-NT\DEV\maw-js"
$mawCli = Join-Path $mawRoot "src\cli.ts"
if ((Test-Path $mawCli) -and (Get-Command bun -ErrorAction SilentlyContinue)) {
  $mawVersion = Invoke-Tool "bun" @("--bun", $mawCli, "--version") $mawRoot
  $state = if ($mawVersion.ok) { "ready" } else { "degraded" }
  Add-Check "maw-js-cli" $state $mawVersion.text $true @{ root = $mawRoot; source = $mawCli }
} else {
  Add-Check "maw-js-cli" "offline" "source cli or bun missing" $true @{ root = $mawRoot; source = $mawCli }
}
Test-PathAny "maw-global-shim" @("C:\Users\USER-NT\.bun\bin\maw.exe", "C:\Users\USER-NT\.bun\bin\maw.bunx") $false

Test-PathAny "oracle-source" @(
  "C:\Users\USER-NT\DEV\arra-oracle-v3",
  "C:\Users\USER-NT\DEV\oracle-v2",
  "/workspaces/arra-oracle-v3"
)
Test-HttpHead "oracle-health" "http://127.0.0.1:47778/api/health" $false
Test-HttpHead "innova-bot-sse-7010" "http://127.0.0.1:7010/sse" $false
Test-HttpHead "innova-bot-sse-7012" "http://127.0.0.1:7012/sse" $false

$router = Invoke-Tool "node" @("-e", "const r=require('./hermes-discord/model-router'); const s=r.status(); console.log(JSON.stringify({primary:s.primary,order:s.order,cloud:s.backends.ollama_cloud,openclaude:s.backends.openclaude}));") $Root
$routerState = if ($router.ok) { "ready" } else { "degraded" }
Add-Check "model-router-status" $routerState $router.text $true

$hardFailures = @($Checks | Where-Object { $_.critical -and $_.state -eq "offline" })
$report = [pscustomobject]@{
  generatedAt = (Get-Date).ToUniversalTime().ToString("o")
  root = $Root
  ok = ($hardFailures.Count -eq 0)
  hardFailures = @($hardFailures | ForEach-Object { $_.name })
  checks = $Checks
}

if ($Json) {
  $report | ConvertTo-Json -Depth 8
} else {
  $Checks | Format-Table name, state, critical, evidence -AutoSize
  if ($report.ok) {
    Write-Host "oracle-readiness: no critical offline checks"
  } else {
    Write-Host ("oracle-readiness: critical offline checks: " + ($report.hardFailures -join ", "))
  }
}

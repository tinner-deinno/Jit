param(
  [int] $IntervalSeconds = 300,
  [int] $Count = 84,
  [int] $Concurrency = 8,
  [int] $AdvisorThreshold = 8,
  [double] $MaxHours = 0,
  [switch] $Once,
  [switch] $DryRun,
  [switch] $Help
)

$ErrorActionPreference = "Stop"
if ($Help) {
  Write-Host "Usage: powershell -File scripts\start-innova-loop.ps1 [-IntervalSeconds 300] [-Count 84] [-Concurrency 8] [-AdvisorThreshold 8] [-MaxHours 5] [-Once] [-DryRun]"
  exit 0
}

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LoopDir = Join-Path $Root "network\loop"
$PidFile = Join-Path $LoopDir "innova-loop.pid"
$LogFile = Join-Path $LoopDir "innova-loop.log"
New-Item -ItemType Directory -Force -Path $LoopDir | Out-Null

if (Test-Path $PidFile) {
  $existing = (Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
  if ($existing -and (Get-Process -Id ([int]$existing) -ErrorAction SilentlyContinue)) {
    Write-Host "innova loop already running pid=$existing log=$LogFile"
    exit 0
  }
}

$argsList = @(
  "eval\innova-loop-controller.js",
  "--interval-ms", ([string]($IntervalSeconds * 1000)),
  "--count", ([string]$Count),
  "--concurrency", ([string]$Concurrency),
  "--advisor-threshold", ([string]$AdvisorThreshold)
)
if ($Once) { $argsList += "--once" }
if ($DryRun) { $argsList += "--dry-run" }
if ($MaxHours -gt 0) {
  $maxRuntimeMs = [long][math]::Round($MaxHours * 3600 * 1000)
  $argsList += @("--max-runtime-ms", ([string]$maxRuntimeMs))
}

$cmd = "Set-Location '$Root'; node $($argsList -join ' ') *> '$LogFile'"
$p = Start-Process powershell -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd) -WindowStyle Hidden -PassThru
Set-Content -Path $PidFile -Value $p.Id
Write-Host "innova loop started pid=$($p.Id) interval=${IntervalSeconds}s count=$Count concurrency=$Concurrency maxHours=$MaxHours log=$LogFile"

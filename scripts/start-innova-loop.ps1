param(
  [int] $IntervalSeconds = 300,
  [int] $Count = 56,
  [int] $Concurrency = 6,
  [int] $AdvisorThreshold = 8,
  [switch] $Once,
  [switch] $DryRun,
  [switch] $Help
)

$ErrorActionPreference = "Stop"
if ($Help) {
  Write-Host "Usage: powershell -File scripts\start-innova-loop.ps1 [-IntervalSeconds 300] [-Count 56] [-Concurrency 6] [-AdvisorThreshold 8] [-Once] [-DryRun]"
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

$cmd = "Set-Location '$Root'; node $($argsList -join ' ') *> '$LogFile'"
$p = Start-Process powershell -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd) -WindowStyle Hidden -PassThru
Set-Content -Path $PidFile -Value $p.Id
Write-Host "innova loop started pid=$($p.Id) interval=${IntervalSeconds}s count=$Count concurrency=$Concurrency log=$LogFile"

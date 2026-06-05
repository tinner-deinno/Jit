param(
  [int] $IntervalSeconds = 240,
  [double] $MaxHours = 0,
  [switch] $Once,
  [switch] $Help
)

$ErrorActionPreference = "Stop"
if ($Help) {
  Write-Host "Usage: powershell -File scripts\start-innova-talk-loop.ps1 [-IntervalSeconds 240] [-MaxHours 5] [-Once]"
  exit 0
}

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LoopDir = Join-Path $Root "network\loop"
$PidFile = Join-Path $LoopDir "innova-talk-loop.pid"
$LogFile = Join-Path $LoopDir "innova-talk-loop.log"
New-Item -ItemType Directory -Force -Path $LoopDir | Out-Null

if (Test-Path $PidFile) {
  $existing = (Get-Content $PidFile -ErrorAction SilentlyContinue | Select-Object -First 1)
  if ($existing -and (Get-Process -Id ([int]$existing) -ErrorAction SilentlyContinue)) {
    Write-Host "innova talk loop already running pid=$existing log=$LogFile"
    exit 0
  }
}

$argsList = @(
  "eval\innova-talk-loop.js",
  "--interval-ms", ([string]($IntervalSeconds * 1000))
)
if ($Once) { $argsList += "--once" }
if ($MaxHours -gt 0) {
  $maxRuntimeMs = [long][math]::Round($MaxHours * 3600 * 1000)
  $argsList += @("--max-runtime-ms", ([string]$maxRuntimeMs))
}

$cmd = "Set-Location '$Root'; node $($argsList -join ' ') *> '$LogFile'"
$p = Start-Process powershell -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd) -WindowStyle Hidden -PassThru
Set-Content -Path $PidFile -Value $p.Id
Write-Host "innova talk loop started pid=$($p.Id) interval=${IntervalSeconds}s maxHours=$MaxHours log=$LogFile"

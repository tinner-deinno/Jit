$ErrorActionPreference = "SilentlyContinue"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LoopDir = Join-Path $Root "network\loop"
$PidFile = Join-Path $LoopDir "innova-loop.pid"

if (!(Test-Path $PidFile)) {
  Write-Host "innova loop is not running (no pid file)"
  exit 0
}

$pidText = (Get-Content $PidFile | Select-Object -First 1)
if ($pidText) {
  Stop-Process -Id ([int]$pidText) -Force
  Write-Host "stopped innova loop pid=$pidText"
}
Remove-Item $PidFile -Force

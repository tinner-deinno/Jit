$ErrorActionPreference = "SilentlyContinue"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$LoopDir = Join-Path $Root "network\loop"
$PidFile = Join-Path $LoopDir "innova-talk-loop.pid"

function Get-DescendantProcessIds {
  param([int]$RootPid)

  $all = Get-CimInstance Win32_Process
  $childrenByParent = @{}
  foreach ($proc in $all) {
    $parent = [int]$proc.ParentProcessId
    if (!$childrenByParent.ContainsKey($parent)) {
      $childrenByParent[$parent] = New-Object System.Collections.Generic.List[int]
    }
    [void]$childrenByParent[$parent].Add([int]$proc.ProcessId)
  }

  $descendants = New-Object System.Collections.Generic.List[int]
  $queue = New-Object System.Collections.Queue
  $queue.Enqueue($RootPid)

  while ($queue.Count -gt 0) {
    $current = [int]$queue.Dequeue()
    if (!$childrenByParent.ContainsKey($current)) {
      continue
    }
    foreach ($childPid in $childrenByParent[$current]) {
      [void]$descendants.Add([int]$childPid)
      $queue.Enqueue([int]$childPid)
    }
  }

  return $descendants.ToArray()
}

function Stop-ProcessTree {
  param([int]$RootPid)

  $ids = @(Get-DescendantProcessIds -RootPid $RootPid) + @($RootPid)
  [array]::Reverse($ids)

  foreach ($id in $ids) {
    if ($id -eq $PID) {
      continue
    }
    Stop-Process -Id $id -Force -ErrorAction SilentlyContinue
  }

  return $ids.Count
}

if (!(Test-Path $PidFile)) {
  Write-Host "innova talk loop is not running (no pid file)"
  exit 0
}

$pidText = (Get-Content $PidFile | Select-Object -First 1)
if ($pidText) {
  $stoppedCount = Stop-ProcessTree -RootPid ([int]$pidText)
  Write-Host "stopped innova talk loop pid=$pidText process_count=$stoppedCount"
}
Remove-Item $PidFile -Force

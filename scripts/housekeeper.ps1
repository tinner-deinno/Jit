# scripts/housekeeper.ps1 - Jit Oracle Housekeeping (Windows)
# ================================================
# Windows-native version of housekeeper.sh
# Use with Windows Task Scheduler or run directly.
#
# Usage:
#   PowerShell -File scripts\housekeeper.ps1
#   PowerShell -File scripts\housekeeper.ps1 -DryRun
#   PowerShell -File scripts\housekeeper.ps1 -StatusOnly
# ================================================

param(
    [switch]$DryRun,
    [switch]$StatusOnly
)

$ErrorActionPreference = "SilentlyContinue"

# Config
$JitRoot     = Split-Path -Parent $PSScriptRoot
$OutboxDir   = Join-Path $JitRoot "ps\outbox"
$InboxDir    = Join-Path $JitRoot "ps\inbox"
$ArchiveBase = Join-Path $JitRoot "ps\archive"
$LogFile     = Join-Path $JitRoot "ps\memory\logs\housekeeper.log"
$RetainDays  = if ($env:HOUSEKEEPER_RETAIN_DAYS) { [int]$env:HOUSEKEEPER_RETAIN_DAYS } else { 7 }
$InboxRetain = if ($env:HOUSEKEEPER_INBOX_RETAIN) { [int]$env:HOUSEKEEPER_INBOX_RETAIN } else { 30 }
$OutboxMax   = if ($env:HOUSEKEEPER_OUTBOX_MAX) { [int]$env:HOUSEKEEPER_OUTBOX_MAX } else { 100 }

# Resolve psi (Unicode ps directory)
$psiUnicode = Join-Path $JitRoot ([char]0x03C8)  # Unicode psi character
if (Test-Path $psiUnicode) {
    $OutboxDir   = Join-Path $psiUnicode "outbox"
    $InboxDir    = Join-Path $psiUnicode "inbox"
    $ArchiveBase = Join-Path $psiUnicode "archive"
    $LogFile     = Join-Path $psiUnicode "memory\logs\housekeeper.log"
}

# Logger
function Write-Log {
    param([string]$Msg)
    $ts = Get-Date -Format "yyyy-MM-ddTHH:mm:ss"
    $line = "[$ts] HOUSEKEEPER: $Msg"
    Write-Host $line
    $dir = Split-Path $LogFile -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

Write-Host ""
Write-Host "=================================================="
Write-Host "  Jit Housekeeper - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host "=================================================="

# Status display
function Show-Status {
    Write-Host ""
    Write-Host "-- psi/outbox/ --"
    if (Test-Path $OutboxDir) {
        $cycleFiles = Get-ChildItem $OutboxDir -Filter "*jit-mother-loop-cycle-*.md" -File
        $oldFiles = $cycleFiles | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetainDays) }
        Write-Host "  Total cycle files: $($cycleFiles.Count)"
        Write-Host "  Older than ${RetainDays}d: $($oldFiles.Count)"
    } else { Write-Host "  (not found)" }

    Write-Host ""
    Write-Host "-- psi/inbox/ --"
    if (Test-Path $InboxDir) {
        $inboxFiles = Get-ChildItem $InboxDir -File
        $oldInbox = $inboxFiles | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$InboxRetain) }
        Write-Host "  Total files: $($inboxFiles.Count)"
        Write-Host "  Older than ${InboxRetain}d: $($oldInbox.Count)"
    } else { Write-Host "  (not found)" }

    Write-Host ""
    Write-Host "-- psi/archive/ --"
    if (Test-Path $ArchiveBase) {
        $archTotal = (Get-ChildItem $ArchiveBase -Recurse -File).Count
        Write-Host "  Total archived files: $archTotal"
    } else { Write-Host "  (empty)" }

    Write-Host ""
    Write-Host "-- Root stray check --"
    $psiStray = Join-Path $JitRoot "psi"
    if (Test-Path $psiStray) {
        Write-Host "  WARN: Stray psi/ directory found (should be psi-unicode/)"
    } else {
        Write-Host "  OK: no stray psi/ directory"
    }
    $mdCount = (Get-ChildItem $JitRoot -Filter "*.md" -File).Count
    Write-Host "  Root .md count: $mdCount"
    Write-Host ""
}

if ($StatusOnly) { Show-Status; exit 0 }

Show-Status

if ($DryRun) {
    Write-Host "  *** DRY-RUN MODE - no files will be moved ***"
    Write-Host ""
}

Write-Log "=== housekeeper run START (DryRun=$DryRun) ==="

# Archive outbox cycle files
function Archive-Outbox {
    if (-not (Test-Path $OutboxDir)) { Write-Log "outbox dir not found, skipping"; return }

    $today = Get-Date -Format "yyyy-MM-dd"
    $archiveDir = Join-Path $ArchiveBase "outbox\$today"

    $allCycleFiles = Get-ChildItem $OutboxDir -Filter "*jit-mother-loop-cycle-*.md" -File |
        Sort-Object Name
    $oldByAge = $allCycleFiles | Where-Object {
        $_.LastWriteTime -lt (Get-Date).AddDays(-$RetainDays)
    }

    # Enforce max count
    $toArchive = @($oldByAge)
    if ($allCycleFiles.Count -gt $OutboxMax) {
        $excess = $allCycleFiles.Count - $OutboxMax
        Write-Log "outbox count $($allCycleFiles.Count) > max $OutboxMax - forcing archive of $excess oldest"
        $forceArchive = $allCycleFiles | Select-Object -First $excess
        $combined = @($toArchive) + @($forceArchive)
        $toArchive = $combined | Sort-Object Name -Unique
    }

    if ($toArchive.Count -eq 0) {
        Write-Log "outbox: nothing to archive ($($allCycleFiles.Count) files, all fresh)"
        return
    }

    Write-Log "outbox: archiving $($toArchive.Count) files -> $archiveDir"

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Would archive $($toArchive.Count) outbox files"
        return
    }

    New-Item -ItemType Directory -Force $archiveDir | Out-Null
    $moved = 0
    foreach ($f in $toArchive) {
        $dest = Join-Path $archiveDir $f.Name
        if (-not (Test-Path $dest)) {
            Move-Item -LiteralPath $f.FullName -Destination $dest -Force
            $moved++
        } else {
            Remove-Item -LiteralPath $f.FullName -Force
        }
    }
    Write-Log "outbox: archived $moved files"
}

# Archive old inbox messages (flat files only, not handoff/ subdir)
function Archive-Inbox {
    if (-not (Test-Path $InboxDir)) { Write-Log "inbox dir not found, skipping"; return }

    $today = Get-Date -Format "yyyy-MM-dd"
    $archiveDir = Join-Path $ArchiveBase "inbox\$today"

    $oldFiles = Get-ChildItem $InboxDir -File |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$InboxRetain) }

    if ($oldFiles.Count -eq 0) {
        Write-Log "inbox: nothing to archive"
        return
    }

    Write-Log "inbox: archiving $($oldFiles.Count) files older than ${InboxRetain}d -> $archiveDir"

    if ($DryRun) {
        Write-Host "  [DRY-RUN] Would archive $($oldFiles.Count) inbox files"
        return
    }

    New-Item -ItemType Directory -Force $archiveDir | Out-Null
    $moved = 0
    foreach ($f in $oldFiles) {
        $dest = Join-Path $archiveDir $f.Name
        Move-Item -LiteralPath $f.FullName -Destination $dest -Force
        $moved++
    }
    Write-Log "inbox: archived $moved files"
}

# Stray directory check and auto-heal
function Check-StrayDirs {
    $found = 0

    # psi/ - created by bash path bug when Unicode psi fails on Windows
    $psiStray = Join-Path $JitRoot "psi"
    if (Test-Path $psiStray) {
        $found++
        Write-Log "WARN: stray psi/ directory found - merging into Unicode psi dir"
        if ($DryRun) {
            Write-Host "  [DRY-RUN] Would merge psi/ -> Unicode psi/ and remove"
        } else {
            $psiCanon = $psiUnicode
            if (Test-Path $psiCanon) {
                Get-ChildItem $psiStray -Recurse -File | ForEach-Object {
                    $rel = $_.FullName.Substring($psiStray.Length + 1)
                    $dest = Join-Path $psiCanon $rel
                    $destDir = Split-Path $dest -Parent
                    if (-not (Test-Path $destDir)) {
                        New-Item -ItemType Directory -Force $destDir | Out-Null
                    }
                    if (-not (Test-Path $dest)) {
                        Move-Item -LiteralPath $_.FullName -Destination $dest -Force
                        Write-Log "healed: psi/$rel -> psi-unicode/$rel"
                    }
                }
            }
            Remove-Item -Recurse -Force $psiStray
            Write-Log "stray psi/ removed"
        }
    }

    if ($found -eq 0) { Write-Log "stray check: clean" }
}

# Trim log to prevent unbounded growth
function Trim-Log {
    if (Test-Path $LogFile) {
        $lines = Get-Content $LogFile
        if ($lines.Count -gt 500) {
            $trimmed = $lines | Select-Object -Last 400
            $trimmed | Set-Content $LogFile -Encoding UTF8
            Write-Log "housekeeper log trimmed to 400 lines"
        }
    }
}

# Run all tasks
Archive-Outbox
Archive-Inbox
Check-StrayDirs
Trim-Log

Write-Log "=== housekeeper run DONE ==="
Write-Host ""
Write-Host "  Done. Log: $LogFile"
Write-Host ""

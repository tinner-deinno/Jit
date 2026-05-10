<#
    .SYNOPSIS
        Windows Bootstrap for Jit Agent
        Setup local proxy, aliases, and environment for Remote Ollama.
#>

$JitRoot = Get-Item "$PSScriptRoot\.."
$ProfilePath = $PROFILE.CurrentUserAllHosts

Write-Host "`n🚀 Bootstrapping Jit Agent (Windows Version)" -ForegroundColor Cyan
Write-Host "==========================================`n"

# 1. Setup Execution Policy
Write-Host "[1/4] Checking Execution Policy..." -ForegroundColor Gray
if ((Get-ExecutionPolicy) -match "Restricted") {
    Write-Host "⚠️ Setting Execution Policy to RemoteSigned..." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
} else {
    Write-Host "✅ Policy is OK." -ForegroundColor Green
}

# 2. Setup Alias in Profile
Write-Host "`n[2/4] Setting up 'ollama' alias..." -ForegroundColor Gray
$TargetScript = "$($JitRoot.FullName)\ollama.ps1"
if (-not (Test-Path $TargetScript)) {
    # If not in Jit/ root, maybe it's in the current home?
    $TargetScript = "$HOME\ollama.ps1"
}

if (Test-Path $TargetScript) {
    $AliasLine = "`nSet-Alias -Name ollama -Value `"$TargetScript`" -Scope Global -Force"
    
    if (-not (Test-Path (Split-Path $ProfilePath))) {
        New-Item -Path (Split-Path $ProfilePath) -ItemType Directory -Force | Out-Null
    }
    
    if (-not (Test-Path $ProfilePath)) {
        New-Item -ItemType File -Path $ProfilePath -Force | Out-Null
    }
    
    $CurrentProfile = Get-Content $ProfilePath -ErrorAction SilentlyContinue
    if ($CurrentProfile -notmatch "Set-Alias -Name ollama") {
        Add-Content -Path $ProfilePath -Value $AliasLine
        Write-Host "✅ Alias 'ollama' added to your PowerShell Profile!" -ForegroundColor Green
        Write-Host "💡 Note: Please restart your terminal or run '. `$PROFILE' to apply." -ForegroundColor Cyan
    } else {
        Write-Host "✅ Alias 'ollama' already exists in profile." -ForegroundColor Green
    }
    # Set it for current session too
    Set-Alias -Name ollama -Value "$TargetScript" -Scope Global -Force
} else {
    Write-Host "❌ Could not find ollama.ps1 at $TargetScript" -ForegroundColor Red
}

# 3. Check for Claude Code
Write-Host "`n[3/4] Verifying Claude Code..." -ForegroundColor Gray
if (Get-Command "claude" -ErrorAction SilentlyContinue) {
    Write-Host "✅ Claude Code is installed." -ForegroundColor Green
} else {
    Write-Host "⚠️ Claude Code not found. You might need to run: npm install -g @anthropic-ai/claude-code" -ForegroundColor Yellow
}

# 4. Final Instructions
Write-Host "`n[4/4] Setup Complete!" -ForegroundColor Green
Write-Host "------------------------------------------"
Write-Host "To start working, you can now run:" -ForegroundColor White
Write-Host "  ollama spawn jit . --model gemma4:26b" -ForegroundColor Cyan
Write-Host "  ollama spawn javis C:\path\to\innova-bot --model qwen3.5:9b" -ForegroundColor Cyan
Write-Host "------------------------------------------`n"

# start-mdes-proxy.ps1 — Launch litellm proxy for mdes.ollama → Claude Code
#
# After running this, open a NEW terminal and run:
#   $env:ANTHROPIC_BASE_URL = "http://localhost:4000"
#   $env:ANTHROPIC_API_KEY  = "mdes-proxy-key"
#   claude
#
# Models mapped:
#   claude-sonnet-4-6  → qwen3.5:9b      (fast, Thai+code)
#   claude-opus-4-7    → qwen2.5-coder:32b (heavy code)
#   claude-haiku-4-5   → gemma4:e4b       (light tasks)

$scriptDir = Split-Path $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir "litellm-mdes-proxy.yaml"

Write-Host ""
Write-Host "=== mdes.ollama → Claude Code Proxy ===" -ForegroundColor Magenta
Write-Host "Port: 4000" -ForegroundColor Cyan
Write-Host "Config: $configPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "After proxy starts, open NEW terminal:" -ForegroundColor Yellow
Write-Host '  $env:ANTHROPIC_BASE_URL = "http://localhost:4000"' -ForegroundColor Green
Write-Host '  $env:ANTHROPIC_API_KEY  = "mdes-proxy-key"' -ForegroundColor Green
Write-Host "  claude" -ForegroundColor Green
Write-Host ""

litellm --config $configPath --port 4000

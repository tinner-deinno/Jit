# openclaude-mdes.ps1 — Launch OpenClaude with mdes.ollama backend
#
# Usage:
#   .\scripts\openclaude-mdes.ps1              # default: qwen3.5:9b (fast)
#   .\scripts\openclaude-mdes.ps1 -Model code  # qwen2.5-coder:32b (heavy code)
#   .\scripts\openclaude-mdes.ps1 -Model deep  # deepseek-coder:33b
#
# Available mdes.ollama models:
#   qwen3.5:9b          — fast, Thai+EN, good all-round
#   qwen3.5:27b         — smarter, slower
#   qwen2.5-coder:32b   — best for code generation
#   deepseek-coder:33b  — deep code analysis
#   gemma4:26b          — balanced, Thai support

param(
    [ValidateSet("fast","code","deep","smart","vision")]
    [string]$Model = "fast"
)

$models = @{
    fast   = "qwen3.5:9b"
    smart  = "qwen3.5:27b"
    code   = "qwen2.5-coder:32b"
    deep   = "deepseek-coder:33b"
    vision = "qwen3-vl:8b"
}

$chosenModel = $models[$Model]

Write-Host ""
Write-Host "=== OpenClaude + mdes.ollama ===" -ForegroundColor Magenta
Write-Host "  Backend : https://ollama.mdes-innova.online/v1" -ForegroundColor Cyan
Write-Host "  Model   : $chosenModel  (profile: $Model)" -ForegroundColor Cyan
Write-Host ""

$env:OPENAI_BASE_URL = "https://ollama.mdes-innova.online/v1"
$env:OPENAI_API_KEY  = "9e34679b9d60d8b984005ec46508579c"
$env:OPENAI_MODEL    = $chosenModel

openclaude

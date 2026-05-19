# voice/tts_interceptor.ps1 — Windows SAPI TTS for Jit Oracle
# Speaks Thai (and any language) using Windows Speech Synthesis.
# Optionally translates English→Thai via Ollama.mdes first.
#
# Usage:
#   .\voice\tts_interceptor.ps1 -Text "สวัสดี"
#   .\voice\tts_interceptor.ps1 -Text "สวัสดี" -Voice female
#   .\voice\tts_interceptor.ps1 -Text "Hello world" -Translate
#   echo "สวัสดีครับ" | powershell -File .\voice\tts_interceptor.ps1
#
# VoiceGender: Male=1, Female=2 (Windows SAPI enum)

param(
    [string]$Text = "",
    [ValidateSet("male", "female")]
    [string]$Voice = "male",
    [ValidateRange(-10, 10)]
    [int]$Rate = 0,
    [ValidateRange(0, 100)]
    [int]$Volume = 85,
    [switch]$Translate
)

# ── Read from stdin if no -Text ─────────────────────────────────────────────
if (-not $Text -and $MyInvocation.ExpectingInput) {
    $Text = $input | Out-String
    $Text = $Text.Trim()
}
if (-not $Text) {
    Write-Error "No text provided. Use -Text 'ข้อความ' or pipe via stdin."
    exit 1
}

# ── Optional Ollama translation (English → Thai) ────────────────────────────
if ($Translate) {
    $token = $env:OLLAMA_TOKEN
    if (-not $token) {
        $envPath = Join-Path (Split-Path $PSScriptRoot) ".env"
        if (Test-Path $envPath) {
            Get-Content $envPath | ForEach-Object {
                if ($_ -match "^OLLAMA_TOKEN=(.+)$") { $token = $Matches[1].Trim() }
            }
        }
    }
    if ($token) {
        try {
            $body = @{
                model    = "gemma4:26b"
                messages = @(@{
                    role    = "user"
                    content = "แปลข้อความต่อไปนี้เป็นภาษาไทยที่เป็นธรรมชาติ กระชับ พูดได้เลย:`n${Text}`nแปลเป็นภาษาไทย:"
                })
                stream   = $false
            } | ConvertTo-Json -Depth 5 -Compress
            $resp = Invoke-RestMethod `
                -Uri "https://ollama.mdes-innova.online/api/chat" `
                -Method Post `
                -Headers @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" } `
                -Body $body -TimeoutSec 30 -ErrorAction SilentlyContinue
            $translated = $resp.message.content.Trim()
            if ($translated) {
                Write-Host "[TTS] Translated: $($translated.Substring(0, [Math]::Min(60, $translated.Length)))..." -ForegroundColor DarkGray
                $Text = $translated
            }
        } catch {
            Write-Warning "[TTS] Ollama translation failed — speaking original text"
        }
    } else {
        Write-Warning "[TTS] No OLLAMA_TOKEN found — skipping translation"
    }
}

# ── Windows SAPI Speech ─────────────────────────────────────────────────────
Add-Type -AssemblyName System.Speech

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer

# VoiceGender enum: Male=1, Female=2
$genderInt = if ($Voice -eq "female") { 2 } else { 1 }
$synth.SelectVoiceByHints($genderInt)
$synth.Rate   = $Rate
$synth.Volume = $Volume

$preview = $Text.Substring(0, [Math]::Min(60, $Text.Length))
Write-Host "[TTS] Speaking ($Voice, rate=$Rate, vol=$Volume): $preview..." -ForegroundColor Cyan

$synth.Speak($Text)
Write-Host "[TTS] Done." -ForegroundColor Green

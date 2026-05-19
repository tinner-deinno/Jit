# voice/test-voice.ps1 — Test Jit Oracle voice greeting
# Speaks "สวัสดี" in male voice via Windows SAPI
#
# Usage: powershell -ExecutionPolicy Bypass -File voice\test-voice.ps1

Write-Host "`n=== Jit Oracle Voice Test ===" -ForegroundColor Magenta

$scriptPath = Join-Path $PSScriptRoot "tts_interceptor.ps1"

Write-Host "`n[Test 1] Male voice — Thai greeting" -ForegroundColor Yellow
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -Text "สวัสดีครับ ผมคือ Jit Oracle ยินดีที่ได้พบคุณ" `
    -Voice male -Rate 0 -Volume 85

Write-Host "`n[Test 2] Male voice — system ready announcement" -ForegroundColor Yellow
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
    -Text "ระบบ innova พร้อมทำงานแล้ว" `
    -Voice male -Rate 1 -Volume 85

Write-Host "`n=== Test complete ===" -ForegroundColor Magenta

<#
    .SYNOPSIS
        MDES Gang Launcher - ปลุกกองทัพ Agents สุมหัวทำงาน
        ควบคุมโดย Jit / สั่งการผ่าน Codex / ทำงานโดย Ollama Remote
#>

param (
    [string]$Action = "status" # auto, start, stop, status
)

$JitRoot = Get-Item "$PSScriptRoot\.."
$Wrapper = "$JitRoot\ollama.ps1"

Write-Host "`n🎭 MDES Gang: กองทัพ Agents คนชั้นกลาง" -ForegroundColor Magenta
Write-Host "========================================`n"

function Start-Agent($name, $path, $model) {
    Write-Host "🚀 ปลุก Agent: [$name] (ใช้ $model)..." -ForegroundColor Cyan
    & $Wrapper spawn $name $path --model $model --dangerously-skip-permissions
}

switch ($Action) {
    "auto" {
        # 1. 🧮 Planner (จอมวางแผน) - ใช้ตัวฉลาดสุด
        Start-Agent "innomcp-planner" "$JitRoot" "gemma4:26b"
        
        # 2. 💻 Coder (นักเขียนโค้ด) - ใช้ตัวที่เขียนโค้ดเก่ง
        Start-Agent "innomcp-coder" "C:\Users\admin\DEV\innomcp" "qwen2.5-coder:32b"
        
        # 3. 🧪 Tester (นักตรวจสอบ) - ใช้ตัวเร็วๆ
        Start-Agent "innomcp-tester" "C:\Users\admin\DEV\innomcp" "qwen3.5:9b"
        
        Write-Host "`n✅ กองทัพพร้อมรบ! ส่งงานผ่าน Codex ได้เลย" -ForegroundColor Green
    }
    
    "status" {
        Write-Host "🔍 กำลังตรวจชีพจรของทีม..." -ForegroundColor Gray
        & $Wrapper ps
    }
    
    "stop" {
        Write-Host "💤 กล่อมกองทัพเข้านอน..." -ForegroundColor Yellow
        Get-Process "ollama" -ErrorAction SilentlyContinue | Stop-Process -Force
    }
}

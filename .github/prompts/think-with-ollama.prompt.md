---
name: think-with-ollama
description: "ส่งโจทย์ให้ MDES Ollama (gemma4:26b) ช่วยคิด — สำหรับงานสร้างสรรค์ภาษาไทย"
argument-hint: "โจทย์ที่ต้องการให้ Ollama ช่วย"
---

ใช้ MDES Ollama เป็นแขนขาคิดเรื่องนี้:

โจทย์: {{args}}

กรุณา:
1. ส่ง prompt ไปที่ MDES Ollama:
   ```bash
   curl -s --location 'https://ollama.mdes-innova.online/api/generate' \
     --header 'Authorization: Bearer ${OLLAMA_TOKEN}' \
     --header 'Content-Type: application/json' \
     --data '{"model":"gemma4:26b","prompt":"<prompt>","stream":false}'
   ```
2. แสดง response ที่ได้
3. สรุปและเพิ่ม perspective ของตัวเอง (สมอง Copilot)

# RBAC Matrix สำหรับ Jit Secrets/Tokens

## หลักการ (Principles)

- **Least Privilege**: ให้ token มีสิทธิ์น้อยที่สุดที่จำเป็นสำหรับการทำงานเท่านั้น  
- **Service Accounts แยกตาม Organ**: ควรใช้บัญชีบริการและ token แยกกันตามหน่วยงาน/สคริปต์ เพื่อจำกัดขอบเขตการเข้าถึง  
- **Rotation**: เจ้าของ token ต้องหมุนเวียน key ตามรอบเวลาที่กำหนด

## ตาราง RBAC

| Token | ใคร/อะไรที่ใช้ได้ (Organ/Script/CI) | Least-Privilege Scope | Rotation Owner |
|-------|--------------------------------------|-----------------------|----------------|
| OLLAMA_TOKEN | Organ A, Script X, CI pipeline main | อ่าน/เขียนเฉพาะโมเดล OLLAMA ที่กำหนด | ทีม Infrastructure |
| COMMANDCODE_API_KEY | Organ B, Script Y, CI pipeline dev | อ่าน/execute เฉพาะโปรเจกต์ commandcode | ทีม Developer |
| THAILLM_TOKEN | Organ C, Script Z, CI pipeline staging | อ่านเฉพาะ endpoint THAILLM แบบจำกัดคำขอ | ทีม AI/ML |
| DISCORD_TOKEN | Organ A (bot service), Script A-discord | ส่งข้อความใน channel ที่กำหนดเท่านั้น | ทีม Operations |
| CODEX_API_KEY | Organ D, CI pipeline production | อ่าน/เขียนเฉพาะ workspace codex ที่ระบุ | ทีม Security |
| GitHub PAT | Organ E, Script automate-release | สิทธิ์ repo scope: contents:write, metadata:read | ทีม Release |

**หมายเหตุ**: ควรตรวจสอบสิทธิ์ทุกครั้งก่อน deploy และหมุน token ทุก 90 วันหรือเมื่อมีเหตุการณ์ด้านความปลอดภัย

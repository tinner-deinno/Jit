<!-- cc-team deliverable
 group: MEGA (56-task parallel burn across innomcp + Jit)
 member: F04 role=dev model=commandcode/deepseek/deepseek-v4-flash
 finish_reason: end_turn | tokens: {"prompt_tokens":111,"completion_tokens":904,"total_tokens":1015} | 12s
 generated: 2026-06-12T19:30:33.467Z -->
# เอกสารความปลอดภัยของซัพพลายเชนสำหรับ Monorepo

## 1. บทเรียนจากความเสี่ยง `npx -y` / dependency ที่ไม่ pinned

การใช้ `npx -y` หรือระบุ dependency แบบไม่ระบุรุ่น (unpinned) ทำให้ระบบดึงเวอร์ชันล่าสุดโดยไม่มีการตรวจสอบ ซึ่งอาจนำไปสู่การโจมตีแบบ supply chain (เช่น dependency confusion, malicious package) **บทเรียน**: ห้ามใช้ `npx -y` ในสคริปต์อัตโนมัติ ต้องระบุเวอร์ชันเสมอ

## 2. กลยุทธ์การ pinning

- ทุก package ใน `package.json` ต้องระบุรุ่นแน่นอน (exact version) หลีกเลี่ยง range (`^`, `~`)
- ใช้ `package-lock.json` หรือ `yarn.lock` / `pnpm-lock.yaml` ในการล็อก dependency tree ทั้งหมด
- ใช้เครื่องมืออย่าง `npm shrinkwrap` หรือ `renovate` ในการจัดการอัปเดตด้วยความระมัดระวัง

## 3. การสร้าง SBOM (Software Bill of Materials)

- **ด้วย npm sbom**: `npm sbom --all` (npm ≥ 10) สร้าง CycloneDX JSON
- **ด้วย Syft**: `syft packages dir:. -o cyclonedx-json` สำหรับรายละเอียดเพิ่มเติม
- เก็บ SBOM ไว้ใน repo หรือ CI artifact เพื่อใช้ตรวจสอบภายหลัง

## 4. การสแกน dependency

- **Trivy**:  `trivy fs . --scanners vuln` ตรวจจับช่องโหว่ใน dependency
- **Snyk**: `snyk test --all-projects` สำหรับต่อเนื่องกับ CI
- **npm audit**: `npm audit --audit-level=high` ใช้เป็นเกตก่อน commit ได้
- ควรสแกนทุกครั้งก่อน merge หรือใน pipeline CI

## 5. ความเสี่ยงจากการสร้างเนื้อหาด้วย LLM แบบ bulk (MEGA-100)

`MEGA-100` หมายถึงการที่ LLM ถูกใช้สร้างโค้ด/ข้อมูลจำนวนมากโดยไม่ตรวจสอบความถูกต้อง อาจเกิด fence corruption (เช่น การแทรกโค้ดที่เป็นอันตราย, prompt injection) **การป้องกัน**:
- จำกัดจำนวนโค้ดที่ LLM สร้างต่อครั้ง
- ตรวจสอบ output ทุกครั้งด้วย human review
- ใช้ sandbox ในการรันโค้ดที่สร้างจาก LLM

## 6. การบังคับใช้ `tsc` gate ก่อน commit

ก่อน commit ทุกครั้ง ต้องรัน TypeScript compiler (`tsc --noEmit`) โดยตั้งเป็น pre-commit hook (husky/lint-staged) เพื่อป้องกันไม่ให้โค้ดที่มี type error เข้า repo ซึ่งอาจทำให้เกิดช่องโหว่จากการตีความผิด

## 7. การยืนยันว่า artifact ที่อ้างอิงโดย agent มีอยู่จริง

ก่อนที่ agent (script, CI, หรือระบบอัตโนมัติ) จะใช้ artifact (เช่น npm package, binary, certificate) ต้องตรวจสอบ:
- Hash หรือ checksum (SHA256) ตรงกับที่ประกาศ
- ไฟล์นั้นมีอยู่จริงในระบบหรือ registry ที่เชื่อถือได้
- ใช้ `npm cache verify` หรือการลงชื่อด้วย GPG

---

**หมายเหตุ**: ปฏิบัติตามเอกสารนี้ในทุกขั้นตอนของ CI/CD และในการพัฒนา เพื่อลดความเสี่ยงจากการโจมตี supply chain

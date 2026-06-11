# oracle-prism (nazt gist) Learning Index

## Source
- **Origin**: ./origin/
- **Gist**: https://gist.github.com/nazt/ce8065ae5da53371287ca92bd1a3b2ab
- **Content**: SKILL.md เดียว (130 บรรทัด) — skill definition `/oracle-prism`

## Explorations

### 2026-06-11 14:33 (direct read — ไฟล์เดียว ไม่ต้อง fan out)
- [Architecture](2026-06-11/1433_ARCHITECTURE.md)
- [Quick Reference](2026-06-11/1433_QUICK-REFERENCE.md)

**Key insights**:
1. **Prismatic ≠ Adversarial** — แสงเดียวผ่านปริซึมแตกหลายสี: ข้อเท็จจริงชุดเดียว มองด้วยคำถามต่างกัน ไม่ใช่พยายามหักล้าง
2. **Zero subagents by design** — agent เดียว transform ตามลำดับ = เครื่องมือ multi-perspective ที่เบาที่สุด (เทียบ /adversarial-analysis ที่ใช้ 5 subagents)
3. **Lenses ขัดแย้งกันได้และต้องแสดง** — ห้าม harmonize ความเห็นต่าง นี่คือ feature ไม่ใช่ bug
4. **4 presets**: default (5 lens), retro, design, incident — ครอบคลุม use case หลักของ retrospective/review
5. **ติดตั้งแล้วเป็น `/oracle-prism`** ใน ~/.claude/skills (2026-06-11)

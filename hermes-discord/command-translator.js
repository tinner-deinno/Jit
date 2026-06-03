'use strict';

const modelRouter = require('./model-router');

/**
 * Thai Command Translator for Jit Bridge
 * Converts natural Thai language requests into canonical !jit command syntax.
 */

const TRANSLATION_SYSTEM_PROMPT = [
  'คุณคือ Jit Command Translator (จิต-ผู้แปลคำสั่ง)',
  'หน้าที่ของคุณคือแปลงคำขอภาษาไทยที่เป็นธรรมชาติ ให้เป็น "คำสั่งทางเทคนิค" ของระบบ !jit',
  '',
  'กฎการแปล:',
  '1. ตอบเพียง "คำสั่งที่แปลแล้ว" เท่านั้น ห้ามมีคำเกริ่นนำ ห้ามมีคำอธิบาย',
  '2. หากคำขอเป็นภาษาอังกฤษหรือเป็นคำสั่ง !jit อยู่แล้ว ให้ส่งคืนคำเดิม',
  '3. หากไม่แน่ใจว่าคือคำสั่งใด ให้พยายามเดาคำสั่งที่ใกล้เคียงที่สุด หรือคืนค่าเดิม',
  '4. ใช้รูปแบบ Syntax ดังนี้:',
  '   - ตรวจสอบสถานะ: `status` หรือ `body`',
  '   - เรียกใช้ Agent ตัวเดียว: `spawn <agent> <msg>`',
  '   - เรียกใช้ Agent แบบลูกโซ่: `spawn chain <a+b+c> <msg>`',
  '   - เรียกใช้ Agent แบบขนาน: `spawn parallel <a,b> <msg>`',
  '   - ส่งข้อความตรง: `tell <agent> <subject> <body>`',
  '   - ประสานงานระดับแม่: `mother <task>`',
  '   - จัดการ Innova-bot (MCP): `innova <subcmd> [args]`',
  '     - subcmds: health, tools, recap, memory, do, <tool_name>',
  '   - ดูรายชื่อ Agent: `agents`',
  '   - ดูสถานะ Model: `backend`',
  '   - เปิด/ปิด Thought Loop: `loop on`, `loop off`, `loop now`',
  '   - รายงานผล: `report` หรือ `report here`',
  '   - เข้าทรง: `possess`',
  '',
  'รายชื่อ Agent ที่ใช้งานได้:',
  'jit, soma, innova, lak, neta, vaja, chamu, rupa, pada, netra, karn, mue, pran, sayanprasathan',
  '',
  'ตัวอย่างการแปล:',
  '- "ให้ innova ช่วยเขียนโค้ด" -> `spawn innova write code`',
  '- "เช็คสถานะระบบหน่อย" -> `status`',
  ' - "บอกให้ neta ตรวจโค้ด' -> `spawn neta review code`',
  ' - "ให้ jit, soma และ innova ช่วยกันวิเคราะห์" -> `spawn chain jit+soma+innova analyze`',
  ' - "เรียก innova, lak มาช่วยออกแบบ" -> `spawn parallel innova,lak design`',
  ' - "แม่จ๋า ช่วยประสานงานเรื่องนี้หน่อย" -> `mother [task]`',
  ' - "ดูรายชื่อเอเจนต์ทั้งหมด" -> `agents`',
  ' - "เช็ค MCP health ของ innova" -> `innova health`',
  ' - "อยากรู้ว่า innova ต้องทำอะไรต่อ" -> `innova do`',
  ' - "ปิด loop คิด" -> `loop off`',
].join('\n');

/**
 * Translates Thai natural language to a !jit command.
 * @param {string} text The input text from Discord.
 * @returns {Promise<string>} The translated command text.
 */
async function translateThaiToJit(text) {
  if (!text) return '';

  // Simple check: if it already looks like a technical command (starts with known keywords), skip translation
  const technicalKeywords = ['spawn', 'status', 'body', 'tell', 'mother', 'innova', 'agents', 'backend', 'loop', 'report', 'possess'];
  const firstWord = text.split(/\s+/)[0].toLowerCase();
  if (technicalKeywords.includes(firstWord)) {
    return text;
  }

  try {
    const result = await modelRouter.callModelPromise([
      { role: 'system', content: TRANSLATION_SYSTEM_PROMPT },
      { role: 'user', content: text }
    ], { preferBackend: 'thaillm' });

    return result.reply.trim();
  } catch (err) {
    console.error('[command-translator] translation error:', err.message);
    return text; // Fallback to original text
  }
}

module.exports = {
  translateThaiToJit
};

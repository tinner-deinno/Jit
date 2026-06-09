/**
 * Thai Syllable Splitter (Deterministic)
 * Part of Project Jit's Routing Optimization (TICKET-006a)
 *
 * Purpose: To provide a consistent, deterministic canonical form of Thai text
 * before it is routed to different LLM backends, reducing routing variance.
 */

const THAI_VOWELS = ['ะ', 'า', 'ิ', 'ี', 'ึ', 'ื', 'ุ', 'ู', 'เ', 'แ', 'โ', 'ใ', 'ไ', 'อ', 'อำ'];
const THAI_CONSONANTS = ['ก', 'ข', 'ค', 'ง', 'จ', 'ฉ', 'ช', 'ซ', 'ฌ', 'ญ', 'ฎ', 'ฏ', 'ฐ', 'ฑ', 'ฒ', 'ณ', 'ด', 'ต', 'ถ', 'ท', 'ธ', 'น', 'บ', 'ป', 'ผ', 'ฝ', 'พ', 'ฟ', 'ภ', 'ม', 'ย', 'ร', 'ล', 'ว', 'ศ', 'ษ', 'ส', 'ห', 'ฬ', 'อ', 'ฮ'];

function splitThaiSyllables(text) {
    if (!text) return [];

    // NFC-normalize at entry point so that combining marks in non-canonical
    // order (e.g. tone-mark before below-vowel) produce the same output as
    // their canonically-ordered equivalents.  This is the fix for the
    // SA Design Review gap (2026-06-08): "NFC Normalization Gap".
    let normalized = String(text).normalize('NFC');

    // TICKET-017: Strip zero-width characters (ZWS, ZWNJ, ZWJ) to ensure
    // routing key stability regardless of whether the input contains hidden
    // formatting characters. These characters don't affect visual output but
    // can change hash keys if not normalized away.
    // Pattern: U+200B (ZWS), U+200C (ZWNJ), U+200D (ZWJ)
    normalized = normalized.replace(/[​‌‍]/g, '');

    // Simple deterministic split: current implementation uses a regex-based
    // heuristic for syllable boundaries to avoid tokenization variance.
    // This is a seed implementation to be refined by the CommandCode fleet.
    const result = normalized.split(/([ก-ฮ][ะ-ู]+|[ก-ฮ]{2,})/);
    return result.filter(s => s.trim().length > 0);
}

module.exports = { splitThaiSyllables };

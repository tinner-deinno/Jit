#!/usr/bin/env node
/**
 * Thai Test Corpus 010 — Expansion Validator
 *
 * Validates the expanded 50-phrase corpus for:
 * - Uniqueness and completeness
 * - Backend distribution
 * - Syllable count variety
 * - Tone mark coverage
 * - Zero-width character safety
 * - JSON format compliance
 *
 * Usage: node validate-expanded-corpus-010.js [--corpus path/to/corpus.json]
 */

'use strict';

const fs = require('fs');
const path = require('path');

// ============================================================================
// Configuration
// ============================================================================

const REQUIRED_FIELDS = [
  'id',
  'phrase',
  'syllables',
  'syllable_count',
  'tone_marks',
  'contains_zero_width',
  'backend_index',
  'backend_name',
  'reason'
];

const EXPECTED_BACKENDS = [
  'ollama_mdes',
  'thaillm',
  'commandcode',
  'ollama_local',
  'ollama_cloud',
  'copilot',
  'openai',
  'openclaude',
  'innova_bot'
];

const ZERO_WIDTH_CHARS = [
  '​', // ZWSP
  '‌', // ZWNJ
  '‍', // ZWJ
  '﻿'  // BOM/ZWNBSP
];

// ============================================================================
// Validator Class
// ============================================================================

class CorpusValidator {
  constructor(corpusPath) {
    this.corpusPath = corpusPath;
    this.corpus = null;
    this.results = {
      passed: 0,
      failed: 0,
      warnings: 0,
      checks: []
    };
  }

  // ========================================================================
  // Main Validation Flow
  // ========================================================================

  async validate() {
    console.log('Thai Test Corpus 010 — Expansion Validator');
    console.log('==========================================\n');

    try {
      this.loadCorpus();
      this.checkFileStructure();
      this.checkSize();
      this.checkUniqueness();
      this.checkBackendDistribution();
      this.checkSyllableVariety();
      this.checkToneMarks();
      this.checkZeroWidthSafety();
      this.checkJSONFormat();
      this.checkSyllableCount();
      this.generateReport();
    } catch (error) {
      console.error(`FATAL ERROR: ${error.message}`);
      process.exit(1);
    }
  }

  // ========================================================================
  // Load Corpus
  // ========================================================================

  loadCorpus() {
    try {
      const data = fs.readFileSync(this.corpusPath, 'utf-8');
      this.corpus = JSON.parse(data);
      this.recordCheck('Load Corpus', true, `Loaded ${this.corpus.length} phrases`);
    } catch (error) {
      throw new Error(`Failed to load corpus: ${error.message}`);
    }
  }

  // ========================================================================
  // Check 1: File Structure
  // ========================================================================

  checkFileStructure() {
    const result = Array.isArray(this.corpus);
    this.recordCheck(
      'File Structure (JSON array)',
      result,
      result ? 'Valid JSON array' : 'Not a valid JSON array'
    );
  }

  // ========================================================================
  // Check 2: Corpus Size
  // ========================================================================

  checkSize() {
    const expected = 50;
    const actual = this.corpus.length;
    const result = actual === expected;

    this.recordCheck(
      'Corpus Size (50 phrases)',
      result,
      `${actual}/${expected} phrases found`
    );
  }

  // ========================================================================
  // Check 3: Uniqueness
  // ========================================================================

  checkUniqueness() {
    const ids = this.corpus.map(e => e.id);
    const phrases = this.corpus.map(e => e.phrase);
    const uniqueIds = new Set(ids).size;
    const uniquePhrases = new Set(phrases).size;

    const idsUnique = uniqueIds === this.corpus.length;
    const phrasesUnique = uniquePhrases === this.corpus.length;

    this.recordCheck(
      'Unique IDs',
      idsUnique,
      `${uniqueIds}/${this.corpus.length} unique IDs`
    );

    this.recordCheck(
      'Unique Phrases',
      phrasesUnique,
      `${uniquePhrases}/${this.corpus.length} unique phrases`
    );

    // Check ID format
    const idRegex = /^TH-010-\d{3}$/;
    const validIds = ids.every(id => idRegex.test(id));
    this.recordCheck(
      'ID Format (TH-010-NNN)',
      validIds,
      validIds ? 'All IDs follow correct format' : 'Some IDs have invalid format'
    );
  }

  // ========================================================================
  // Check 4: Backend Distribution
  // ========================================================================

  checkBackendDistribution() {
    const distribution = {};
    EXPECTED_BACKENDS.forEach(b => distribution[b] = 0);

    this.corpus.forEach(entry => {
      if (distribution.hasOwnProperty(entry.backend_name)) {
        distribution[entry.backend_name]++;
      }
    });

    const result = EXPECTED_BACKENDS.every(b => distribution[b] > 0);
    const summary = Object.entries(distribution)
      .map(([name, count]) => `${name}: ${count}`)
      .join(' | ');

    this.recordCheck(
      'Backend Coverage (9/9 backends)',
      result,
      summary
    );

    // Check distribution balance
    const counts = Object.values(distribution);
    const min = Math.min(...counts);
    const max = Math.max(...counts);
    const balanced = max - min <= 2;

    this.recordCheck(
      'Distribution Balance (±2)',
      balanced,
      `Min: ${min}, Max: ${max}, Range: ${max - min}`
    );
  }

  // ========================================================================
  // Check 5: Syllable Variety
  // ========================================================================

  checkSyllableVariety() {
    const syllableCounts = {};
    this.corpus.forEach(entry => {
      const count = entry.syllable_count;
      syllableCounts[count] = (syllableCounts[count] || 0) + 1;
    });

    const variety = Object.keys(syllableCounts).length;
    const minVariety = 4; // Expect at least 1, 2, 3, 4+ syllables

    const result = variety >= minVariety;
    const summary = Object.entries(syllableCounts)
      .map(([count, freq]) => `${count} syl: ${freq}`)
      .join(' | ');

    this.recordCheck(
      'Syllable Variety (4+ different lengths)',
      result,
      `${variety} different lengths | ${summary}`
    );

    // Check ranges
    const max = Math.max(...Object.keys(syllableCounts).map(Number));
    this.recordCheck(
      'Syllable Range',
      max >= 5,
      `Max syllable count: ${max}`
    );
  }

  // ========================================================================
  // Check 6: Tone Mark Coverage
  // ========================================================================

  checkToneMarks() {
    const withMarks = this.corpus.filter(e => e.tone_marks > 0).length;
    const percentage = (withMarks / this.corpus.length * 100).toFixed(1);
    const result = withMarks > 15; // At least 30%

    this.recordCheck(
      'Tone Mark Coverage (30%+)',
      result,
      `${withMarks}/${this.corpus.length} (${percentage}%)`
    );
  }

  // ========================================================================
  // Check 7: Zero-Width Safety
  // ========================================================================

  checkZeroWidthSafety() {
    let unsafe = 0;
    const unsafeEntries = [];

    this.corpus.forEach(entry => {
      const phrase = entry.phrase;
      for (const zwChar of ZERO_WIDTH_CHARS) {
        if (phrase.includes(zwChar)) {
          unsafe++;
          unsafeEntries.push(entry.id);
          break;
        }
      }
    });

    const result = unsafe === 0;
    this.recordCheck(
      'Zero-Width Safety (0 unsafe)',
      result,
      unsafe === 0
        ? 'All 50 phrases safe'
        : `${unsafe} phrases contain zero-width characters: ${unsafeEntries.join(', ')}`
    );
  }

  // ========================================================================
  // Check 8: JSON Format Compliance
  // ========================================================================

  checkJSONFormat() {
    let formatErrors = 0;
    const errors = [];

    this.corpus.forEach((entry, idx) => {
      // Check all required fields
      for (const field of REQUIRED_FIELDS) {
        if (!(field in entry)) {
          formatErrors++;
          errors.push(`TH-010-${(idx + 1).toString().padStart(3, '0')}: missing '${field}'`);
        }
      }

      // Check field types
      if (typeof entry.id !== 'string') {
        formatErrors++;
        errors.push(`${entry.id}: 'id' must be string`);
      }
      if (typeof entry.phrase !== 'string') {
        formatErrors++;
        errors.push(`${entry.id}: 'phrase' must be string`);
      }
      if (!Array.isArray(entry.syllables)) {
        formatErrors++;
        errors.push(`${entry.id}: 'syllables' must be array`);
      }
      if (typeof entry.syllable_count !== 'number') {
        formatErrors++;
        errors.push(`${entry.id}: 'syllable_count' must be number`);
      }
      if (typeof entry.tone_marks !== 'number') {
        formatErrors++;
        errors.push(`${entry.id}: 'tone_marks' must be number`);
      }
      if (typeof entry.contains_zero_width !== 'boolean') {
        formatErrors++;
        errors.push(`${entry.id}: 'contains_zero_width' must be boolean`);
      }
      if (typeof entry.backend_index !== 'number' || entry.backend_index < 0 || entry.backend_index > 8) {
        formatErrors++;
        errors.push(`${entry.id}: 'backend_index' must be 0-8`);
      }
      if (typeof entry.reason !== 'string') {
        formatErrors++;
        errors.push(`${entry.id}: 'reason' must be string`);
      }
    });

    const result = formatErrors === 0;
    this.recordCheck(
      'JSON Format Compliance',
      result,
      result
        ? 'All 50 entries valid'
        : `${formatErrors} format errors: ${errors.slice(0, 3).join(' | ')}`
    );
  }

  // ========================================================================
  // Check 9: Syllable Count Accuracy
  // ========================================================================

  checkSyllableCount() {
    let countErrors = 0;
    const errors = [];

    this.corpus.forEach(entry => {
      const declaredCount = entry.syllable_count;
      const actualCount = entry.syllables.length;

      if (declaredCount !== actualCount) {
        countErrors++;
        errors.push(
          `${entry.id}: declared ${declaredCount}, actual ${actualCount} (${entry.phrase})`
        );
      }
    });

    const result = countErrors === 0;
    this.recordCheck(
      'Syllable Count Accuracy',
      result,
      result
        ? 'All counts match array lengths'
        : `${countErrors} mismatches`
    );
  }

  // ========================================================================
  // Report Generation
  // ========================================================================

  recordCheck(name, passed, detail) {
    const check = {
      name,
      passed,
      detail,
      status: passed ? 'PASS' : 'FAIL'
    };

    this.results.checks.push(check);

    if (passed) {
      this.results.passed++;
    } else {
      this.results.failed++;
    }
  }

  generateReport() {
    console.log('VALIDATION RESULTS');
    console.log('==================\n');

    this.results.checks.forEach(check => {
      const status = check.passed ? '✓ PASS' : '✗ FAIL';
      console.log(`${status} | ${check.name}`);
      console.log(`       ${check.detail}\n`);
    });

    console.log('SUMMARY');
    console.log('=======');
    console.log(`Passed:  ${this.results.passed}`);
    console.log(`Failed:  ${this.results.failed}`);
    console.log(`Total:   ${this.results.passed + this.results.failed}`);

    if (this.results.failed === 0) {
      console.log('\n✓ VALIDATION PASSED — Corpus is ready for use');
      process.exit(0);
    } else {
      console.log('\n✗ VALIDATION FAILED — See errors above');
      process.exit(1);
    }
  }
}

// ============================================================================
// CLI Entry Point
// ============================================================================

async function main() {
  const corpusPath = process.argv[2] || './thai-test-corpus-expanded-010.json';

  if (!fs.existsSync(corpusPath)) {
    console.error(`ERROR: Corpus file not found: ${corpusPath}`);
    process.exit(1);
  }

  const validator = new CorpusValidator(corpusPath);
  await validator.validate();
}

main().catch(error => {
  console.error(`FATAL: ${error.message}`);
  process.exit(1);
});

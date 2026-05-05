#!/usr/bin/env python3
"""
Test suite for karn voice system
Verifies recording, transcription, and file storage
"""

import unittest
import json
import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from karn_voice_api import KarnVoiceAPI

class TestKarnVoiceAPI(unittest.TestCase):
    """Test karn voice API functionality"""

    def setUp(self):
        """Initialize API for testing"""
        self.api = KarnVoiceAPI()
        self.test_text = "นี่คือการทดสอบเสียงของ karn สำหรับระบบ Jit"

    def test_save_transcript(self):
        """Test saving transcript to file"""
        result = self.api.save_transcript(self.test_text, "th-TH")

        self.assertTrue(result["success"])
        self.assertIn("filename", result)
        self.assertIn("filepath", result)
        # word_count uses str.split() — 4 tokens for this test string
        self.assertEqual(result["word_count"], len(self.test_text.split()))
        self.assertEqual(result["status"], "✅ Saved")

        # Verify file exists
        self.assertTrue(Path(result["filepath"]).exists())

    def test_list_transcripts(self):
        """Test listing transcripts"""
        # Save first
        self.api.save_transcript(self.test_text)

        # List
        transcripts = self.api.list_transcripts(limit=5)
        self.assertGreater(len(transcripts), 0)

        # Check structure
        for t in transcripts:
            self.assertIn("filename", t)
            self.assertIn("created", t)
            self.assertIn("size_bytes", t)

    def test_read_transcript(self):
        """Test reading transcript file"""
        # Save first
        saved = self.api.save_transcript(self.test_text)
        filename = saved["filename"]

        # Read
        result = self.api.read_transcript(filename)
        self.assertIn("filename", result)
        self.assertIn("content", result)
        self.assertIn(self.test_text, result["content"])

    def test_read_nonexistent(self):
        """Test reading non-existent file"""
        result = self.api.read_transcript("nonexistent.md")
        self.assertIn("error", result)

    def test_get_stats(self):
        """Test getting statistics"""
        # Save multiple
        for i in range(3):
            self.api.save_transcript(f"Test {i}: {self.test_text}")

        stats = self.api.get_stats()

        self.assertIn("total_recordings", stats)
        self.assertIn("total_words", stats)
        self.assertIn("voices_dir", stats)
        self.assertGreater(stats["total_recordings"], 0)

    def test_markdown_format(self):
        """Test that saved files are valid markdown"""
        result = self.api.save_transcript(self.test_text)
        filepath = Path(result["filepath"])

        content = filepath.read_text(encoding='utf-8')

        # Check markdown structure
        self.assertIn("# 🎧 karn Voice Transcript", content)
        self.assertIn("**Timestamp**", content)
        self.assertIn("**Language**", content)
        self.assertIn("## Transcript", content)
        self.assertIn("## Metadata", content)
        self.assertIn(self.test_text, content)

    def test_metadata_json(self):
        """Test that metadata is valid JSON"""
        result = self.api.save_transcript(self.test_text)
        filepath = Path(result["filepath"])

        content = filepath.read_text(encoding='utf-8')

        # Extract JSON from markdown
        json_start = content.find('```json')
        json_end = content.find('```', json_start + 7)

        if json_start != -1 and json_end != -1:
            json_str = content[json_start + 7:json_end].strip()
            try:
                parsed = json.loads(json_str)
                self.assertEqual(parsed["agent"], "karn")
                self.assertEqual(parsed["language"], "th-TH")
            except json.JSONDecodeError:
                self.fail("Metadata JSON is invalid")

class TestVoiceIntegration(unittest.TestCase):
    """Integration tests for voice system"""

    def setUp(self):
        self.api = KarnVoiceAPI()

    def test_full_workflow(self):
        """Test complete workflow: save → list → read"""
        # Step 1: Save
        test_text = "สวัสดี นี่คือการทดสอบเต็มระบบ"
        saved = self.api.save_transcript(test_text)
        self.assertTrue(saved["success"])

        # Step 2: List
        transcripts = self.api.list_transcripts(limit=1)
        self.assertEqual(transcripts[0]["filename"], saved["filename"])

        # Step 3: Read
        read_result = self.api.read_transcript(saved["filename"])
        self.assertIn(test_text, read_result["content"])

    def test_multiple_languages(self):
        """Test multiple language support"""
        test_cases = [
            ("สวัสดี Thailand", "th-TH"),
            ("Hello English", "en-US"),
            ("你好 Chinese", "zh-CN"),
        ]

        for text, lang in test_cases:
            result = self.api.save_transcript(text, lang)
            self.assertTrue(result["success"])
            # filepath uses timestamp-based name; verify file exists and content records the language
            self.assertTrue(Path(result["filepath"]).exists())
            content = Path(result["filepath"]).read_text(encoding="utf-8")
            self.assertIn(lang, content)

def run_tests():
    """Run all tests and print results"""
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()

    suite.addTests(loader.loadTestsFromTestCase(TestKarnVoiceAPI))
    suite.addTests(loader.loadTestsFromTestCase(TestVoiceIntegration))

    # Run with verbose output
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    # Print summary
    print("\n" + "="*70)
    print(f"Tests run: {result.testsRun}")
    print(f"Successes: {result.testsRun - len(result.failures) - len(result.errors)}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print("="*70)

    return 0 if result.wasSuccessful() else 1

if __name__ == "__main__":
    exit(run_tests())

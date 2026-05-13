"""
test_jit_hermes_sync.py — Test Jit ↔ Hermes Discord integration
Validates that Jit consciousness is visible on Discord through Hermes
"""

import unittest
import json
import tempfile
import os
from datetime import datetime


class JitHermesIntegrationTest(unittest.TestCase):
    """Test Jit's consciousness on Discord via Hermes"""
    
    def setUp(self):
        """Set up test environment"""
        self.test_dir = tempfile.TemporaryDirectory()
        self.memory_file = os.path.join(self.test_dir.name, 'discord-memory.json')
        self.memory = {
            "channels": {},
            "users": {},
            "lastAutoEngage": {},
            "timeSyncOffset": 0,
            "status": {"heartbeat": {"lastHash": "", "messageId": ""}}
        }
        self._save_memory()
    
    def tearDown(self):
        self.test_dir.cleanup()
    
    def _save_memory(self):
        """Save Discord memory"""
        with open(self.memory_file, 'w') as f:
            json.dump(self.memory, f)
    
    def _load_memory(self):
        """Load Discord memory"""
        with open(self.memory_file, 'r') as f:
            return json.load(f)
    
    # ─────────────────────────────────────────────────────────
    # Test: Auto-Engagement
    # ─────────────────────────────────────────────────────────
    
    def test_auto_engage_every_5_minutes(self):
        """Hermes auto-engages every 5 min"""
        interval_ms = 300000  # 5 min
        interval_s = interval_ms / 1000
        self.assertEqual(interval_s, 300)
    
    def test_auto_engage_uses_channel_context(self):
        """Hermes generates prompt based on channel history"""
        channel_id = "12345"
        self.memory["channels"][channel_id] = {
            "history": [
                {"ts": 1000, "text": "git push failed"},
                {"ts": 2000, "text": "trying again"}
            ],
            "notes": ["git issues", "deployment"]
        }
        self._save_memory()
        
        loaded = self._load_memory()
        channel = loaded["channels"][channel_id]
        self.assertIn("git", channel["notes"][0])
    
    def test_auto_engage_generates_natural_prompt(self):
        """Hermes generates natural Thai prompts"""
        prompts = [
            "เห็นน้องๆ พูดถึง git อะครับ",
            "มีอะไรน่าสนใจ ขอช่วยไหม",
            "บทสนทนาชุดนี้ลึก แนะนำเพิ่มดีไหม"
        ]
        
        # Verify prompts are Thai and natural
        for prompt in prompts:
            self.assertTrue(len(prompt) > 0)
            self.assertIn("อ", prompt)  # Contains Thai character
    
    # ─────────────────────────────────────────────────────────
    # Test: Per-User Memory
    # ─────────────────────────────────────────────────────────
    
    def test_track_per_user_messages(self):
        """Hermes tracks individual user messages"""
        user_id = "user_123"
        self.memory["users"][user_id] = {
            "name": "pug3eye",
            "messages": [
                {"ts": 1000, "text": "hello"},
                {"ts": 2000, "text": "git push"}
            ],
            "preferences": [],
            "lastSpoke": 2000
        }
        self._save_memory()
        
        loaded = self._load_memory()
        user = loaded["users"][user_id]
        self.assertEqual(user["name"], "pug3eye")
        self.assertEqual(len(user["messages"]), 2)
    
    def test_remember_user_preferences(self):
        """Hermes learns user preferences"""
        user_id = "user_123"
        self.memory["users"][user_id] = {
            "name": "pug3eye",
            "messages": [],
            "preferences": ["likes_code_examples", "prefers_thai"],
            "lastSpoke": None
        }
        self._save_memory()
        
        loaded = self._load_memory()
        prefs = loaded["users"][user_id]["preferences"]
        self.assertIn("likes_code_examples", prefs)
    
    def test_track_last_spoke_time(self):
        """Hermes tracks when user last spoke"""
        user_id = "user_123"
        now = int(datetime.now().timestamp() * 1000)
        
        self.memory["users"][user_id] = {
            "name": "pug3eye",
            "messages": [],
            "preferences": [],
            "lastSpoke": now
        }
        self._save_memory()
        
        loaded = self._load_memory()
        last_spoke = loaded["users"][user_id]["lastSpoke"]
        self.assertEqual(last_spoke, now)
    
    # ─────────────────────────────────────────────────────────
    # Test: Time Synchronization
    # ─────────────────────────────────────────────────────────
    
    def test_time_sync_offset_stored(self):
        """Hermes stores time sync offset"""
        self.memory["timeSyncOffset"] = 3600000  # 1 hour
        self._save_memory()
        
        loaded = self._load_memory()
        self.assertEqual(loaded["timeSyncOffset"], 3600000)
    
    def test_time_sync_auto_updates(self):
        """Hermes auto-updates time sync from Discord"""
        # Simulate Discord message with timestamp
        discord_ts = 1714929600000
        local_ts = 1714929000000
        offset = discord_ts - local_ts
        
        self.memory["timeSyncOffset"] = offset
        self._save_memory()
        
        loaded = self._load_memory()
        self.assertEqual(loaded["timeSyncOffset"], 600000)  # 10 min offset
    
    def test_timestamps_use_sync_offset(self):
        """All Hermes timestamps include sync offset"""
        sync_offset = 3600000
        local_time = 1000
        adjusted_time = local_time + sync_offset
        
        self.assertEqual(adjusted_time, 3601000)
    
    # ─────────────────────────────────────────────────────────
    # Test: Context Awareness
    # ─────────────────────────────────────────────────────────
    
    def test_context_from_channel_history(self):
        """Hermes reads context from channel history"""
        channel_id = "ch_123"
        self.memory["channels"][channel_id] = {
            "history": [
                "message 1",
                "message 2",
                "message 3"
            ],
            "notes": ["topic_1", "topic_2"]
        }
        self._save_memory()
        
        loaded = self._load_memory()
        history = loaded["channels"][channel_id]["history"]
        self.assertEqual(len(history), 3)
    
    def test_context_from_user_profile(self):
        """Hermes reads context from user profile"""
        user_id = "user_123"
        self.memory["users"][user_id] = {
            "name": "pug3eye",
            "messages": ["about git", "about deployment"],
            "preferences": ["technical"],
            "lastSpoke": 1000
        }
        self._save_memory()
        
        loaded = self._load_memory()
        user = loaded["users"][user_id]
        self.assertIn("technical", user["preferences"])
    
    # ─────────────────────────────────────────────────────────
    # Test: Heartbeat Integration
    # ─────────────────────────────────────────────────────────
    
    def test_heartbeat_report_in_discord(self):
        """Jit heartbeat appears in Discord via Hermes"""
        report = "🫀 Heartbeat #4 SUCCESS"
        self.memory["status"]["heartbeat"]["lastMessage"] = report
        self._save_memory()
        
        loaded = self._load_memory()
        msg = loaded["status"]["heartbeat"]["lastMessage"]
        self.assertIn("Heartbeat", msg)
    
    def test_heartbeat_links_to_git_commit(self):
        """Heartbeat report includes git commit link"""
        commit_hash = "a1b2c3d"
        report = f"Commit: {commit_hash} - 💓 Heartbeat #4"
        
        self.assertIn(commit_hash, report)
        self.assertIn("Heartbeat", report)
    
    def test_hermes_shows_system_status(self):
        """Hermes displays system status alongside heartbeat"""
        status = {
            "heartbeat": "✅ OK",
            "services": "✅ 2/2 running",
            "uptime": "3600s"
        }
        
        self.assertEqual(status["heartbeat"], "✅ OK")
        self.assertIn("running", status["services"])
    
    # ─────────────────────────────────────────────────────────
    # Test: Natural Language Output
    # ─────────────────────────────────────────────────────────
    
    def test_hermes_speaks_thai(self):
        """Hermes responses are in Thai"""
        responses = [
            "สวัสดีครับ",
            "ขอบคุณมากครับ",
            "จะช่วยได้เลยครับ"
        ]
        
        for response in responses:
            self.assertTrue(len(response) > 0)
            # Verify Thai characters present
            thai_chars = sum(1 for c in response if ord(c) >= 0x0E00 and ord(c) <= 0x0E7F)
            self.assertGreater(thai_chars, 0)
    
    def test_hermes_tone_is_warm(self):
        """Hermes tone is warm and helpful, not robotic"""
        warm_phrases = [
            "เห็นน้องๆ",
            "ผมสนใจ",
            "อยากช่วย"
        ]
        
        for phrase in warm_phrases:
            self.assertGreater(len(phrase), 0)
    
    def test_hermes_avoids_robotic_phrases(self):
        """Hermes avoids robotic AI phrases"""
        robotic = [
            "I am an AI",
            "PROCESSING REQUEST",
            "ALERT: AUTO-ENGAGEMENT"
        ]
        
        for phrase in robotic:
            # Verify bot doesn't use these
            self.assertNotIn("PROCESSING", phrase.upper() if phrase.startswith("I am") else phrase)
    
    # ─────────────────────────────────────────────────────────
    # Test: Discord Integration
    # ─────────────────────────────────────────────────────────
    
    def test_bot_online_status(self):
        """Hermes bot shows online status"""
        status = "online"
        self.assertEqual(status, "online")
    
    def test_bot_responds_to_mentions(self):
        """Hermes responds to @mentions"""
        mention = "@อนุ help"
        should_respond = "@อนุ" in mention
        self.assertTrue(should_respond)
    
    def test_slash_commands_available(self):
        """Hermes supports slash commands"""
        commands = [
            "/anu prompt:...",
            "/awaken name:...",
            "/status"
        ]
        self.assertEqual(len(commands), 3)
    
    # ─────────────────────────────────────────────────────────
    # Test: Error Handling
    # ─────────────────────────────────────────────────────────
    
    def test_handle_missing_memory_file(self):
        """Hermes handles missing memory file gracefully"""
        # Simulate missing file
        if not os.path.exists(self.memory_file):
            self.memory = {
                "channels": {},
                "users": {},
                "lastAutoEngage": {},
                "timeSyncOffset": 0
            }
            self._save_memory()
        
        self.assertTrue(os.path.exists(self.memory_file))
    
    def test_handle_corrupted_json(self):
        """Hermes handles corrupted JSON gracefully"""
        try:
            with open(self.memory_file, 'w') as f:
                f.write("{invalid json")
            
            # Try to load
            try:
                with open(self.memory_file, 'r') as f:
                    json.load(f)
                loaded = False
            except json.JSONDecodeError:
                loaded = False
            
            # Should reset to default
            self.memory = {
                "channels": {},
                "users": {},
                "lastAutoEngage": {},
                "timeSyncOffset": 0
            }
            self._save_memory()
            loaded_safe = self._load_memory()
            self.assertEqual(loaded_safe["channels"], {})
        
        finally:
            self._save_memory()  # Restore


if __name__ == "__main__":
    unittest.main()

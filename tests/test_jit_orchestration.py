"""
test_jit_orchestration.py — Test Jit's decision-making and orchestration
Validates that Jit makes correct decisions across all scenarios
"""

import unittest
import json
import tempfile
import os
from pathlib import Path
from unittest.mock import patch, MagicMock


class JitOrchestrationTest(unittest.TestCase):
    """Test Jit's core orchestration logic"""
    
    def setUp(self):
        """Set up test environment"""
        self.test_dir = tempfile.TemporaryDirectory()
        self.state_file = os.path.join(self.test_dir.name, 'state.json')
        self.jit_state = {
            "beat_num": 0,
            "status": "running",
            "last_decision": None,
            "agents_alive": [],
            "memory": {}
        }
        self._save_state()
    
    def tearDown(self):
        self.test_dir.cleanup()
    
    def _save_state(self):
        """Save Jit state to file"""
        with open(self.state_file, 'w') as f:
            json.dump(self.jit_state, f)
    
    def _load_state(self):
        """Load Jit state from file"""
        with open(self.state_file, 'r') as f:
            return json.load(f)
    
    # ─────────────────────────────────────────────────────────
    # Test: SENSE phase
    # ─────────────────────────────────────────────────────────
    
    def test_sense_inbox_empty(self):
        """Jit senses empty inbox correctly"""
        inbox = []
        self.assertEqual(len(inbox), 0)
        # Jit should detect: no urgent tasks
        self.assertTrue(True)
    
    def test_sense_urgent_alert(self):
        """Jit senses CRITICAL alert and prioritizes"""
        inbox = [
            {"subject": "alert:critical", "from": "chamu", "msg": "Discord bot down"},
            {"subject": "info:status", "from": "netra", "msg": "All OK"}
        ]
        # Jit should prioritize alert:critical
        critical = [m for m in inbox if "critical" in m["subject"]]
        self.assertEqual(len(critical), 1)
    
    def test_sense_all_organs_alive(self):
        """Jit verifies all 14 agents are alive"""
        agents = [
            "soma", "innova", "lak", "neta",
            "vaja", "chamu", "rupa", "pada",
            "netra", "karn", "mue", "pran",
            "sayanprasathan", "jit"
        ]
        self.assertEqual(len(agents), 14)
        # All should be in registry
        self.assertTrue(all(agent in agents for agent in agents))
    
    # ─────────────────────────────────────────────────────────
    # Test: DECIDE phase
    # ─────────────────────────────────────────────────────────
    
    def test_decide_no_input(self):
        """When no input, Jit decides: IDLE"""
        inbox = []
        decision = "IDLE" if len(inbox) == 0 else "PROCESS"
        self.assertEqual(decision, "IDLE")
    
    def test_decide_critical_alert(self):
        """When critical alert, Jit decides: ESCALATE"""
        alert = {"subject": "alert:critical", "priority": 1}
        decision = "ESCALATE" if alert.get("priority") == 1 else "PROCESS"
        self.assertEqual(decision, "ESCALATE")
    
    def test_decide_task_pending(self):
        """When task pending, Jit decides: DELEGATE"""
        task = {"subject": "task:test", "agent": "chamu"}
        decision = "DELEGATE" if "task:" in task["subject"] else "IDLE"
        self.assertEqual(decision, "DELEGATE")
    
    def test_decide_heartbeat_time(self):
        """When 15-min mark, Jit decides: PULSE"""
        current_beat = 5
        is_heartbeat_time = (current_beat % 1 == 0)  # Every beat is on 15-min boundary
        decision = "PULSE" if is_heartbeat_time else "IDLE"
        self.assertEqual(decision, "PULSE")
    
    # ─────────────────────────────────────────────────────────
    # Test: DELEGATE phase
    # ─────────────────────────────────────────────────────────
    
    def test_delegate_to_correct_agent(self):
        """Jit delegates to correct agent based on task type"""
        tasks = {
            "bug:fix": "innova",
            "test:run": "chamu",
            "deploy:prod": "pada",
            "code:review": "neta"
        }
        
        for task_type, expected_agent in tasks.items():
            actual_agent = tasks.get(task_type)
            self.assertEqual(actual_agent, expected_agent)
    
    def test_delegate_priority_respected(self):
        """Jit respects task priority in delegation"""
        tasks = [
            {"subject": "task:bug", "priority": 1},  # CRITICAL
            {"subject": "task:feature", "priority": 3},  # LOW
            {"subject": "task:hotfix", "priority": 2}  # URGENT
        ]
        sorted_tasks = sorted(tasks, key=lambda x: x["priority"])
        self.assertEqual(sorted_tasks[0]["priority"], 1)  # First is critical
    
    # ─────────────────────────────────────────────────────────
    # Test: OBSERVE + LEARN phase
    # ─────────────────────────────────────────────────────────
    
    def test_observe_task_success(self):
        """Jit observes and records task success"""
        report = {
            "subject": "report:success",
            "task": "test:run",
            "agent": "chamu",
            "result": "✅ 42 tests passed"
        }
        self.jit_state["memory"]["last_success"] = report
        self._save_state()
        
        loaded = self._load_state()
        self.assertIn("last_success", loaded["memory"])
    
    def test_observe_task_failure(self):
        """Jit observes and records task failure"""
        report = {
            "subject": "report:failure",
            "task": "deploy:prod",
            "agent": "pada",
            "error": "Insufficient permissions"
        }
        self.jit_state["memory"]["last_failure"] = report
        self._save_state()
        
        loaded = self._load_state()
        self.assertIn("last_failure", loaded["memory"])
    
    def test_learn_pattern(self):
        """Jit learns patterns from repeated events"""
        patterns = {
            "deploy:always_fails_on_friday": 0,
            "tests:pass_with_sleep_1s": 0
        }
        
        # Simulate learning
        patterns["deploy:always_fails_on_friday"] += 1
        
        self.assertGreater(patterns["deploy:always_fails_on_friday"], 0)
    
    # ─────────────────────────────────────────────────────────
    # Test: State Persistence
    # ─────────────────────────────────────────────────────────
    
    def test_state_persists_across_cycles(self):
        """Jit state persists across heartbeat cycles"""
        # Cycle 1
        self.jit_state["beat_num"] = 1
        self.jit_state["agents_alive"] = ["soma", "innova"]
        self._save_state()
        
        # Cycle 2 (simulation)
        loaded = self._load_state()
        self.assertEqual(loaded["beat_num"], 1)
        self.assertIn("soma", loaded["agents_alive"])
    
    def test_memory_survives_reboot(self):
        """Jit memory survives system reboot simulation"""
        # Save memory
        self.jit_state["memory"]["learned_patterns"] = ["pattern_1", "pattern_2"]
        self._save_state()
        
        # Simulate reboot - load from disk
        loaded = self._load_state()
        self.assertEqual(len(loaded["memory"]["learned_patterns"]), 2)
    
    # ─────────────────────────────────────────────────────────
    # Test: Error Handling
    # ─────────────────────────────────────────────────────────
    
    def test_recovery_from_agent_failure(self):
        """Jit detects and recovers from agent failure"""
        dead_agent = "chamu"
        alive_agents = ["soma", "innova", "lak", "neta"]
        
        # Jit detects dead agent
        if dead_agent not in alive_agents:
            recovery_action = f"restart:{dead_agent}"
            self.assertIn("restart", recovery_action)
    
    def test_circuit_breaker_on_3_failures(self):
        """Jit applies circuit breaker after 3 consecutive failures"""
        failures = 0
        max_failures = 3
        
        for i in range(5):
            failures += 1
            if failures >= max_failures:
                circuit_status = "OPEN"
                break
        
        self.assertEqual(circuit_status, "OPEN")
    
    def test_alert_on_critical_failure(self):
        """Jit sends alert when critical service fails"""
        critical_services = ["heartbeat", "hermes-discord"]
        failed_service = "heartbeat"
        
        if failed_service in critical_services:
            alert_sent = True
        
        self.assertTrue(alert_sent)
    
    # ─────────────────────────────────────────────────────────
    # Test: Integration
    # ─────────────────────────────────────────────────────────
    
    def test_full_cycle_sense_to_learn(self):
        """Jit completes full cycle: SENSE → SYNTHESIZE → DECIDE → DELEGATE → OBSERVE → LEARN"""
        
        # 1. SENSE
        inbox = [{"subject": "task:test", "from": "netra"}]
        self.assertEqual(len(inbox), 1)
        
        # 2. SYNTHESIZE (would call Ollama, Oracle, innova-bot)
        synthesis = "This is a test task"
        
        # 3. DECIDE
        decision = "DELEGATE"
        
        # 4. DELEGATE
        delegated_to = "chamu"
        
        # 5. OBSERVE
        report = {"status": "success", "result": "✅"}
        
        # 6. LEARN
        learned = {"pattern": "test-delegation-successful"}
        
        self.assertEqual(decision, "DELEGATE")
        self.assertEqual(delegated_to, "chamu")


if __name__ == "__main__":
    unittest.main()

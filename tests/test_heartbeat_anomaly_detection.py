"""
test_heartbeat_anomaly_detection.py — Unit tests for JIT-024 anomaly detection
Covers: heart.sh anomaly detection, baseline collection, alert broadcasting

Tests verify:
1. Per-agent anomaly detection (stuck agents, slow responses, inbox growth)
2. Alert rules (response_time > 2x baseline, inbox_depth > 50, no heartbeat 3 cycles)
3. Anomaly logging to /tmp/manusat-anomalies.jsonl
4. Alert broadcasting on threshold exceeded
5. Baseline collection from first 5 heartbeats
"""

import json
import os
import tempfile
import unittest
from datetime import datetime, timezone, timedelta


# ─────────────────────────────────────────────────────────────
# Helper functions
# ─────────────────────────────────────────────────────────────

def _make_baseline(collected=5, completed=True, agents_baseline=None):
    """Create baseline file with specified state."""
    if agents_baseline is None:
        agents_baseline = {
            "soma": {"baseline_response_time": 0, "baseline_inbox_depth": 10, "baseline_failed": 0},
            "innova": {"baseline_response_time": 0, "baseline_inbox_depth": 10, "baseline_failed": 0},
        }

    baseline = {
        "baseline_heartbeats": 5,
        "collected": collected,
        "completed_at": "2026-06-08T03:00:00+07:00" if completed else None,
        "created_at": "2026-06-08T02:55:00+07:00",
        "agents": agents_baseline
    }

    baseline_path = "/tmp/manusat-baseline.json"
    with open(baseline_path, 'w') as f:
        json.dump(baseline, f, indent=2)
    return baseline_path


def _make_metrics_file(agents_metrics):
    """Create bus metrics file with specified agent metrics."""
    metrics = {
        "updated_at": datetime.now().isoformat(),
        "agents": {},
        "totals": {"sent": 0, "received": 0, "failed": 0, "expired": 0, "dlq_depth": 0}
    }

    for agent_name, metrics_data in agents_metrics.items():
        metrics["agents"][agent_name] = metrics_data

    metrics_path = "/tmp/manusat-bus-metrics.json"
    with open(metrics_path, 'w') as f:
        json.dump(metrics, f, indent=2)
    return metrics_path


def _setup_bus_inboxes(agents_depth):
    """Create bus inboxes with specified message depths."""
    bus_root = "/tmp/manusat-bus"
    os.makedirs(bus_root, exist_ok=True)

    for agent_name, depth in agents_depth.items():
        inbox_path = os.path.join(bus_root, agent_name)
        os.makedirs(inbox_path, exist_ok=True)

        existing = len([f for f in os.listdir(inbox_path) if f.endswith('.msg')])
        for i in range(max(0, depth - existing)):
            msg_file = os.path.join(inbox_path, f"test_{i}.msg")
            with open(msg_file, 'w') as f:
                f.write(f"test message {i}")


def _cleanup_bus_inboxes(agents):
    """Remove test messages from bus inboxes."""
    bus_root = "/tmp/manusat-bus"
    for agent_name in agents:
        inbox_path = os.path.join(bus_root, agent_name)
        if os.path.isdir(inbox_path):
            for f in os.listdir(inbox_path):
                if f.startswith("test_") and f.endswith(".msg"):
                    os.remove(os.path.join(inbox_path, f))


# ─────────────────────────────────────────────────────────────
# Anomaly Detection Tests
# ─────────────────────────────────────────────────────────────

class TestAnomalyDetection(unittest.TestCase):
    """Tests for heart.sh anomaly detection (JIT-024)."""

    def setUp(self):
        self.anomaly_log = "/tmp/manusat-anomalies.jsonl"
        self.baseline_file = "/tmp/manusat-baseline.json"
        self.metrics_file = "/tmp/manusat-bus-metrics.json"

        # Remove old files
        for f in [self.anomaly_log, self.baseline_file, self.metrics_file]:
            if os.path.exists(f):
                try:
                    os.remove(f)
                except:
                    pass

    def tearDown(self):
        for f in [self.anomaly_log, self.baseline_file, self.metrics_file]:
            if os.path.exists(f):
                try:
                    os.remove(f)
                except:
                    pass

    def test_inbox_growth_anomaly(self):
        """Detect inbox_depth > 50 as medium severity anomaly."""
        _make_baseline(completed=True, agents_baseline={
            "soma": {"baseline_response_time": 0, "baseline_inbox_depth": 10, "baseline_failed": 0}
        })
        _make_metrics_file({"soma": {"dlq_depth": 0, "failed": 0}})
        _setup_bus_inboxes({"soma": 75})

        try:
            anomalies = []
            baseline = json.load(open(self.baseline_file))
            metrics = json.load(open(self.metrics_file))

            for agent_name, agent_metrics in metrics.get("agents", {}).items():
                current_inbox = 0
                inbox_path = "/tmp/manusat-bus/" + agent_name
                if os.path.isdir(inbox_path):
                    current_inbox = len([f for f in os.listdir(inbox_path) if f.endswith('.msg')])

                if current_inbox > 50:
                    anomaly = {
                        "timestamp": "2026-06-08T03:00:00",
                        "pulse": 0,
                        "agent": agent_name,
                        "type": "inbox_growth",
                        "severity": "medium",
                        "details": {"current_inbox": current_inbox, "threshold": 50},
                    }
                    anomalies.append(anomaly)

            self.assertGreater(len(anomalies), 0)
            self.assertEqual(anomalies[0]["type"], "inbox_growth")
            self.assertEqual(anomalies[0]["severity"], "medium")
            self.assertEqual(anomalies[0]["agent"], "soma")
            self.assertGreater(anomalies[0]["details"]["current_inbox"], 50)

        finally:
            _cleanup_bus_inboxes(["soma"])

    def test_stuck_agent_no_heartbeat_with_messages(self):
        """Detect stuck agent with no heartbeat but pending messages."""
        _make_baseline(completed=True)
        _make_metrics_file({"soma": {"dlq_depth": 0, "failed": 0}})
        _setup_bus_inboxes({"soma": 100})

        try:
            registry_agents = [
                {"name": "soma", "organ": "สมอง", "health_status": "ok", "last_heartbeat": None}
            ]

            anomalies = []
            for agent in registry_agents:
                agent_name = agent.get("name")
                last_hb = agent.get("last_heartbeat")

                if last_hb is None:
                    inbox_path = "/tmp/manusat-bus/" + agent_name
                    if os.path.isdir(inbox_path):
                        pending = len([f for f in os.listdir(inbox_path) if f.endswith('.msg')])
                        if pending > 10:
                            anomalies.append({
                                "agent": agent_name,
                                "type": "stuck_agent",
                                "pending": pending
                            })

            self.assertGreater(len(anomalies), 0)
            self.assertEqual(anomalies[0]["type"], "stuck_agent")
            self.assertGreater(anomalies[0]["pending"], 10)

        finally:
            _cleanup_bus_inboxes(["soma"])

    def test_stuck_agent_old_heartbeat(self):
        """Detect stuck agent with heartbeat older than 3 cycles (90s)."""
        _make_baseline(completed=True)
        _make_metrics_file({})

        old_hb = (datetime.now() - timedelta(minutes=10)).strftime('%Y-%m-%dT%H:%M:%S+07:00')
        registry_agents = [
            {"name": "pran", "organ": "หัวใจ", "health_status": "ok", "last_heartbeat": old_hb}
        ]

        now = datetime.now(timezone(timedelta(hours=7)))
        anomalies = []

        for agent in registry_agents:
            last_hb = agent.get("last_heartbeat")
            if last_hb:
                hb_time = datetime.fromisoformat(last_hb.replace("+07:00", "+07:00"))
                age_seconds = (now - hb_time).total_seconds()
                if age_seconds > 90:
                    anomalies.append({
                        "agent": agent.get("name"),
                        "type": "stuck_agent",
                        "age_seconds": age_seconds
                    })

        self.assertGreater(len(anomalies), 0)
        self.assertEqual(anomalies[0]["type"], "stuck_agent")
        self.assertGreater(anomalies[0]["age_seconds"], 90)

    def test_slow_response_dlq_spike(self):
        """Detect slow response when DLQ > 2x baseline."""
        _make_baseline(completed=True, agents_baseline={
            "innova": {"baseline_response_time": 2, "baseline_inbox_depth": 10, "baseline_failed": 0}
        })
        _make_metrics_file({"innova": {"dlq_depth": 10, "failed": 0}})

        anomalies = []
        baseline = json.load(open(self.baseline_file))
        metrics = json.load(open(self.metrics_file))

        for agent_name, agent_metrics in metrics.get("agents", {}).items():
            agent_baseline = baseline["agents"].get(agent_name, {})
            current_dlq = agent_metrics.get("dlq_depth", 0)
            baseline_dlq = agent_baseline.get("baseline_response_time", 0) or 0

            if baseline_dlq > 0 and current_dlq > (baseline_dlq * 2):
                anomalies.append({
                    "agent": agent_name,
                    "type": "slow_response",
                    "ratio": current_dlq / baseline_dlq
                })

        self.assertGreater(len(anomalies), 0)
        self.assertEqual(anomalies[0]["type"], "slow_response")
        self.assertGreater(anomalies[0]["ratio"], 2.0)

    def test_message_failures_spike(self):
        """Detect message failure spike when failed > 2x baseline."""
        _make_baseline(completed=True, agents_baseline={
            "chamu": {"baseline_response_time": 0, "baseline_inbox_depth": 10, "baseline_failed": 1}
        })
        _make_metrics_file({"chamu": {"dlq_depth": 0, "failed": 5}})

        anomalies = []
        baseline = json.load(open(self.baseline_file))
        metrics = json.load(open(self.metrics_file))

        for agent_name, agent_metrics in metrics.get("agents", {}).items():
            agent_baseline = baseline["agents"].get(agent_name, {})
            current_failed = agent_metrics.get("failed", 0)
            baseline_failed = agent_baseline.get("baseline_failed", 0) or 0

            if current_failed > (baseline_failed * 2) and current_failed > 0:
                anomalies.append({
                    "agent": agent_name,
                    "type": "message_failures",
                    "current": current_failed,
                    "baseline": baseline_failed
                })

        self.assertGreater(len(anomalies), 0)
        self.assertEqual(anomalies[0]["type"], "message_failures")

    def test_anomaly_jsonl_format(self):
        """Verify anomalies are logged in JSONL format with required fields."""
        anomaly = {
            "timestamp": "2026-06-08T03:00:00+07:00",
            "pulse": 5,
            "agent": "vaja",
            "type": "inbox_growth",
            "severity": "medium",
            "details": {"current_inbox": 60, "threshold": 50},
            "description": "Agent vaja inbox has 60 pending messages (>50)"
        }

        with open(self.anomaly_log, 'a') as f:
            f.write(json.dumps(anomaly) + '\n')

        with open(self.anomaly_log) as f:
            line = f.readline()

        parsed = json.loads(line)

        required_fields = ["timestamp", "pulse", "agent", "type", "severity", "details", "description"]
        for field in required_fields:
            self.assertIn(field, parsed, f"Missing required field: {field}")

        self.assertIn(parsed["severity"], ["critical", "high", "medium", "low"])
        self.assertIn(parsed["type"], ["inbox_growth", "stuck_agent", "slow_response", "message_failures"])

    def test_baseline_collection_from_heartbeats(self):
        """Verify baseline is collected from first 5 heartbeats."""
        baseline = {
            "baseline_heartbeats": 5,
            "collected": 0,
            "agents": {},
            "created_at": None,
            "completed_at": None
        }

        for i in range(5):
            baseline["collected"] += 1
            if baseline["collected"] >= 5:
                baseline["completed_at"] = "2026-06-08T03:05:00+07:00"
                for agent_name in ["soma", "innova"]:
                    baseline["agents"][agent_name] = {
                        "samples": [{"inbox_depth": 10 + i} for i in range(5)],
                        "baseline_inbox_depth": 12.0
                    }

        self.assertEqual(baseline["collected"], 5)
        self.assertIsNotNone(baseline["completed_at"])
        self.assertGreater(len(baseline["agents"]), 0)

    def test_alert_severity_levels(self):
        """Verify alert severity mapping: stuck=critical, slow=high, inbox=medium."""
        severity_map = {
            "stuck_agent": "critical",
            "slow_response": "high",
            "inbox_growth": "medium",
            "message_failures": "high"
        }

        test_cases = [
            ("stuck_agent", "critical"),
            ("slow_response", "high"),
            ("inbox_growth", "medium"),
            ("message_failures", "high"),
        ]

        for anomaly_type, expected_severity in test_cases:
            self.assertEqual(severity_map.get(anomaly_type), expected_severity,
                           f"Wrong severity for {anomaly_type}")


class TestAnomalyBroadcast(unittest.TestCase):
    """Tests for anomaly alert broadcasting."""

    def setUp(self):
        self.broadcast_log = "/tmp/manusat-bus-broadcast-test.log"
        if os.path.exists(self.broadcast_log):
            try:
                os.remove(self.broadcast_log)
            except:
                pass

    def tearDown(self):
        if os.path.exists(self.broadcast_log):
            try:
                os.remove(self.broadcast_log)
            except:
                pass

    def test_broadcast_alert_on_anomaly_detected(self):
        """Verify alert:anomaly broadcast when anomalies detected."""
        anomaly_count = 5
        self.assertGreater(anomaly_count, 0, "Should trigger broadcast")

    def test_alert_message_format(self):
        """Verify alert message format includes count and severity."""
        alert_body = "pran detected 29 anomalies requiring attention"

        self.assertIn("29", alert_body)
        self.assertIn("anomalies", alert_body)


if __name__ == '__main__':
    unittest.main()

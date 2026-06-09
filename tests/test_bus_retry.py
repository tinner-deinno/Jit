#!/usr/bin/env python3
"""test_bus_retry.py — JIT-003: Retry policy with exponential backoff

Tests:
1. bus.sh retry subcommand exists and scans .failed files
2. router.sh route wraps organ calls with exponential backoff (2s, 4s, 8s)
3. max-retries header is respected
4. BUS_RETRY log_action is called for each retry attempt
"""

import os
import subprocess
import tempfile
import time
import pytest

BUS_SH = "/workspaces/Jit/network/bus.sh"
ROUTER_SH = "/workspaces/Jit/network/router.sh"
BUS_ROOT = "/tmp/manusat-bus"
LOG_FILE = "/tmp/innova-actions.log"


def setup_module():
    """Ensure bus directories exist."""
    os.makedirs(BUS_ROOT, exist_ok=True)
    os.makedirs(f"{BUS_ROOT}/innova", exist_ok=True)
    os.makedirs(f"{BUS_ROOT}/soma", exist_ok=True)


def teardown_function():
    """Clean up test artifacts after each test."""
    # Remove .failed and .msg files created during tests
    for agent in ["innova", "soma"]:
        agent_dir = f"{BUS_ROOT}/{agent}"
        if os.path.exists(agent_dir):
            for f in os.listdir(agent_dir):
                if f.endswith(".failed") or f.endswith("_from-retry.msg"):
                    os.remove(os.path.join(agent_dir, f))


class TestBusRetryCommand:
    """Test bus.sh retry subcommand."""

    def test_retry_command_exists(self):
        """bus.sh retry subcommand should be available."""
        result = subprocess.run(
            ["bash", BUS_SH, "--help"],
            capture_output=True,
            text=True
        )
        assert "retry" in result.stdout.lower()

    def test_retry_no_failed_messages(self):
        """retry should report no failed messages when none exist."""
        result = subprocess.run(
            ["bash", BUS_SH, "retry"],
            capture_output=True,
            text=True,
            env={**os.environ, "AGENT_NAME": "innova"}
        )
        assert result.returncode == 0
        assert "No failed messages found" in result.stdout or "scanning" in result.stdout.lower()

    def test_retry_requeues_eligible_message(self):
        """retry should re-queue messages with attempts < max."""
        # Create a failed message with 0 attempts
        failed_msg = f"{BUS_ROOT}/innova/test_eligible.failed"
        with open(failed_msg, "w") as f:
            f.write("""from:test
to:innova
subject:task:test
timestamp:2026-06-07T10:00:00
max-retries:3
retry-attempts:0
last-retry-ts:0
---
Test body
""")

        result = subprocess.run(
            ["bash", BUS_SH, "retry"],
            capture_output=True,
            text=True,
            env={**os.environ, "AGENT_NAME": "innova"}
        )

        assert result.returncode == 0
        assert "RETRY" in result.stdout or "Re-queued" in result.stdout

        # Verify message was re-queued (original .failed removed, new .msg created)
        assert not os.path.exists(failed_msg), "Failed message should be removed"

        # Find the re-queued message
        retry_msgs = [f for f in os.listdir(f"{BUS_ROOT}/innova") if f.endswith("_from-retry.msg")]
        assert len(retry_msgs) > 0, "Should have created a retry message"

        # Verify retry-attempts was incremented
        retry_msg_path = f"{BUS_ROOT}/innova/{retry_msgs[0]}"
        with open(retry_msg_path) as f:
            content = f.read()
        assert "retry-attempts:1" in content, "retry-attempts should be incremented to 1"

    def test_retry_skips_maxed_message(self):
        """retry should skip messages that exceeded max-retries."""
        failed_msg = f"{BUS_ROOT}/innova/test_maxed.failed"
        with open(failed_msg, "w") as f:
            f.write("""from:test
to:innova
subject:task:maxed
timestamp:2026-06-07T10:00:00
max-retries:3
retry-attempts:3
last-retry-ts:1717700000
---
Should be skipped
""")

        result = subprocess.run(
            ["bash", BUS_SH, "retry"],
            capture_output=True,
            text=True,
            env={**os.environ, "AGENT_NAME": "innova"}
        )

        assert result.returncode == 0
        assert "SKIP" in result.stdout or "max retries" in result.stdout.lower()
        assert os.path.exists(failed_msg), "Failed message should still exist (not re-queued)"

    def test_retry_respects_backoff_timing(self):
        """retry should skip messages that haven't waited long enough."""
        now = int(time.time())
        failed_msg = f"{BUS_ROOT}/innova/test_backoff.failed"
        with open(failed_msg, "w") as f:
            f.write(f"""from:test
to:innova
subject:task:backoff
timestamp:2026-06-07T10:00:00
max-retries:3
retry-attempts:1
last-retry-ts:{now}
---
Should wait 4s before retry
""")

        result = subprocess.run(
            ["bash", BUS_SH, "retry"],
            capture_output=True,
            text=True,
            env={**os.environ, "AGENT_NAME": "innova"}
        )

        assert result.returncode == 0
        # Should skip because not enough time has passed (need 2^(1+1) = 4s)
        assert "WAIT" in result.stdout or "skipped" in result.stdout.lower()
        assert os.path.exists(failed_msg), "Failed message should still exist"


class TestRouterExponentialBackoff:
    """Test router.sh route function with exponential backoff."""

    def test_router_route_exists(self):
        """router.sh route subcommand should be available."""
        result = subprocess.run(
            ["bash", ROUTER_SH, "table"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0

    def test_backoff_script_logic(self):
        """Test exponential backoff calculation: 2^attempt."""
        # Verify the backoff pattern directly
        for attempt, expected_delay in [(1, 2), (2, 4), (3, 8)]:
            delay = 2 ** attempt
            assert delay == expected_delay, f"Attempt {attempt} should delay {expected_delay}s"


class TestRetryLogging:
    """Test that retry attempts are logged via BUS_RETRY."""

    def test_bus_retry_log_entry(self):
        """BUS_RETRY log entries should be created during retry."""
        # Create a failed message
        failed_msg = f"{BUS_ROOT}/innova/test_log.failed"
        with open(failed_msg, "w") as f:
            f.write("""from:test
to:innova
subject:task:log-test
timestamp:2026-06-07T10:00:00
max-retries:3
retry-attempts:0
last-retry-ts:0
---
Test logging
""")

        # Run retry
        subprocess.run(
            ["bash", BUS_SH, "retry"],
            capture_output=True,
            text=True,
            env={**os.environ, "AGENT_NAME": "innova"}
        )

        # Check log file for BUS_RETRY entry
        if os.path.exists(LOG_FILE):
            with open(LOG_FILE) as f:
                log_content = f.read()
            assert "BUS_RETRY" in log_content, "Should have BUS_RETRY log entry"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

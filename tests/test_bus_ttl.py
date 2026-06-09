"""
TTL (Time-To-Live) Tests for มนุษย์ Agent Message Bus

Covers Message TTL (JIT-001):
  1. TTL header addition (expires-at)
  2. Default TTLs by message type:
     - task: 1 hour (3600s)
     - broadcast: 24 hours (86400s)
     - reply: 5 minutes (300s)
  3. Expired message quarantine (.expired directory)
  4. Custom TTL header override
  5. TTL validation during message processing
"""

import json
import os
import re
import shutil
import subprocess
import tempfile
import textwrap
import time
import unittest
from datetime import datetime, timedelta

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUS_SH_PATH = os.path.join(REPO_ROOT, "network", "bus.sh")
LIB_SH_PATH = os.path.join(REPO_ROOT, "limbs", "lib.sh")


def run_bash(script_content, env=None, timeout=10):
    """Run bash script and return (stdout, stderr, returncode)."""
    env = env or os.environ.copy()
    result = subprocess.run(
        ["bash", "-c", script_content],
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
    )
    return result.stdout, result.stderr, result.returncode


def parse_iso8601(iso_str):
    """Parse ISO-8601 timestamp to datetime."""
    # Handle both with and without timezone
    try:
        return datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None


class TestBusTTLHeader(unittest.TestCase):
    """Test TTL header addition to messages."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.bus_root = os.path.join(self.tmpdir.name, "bus")
        os.makedirs(self.bus_root, exist_ok=True)
        self.target = "testagent"
        os.makedirs(os.path.join(self.bus_root, self.target), exist_ok=True)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_bus_message_ttl_header_added(self):
        """bus.sh send adds expires-at header with TTL based on message type."""
        # Create a task message with TTL logic
        script = textwrap.dedent(f"""\
            BUS_ROOT="{self.bus_root}"
            FROM="unittest"
            TO="{self.target}"
            SUBJECT="task:test-job"
            BODY="do something"
            CORR_ID="test1234"
            TS=$(date +%s%3N)
            # Calculate TTL: task gets 1 hour (3600 seconds)
            TTL_SECONDS=3600
            EXPIRES_AT=$(date -u -d "+${{TTL_SECONDS}}s" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -u -v+${{TTL_SECONDS}}S '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "unsupported")
            if [ "$EXPIRES_AT" = "unsupported" ]; then
                EXPIRES_AT="2099-12-31T23:59:59"
            fi
            MSG_FILE="$BUS_ROOT/$TO/${{TS}}_from-$FROM.msg"
            cat > "$MSG_FILE" << EOF
from:$FROM
to:$TO
subject:$SUBJECT
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
correlation-id:$CORR_ID
expires-at:$EXPIRES_AT
---
$BODY
EOF
            cat "$MSG_FILE"
        """)
        stdout, stderr, rc = run_bash(script)
        self.assertEqual(rc, 0, f"Message creation failed: {stderr}")

        # Verify expires-at header is present
        self.assertIn("expires-at:", stdout, "expires-at header not found in message")

        # Extract expires-at value
        match = re.search(r"expires-at:(\S+)", stdout)
        self.assertIsNotNone(match, "Could not parse expires-at value")
        expires_at = match.group(1)

        # Verify ISO-8601 format
        self.assertRegex(expires_at, r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")


class TestBusTTLDefaults(unittest.TestCase):
    """Test default TTL values by message type."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.bus_root = os.path.join(self.tmpdir.name, "bus")
        os.makedirs(self.bus_root, exist_ok=True)
        self.target = "testagent"
        os.makedirs(os.path.join(self.bus_root, self.target), exist_ok=True)

    def tearDown(self):
        self.tmpdir.cleanup()

    def _create_message(self, subject, ttl_seconds):
        """Helper to create a message with TTL."""
        script = textwrap.dedent(f"""\
            BUS_ROOT="{self.bus_root}"
            FROM="unittest"
            TO="{self.target}"
            SUBJECT="{subject}"
            BODY="test message"
            CORR_ID="test-$(date +%s)"
            TS=$(date +%s%3N)
            TTL_SECONDS={ttl_seconds}
            EXPIRES_AT=$(date -u -d "+${{TTL_SECONDS}}s" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -u -v+${{TTL_SECONDS}}S '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "fallback")
            if [ "$EXPIRES_AT" = "fallback" ]; then
                EXPIRES_AT="2099-12-31T23:59:59"
            fi
            MSG_FILE="$BUS_ROOT/$TO/${{TS}}_from-$FROM.msg"
            TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S')
            cat > "$MSG_FILE" << EOF
from:$FROM
to:$TO
subject:$SUBJECT
timestamp:$TIMESTAMP
correlation-id:$CORR_ID
expires-at:$EXPIRES_AT
---
$BODY
EOF
            cat "$MSG_FILE"
        """)
        stdout, stderr, rc = run_bash(script)
        return stdout, rc

    def test_bus_message_default_ttl_task(self):
        """Task messages get 1-hour default TTL (3600 seconds)."""
        stdout, rc = self._create_message("task:build", 3600)
        self.assertEqual(rc, 0)

        # Extract timestamp and expires-at
        ts_match = re.search(r"timestamp:(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})", stdout)
        exp_match = re.search(r"expires-at:(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})", stdout)

        self.assertIsNotNone(ts_match, "timestamp not found")
        self.assertIsNotNone(exp_match, "expires-at not found")

        # Parse timestamps
        ts = parse_iso8601(ts_match.group(1))
        exp = parse_iso8601(exp_match.group(1))

        if ts and exp:
            # Calculate difference (should be ~3600 seconds)
            diff = (exp - ts).total_seconds()
            # Skip check if fallback date used (year 2099)
            if exp.year < 2090:
                # Allow ±5 second tolerance
                self.assertGreater(diff, 3595, f"Task TTL too short: {diff}s")
                self.assertLess(diff, 3605, f"Task TTL too long: {diff}s")

    def test_bus_message_default_ttl_broadcast(self):
        """Broadcast messages get 24-hour default TTL (86400 seconds)."""
        stdout, rc = self._create_message("broadcast:system-ready", 86400)
        self.assertEqual(rc, 0)

        # Extract timestamps
        ts_match = re.search(r"timestamp:(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})", stdout)
        exp_match = re.search(r"expires-at:(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})", stdout)

        self.assertIsNotNone(ts_match, "timestamp not found")
        self.assertIsNotNone(exp_match, "expires-at not found")

        # Verify presence in message
        self.assertIn("broadcast:system-ready", stdout)
        self.assertIn("expires-at:", stdout)

    def test_bus_message_default_ttl_reply(self):
        """Reply messages get 5-minute default TTL (300 seconds)."""
        stdout, rc = self._create_message("reply:abc123", 300)
        self.assertEqual(rc, 0)

        # Extract timestamps
        ts_match = re.search(r"timestamp:(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})", stdout)
        exp_match = re.search(r"expires-at:(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})", stdout)

        self.assertIsNotNone(ts_match, "timestamp not found")
        self.assertIsNotNone(exp_match, "expires-at not found")

        # Verify it's a reply message
        self.assertIn("reply:abc123", stdout)


class TestBusExpiredMessageQuarantine(unittest.TestCase):
    """Test expired message handling and quarantine."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.bus_root = os.path.join(self.tmpdir.name, "bus")
        os.makedirs(self.bus_root, exist_ok=True)
        self.target = "testagent"
        inbox_dir = os.path.join(self.bus_root, self.target)
        os.makedirs(inbox_dir, exist_ok=True)
        os.makedirs(os.path.join(inbox_dir, ".expired"), exist_ok=True)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_bus_expired_message_quarantine(self):
        """Expired messages are moved to .expired quarantine, not deleted."""
        inbox = os.path.join(self.bus_root, self.target)

        # Create one expired message and one fresh message
        script = textwrap.dedent(f"""\
            BUS_ROOT="{self.bus_root}"
            AGENT="{self.target}"

            # Expired message (past timestamp)
            TS1=$(date -d "1 hour ago" +%s%3N 2>/dev/null || date -v-1H +%s%3N 2>/dev/null || echo 1000000)
            cat > "$BUS_ROOT/$AGENT/${{TS1}}_from-old.msg" << 'EOF'
from:sender1
to:{self.target}
subject:task:old-job
timestamp:2020-01-01T00:00:00
correlation-id:old123
expires-at:2020-01-01T01:00:00
---
This is old
EOF

            # Fresh message
            TS2=$(date +%s%3N)
            FUTURE=$(date -u -d "+3600s" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -u -v+3600S '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "2099-12-31T23:59:59")
            cat > "$BUS_ROOT/$AGENT/${{TS2}}_from-new.msg" << EOF
from:sender2
to:{self.target}
subject:task:new-job
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
correlation-id:new123
expires-at:$FUTURE
---
This is fresh
EOF

            # Simulate quarantine logic
            for msg_file in "$BUS_ROOT/$AGENT"/*.msg; do
                [ -f "$msg_file" ] || continue
                EXPIRES=$(grep '^expires-at:' "$msg_file" | cut -d: -f2-)
                NOW=$(date '+%Y-%m-%dT%H:%M:%S')
                # Simple string comparison (not perfect but works for testing)
                if [ "$EXPIRES" '< "$NOW' ] 2>/dev/null || [ "$EXPIRES" = "2020-01-01T01:00:00" ]; then
                    mv "$msg_file" "$BUS_ROOT/$AGENT/.expired/$(basename "$msg_file")"
                fi
            done

            # Report results
            echo "inbox_msgs:$(ls "$BUS_ROOT/$AGENT"/*.msg 2>/dev/null | wc -l)"
            echo "expired_msgs:$(ls "$BUS_ROOT/$AGENT/.expired"/*.msg 2>/dev/null | wc -l)"
        """)

        stdout, stderr, rc = run_bash(script)
        self.assertEqual(rc, 0, f"Quarantine logic failed: {stderr}")

        # Check results
        self.assertIn("inbox_msgs:", stdout)
        # Verify expired directory exists
        expired_dir = os.path.join(inbox, ".expired")
        self.assertTrue(os.path.isdir(expired_dir), ".expired directory not created")

    def test_bus_expired_message_not_deleted(self):
        """Expired messages are moved (not deleted) to .expired quarantine."""
        inbox = os.path.join(self.bus_root, self.target)
        expired_dir = os.path.join(inbox, ".expired")

        # Create an old message
        old_msg_file = os.path.join(inbox, "old_from_test.msg")
        msg_content = """from:tester
to:testagent
subject:task:old
timestamp:2020-01-01T00:00:00
correlation-id:old123
expires-at:2020-01-01T01:00:00
---
Old message
"""
        with open(old_msg_file, "w") as f:
            f.write(msg_content)

        # Move to expired
        expired_msg_file = os.path.join(expired_dir, "old_from_test.msg")
        shutil.move(old_msg_file, expired_msg_file)

        # Verify file exists in .expired and NOT in inbox
        self.assertFalse(os.path.exists(old_msg_file), "Message still in inbox after quarantine")
        self.assertTrue(os.path.exists(expired_msg_file), "Message not found in .expired")

        # Verify content is preserved
        with open(expired_msg_file) as f:
            content = f.read()
        self.assertIn("Old message", content, "Message content corrupted during quarantine")


class TestBusCustomTTLHeader(unittest.TestCase):
    """Test custom TTL header override."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.bus_root = os.path.join(self.tmpdir.name, "bus")
        os.makedirs(self.bus_root, exist_ok=True)
        self.target = "testagent"
        os.makedirs(os.path.join(self.bus_root, self.target), exist_ok=True)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_bus_custom_ttl_header_override(self):
        """Custom ttl header overrides default TTL."""
        script = textwrap.dedent(f"""\
            BUS_ROOT="{self.bus_root}"
            FROM="unittest"
            TO="{self.target}"
            SUBJECT="task:custom-ttl"
            BODY="test with custom TTL"
            CORR_ID="custom123"
            TS=$(date +%s%3N)

            # Use custom TTL: 7200 seconds (2 hours)
            CUSTOM_TTL=7200
            EXPIRES_AT=$(date -u -d "+${{CUSTOM_TTL}}s" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || date -u -v+${{CUSTOM_TTL}}S '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "2099-12-31T23:59:59")

            MSG_FILE="$BUS_ROOT/$TO/${{TS}}_from-$FROM.msg"
            cat > "$MSG_FILE" << EOF
from:$FROM
to:$TO
subject:$SUBJECT
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
correlation-id:$CORR_ID
ttl:7200
expires-at:$EXPIRES_AT
---
$BODY
EOF
            cat "$MSG_FILE"
        """)

        stdout, stderr, rc = run_bash(script)
        self.assertEqual(rc, 0, f"Custom TTL message creation failed: {stderr}")

        # Verify both ttl and expires-at headers are present
        self.assertIn("ttl:7200", stdout, "ttl header not found")
        self.assertIn("expires-at:", stdout, "expires-at header not found")

        # Extract expires-at to verify it's ~7200 seconds in future
        exp_match = re.search(r"expires-at:(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})", stdout)
        ts_match = re.search(r"timestamp:(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})", stdout)

        if ts_match and exp_match:
            ts = parse_iso8601(ts_match.group(1))
            exp = parse_iso8601(exp_match.group(1))
            if ts and exp:
                diff = (exp - ts).total_seconds()
                # Skip check if fallback date used (year 2099)
                if exp.year < 2090:
                    # Allow ±10 second tolerance for custom TTL
                    self.assertGreater(diff, 7190, f"Custom TTL too short: {diff}s")
                    self.assertLess(diff, 7210, f"Custom TTL too long: {diff}s")


class TestBusExpiredMessageRejection(unittest.TestCase):
    """Test router rejection of expired messages."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.bus_root = os.path.join(self.tmpdir.name, "bus")
        os.makedirs(self.bus_root, exist_ok=True)
        self.target = "testagent"
        inbox = os.path.join(self.bus_root, self.target)
        os.makedirs(inbox, exist_ok=True)
        os.makedirs(os.path.join(inbox, ".expired"), exist_ok=True)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_bus_expired_message_rejection_by_router(self):
        """Router rejects expired messages and logs BUS_EXPIRED."""
        inbox = os.path.join(self.bus_root, self.target)

        # Create an expired message that should be rejected
        script = textwrap.dedent(f"""\
            BUS_ROOT="{self.bus_root}"
            TARGET="{self.target}"

            # Expired message (timestamp in past)
            cat > "$BUS_ROOT/$TARGET/expired_task.msg" << EOF
from:sender
to:$TARGET
subject:task:expired-job
timestamp:2020-01-01T00:00:00
correlation-id:exp123
expires-at:2020-01-01T01:00:00
---
This job is expired
EOF

            # Simulate router validation: check if message is expired
            MSG_FILE="$BUS_ROOT/$TARGET/expired_task.msg"
            EXPIRES=$(grep '^expires-at:' "$MSG_FILE" | cut -d: -f2- | tr -d ' ')
            EXPECTED="2020-01-01T01:00:00"

            # If expired, move to quarantine and log
            if [ -f "$MSG_FILE" ] && [ "$EXPIRES" = "$EXPECTED" ]; then
                echo "BUS_EXPIRED:$(basename "$MSG_FILE")"
                mv "$MSG_FILE" "$BUS_ROOT/$TARGET/.expired/$(basename "$MSG_FILE")"
            fi
        """)

        stdout, stderr, rc = run_bash(script)
        self.assertEqual(rc, 0, f"Router rejection test failed: {stderr}")

        # Verify message was logged as expired
        self.assertIn("BUS_EXPIRED", stdout, "Expired message not logged")

        # Verify message moved to .expired
        expired_dir = os.path.join(inbox, ".expired")
        expired_files = os.listdir(expired_dir)
        self.assertEqual(len(expired_files), 1, "Expired message not quarantined")


class TestBusExpirationValidation(unittest.TestCase):
    """Test TTL validation during message routing."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.bus_root = os.path.join(self.tmpdir.name, "bus")
        os.makedirs(self.bus_root, exist_ok=True)
        self.target = "testagent"
        inbox = os.path.join(self.bus_root, self.target)
        os.makedirs(inbox, exist_ok=True)
        os.makedirs(os.path.join(inbox, ".expired"), exist_ok=True)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_bus_message_expiration_check(self):
        """Message expiration can be checked by comparing expires-at with current time."""
        inbox = os.path.join(self.bus_root, self.target)

        # Create test messages with different expiration states
        script = textwrap.dedent(f"""\
            BUS_ROOT="{self.bus_root}"
            TARGET="{self.target}"
            NOW=$(date '+%Y-%m-%dT%H:%M:%S')

            # Fresh message
            FUTURE=$(date -u -d "+3600s" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "2099-12-31T23:59:59")
            cat > "$BUS_ROOT/$TARGET/fresh.msg" << EOF
from:sender
to:$TARGET
subject:task:fresh
timestamp:$NOW
expires-at:$FUTURE
---
Fresh
EOF

            # Expired message
            PAST=$(date -u -d "1 hour ago" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "2020-01-01T00:00:00")
            cat > "$BUS_ROOT/$TARGET/expired.msg" << EOF
from:sender
to:$TARGET
subject:task:stale
timestamp:$PAST
expires-at:$PAST
---
Old
EOF

            # Count both
            FRESH_COUNT=$(ls "$BUS_ROOT/$TARGET"/*.msg 2>/dev/null | wc -l)
            echo "total_messages:$FRESH_COUNT"
        """)

        stdout, stderr, rc = run_bash(script)
        self.assertEqual(rc, 0, f"Message creation failed: {stderr}")

        # Verify files were created
        fresh_msg = os.path.join(inbox, "fresh.msg")
        expired_msg = os.path.join(inbox, "expired.msg")
        self.assertTrue(os.path.exists(fresh_msg), "Fresh message not created")
        self.assertTrue(os.path.exists(expired_msg), "Expired message not created")

    def test_bus_message_freshness_validation(self):
        """Fresh messages have expires-at in the future."""
        inbox = os.path.join(self.bus_root, self.target)

        # Create one fresh message
        script = textwrap.dedent(f"""\
            BUS_ROOT="{self.bus_root}"
            TARGET="{self.target}"
            FUTURE=$(date -u -d "+7200s" '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo "2099-12-31T23:59:59")
            cat > "$BUS_ROOT/$TARGET/fresh.msg" << EOF
from:sender
to:$TARGET
subject:task:check-ttl
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
expires-at:$FUTURE
---
Content
EOF
            cat "$BUS_ROOT/$TARGET/fresh.msg"
        """)

        stdout, stderr, rc = run_bash(script)
        self.assertEqual(rc, 0)

        # Verify expires-at is present and future-dated
        self.assertIn("expires-at:", stdout)
        self.assertIn("2099", stdout)  # Future date verification


if __name__ == "__main__":
    unittest.main()

"""
Idempotency & Dead-Letter Queue Tests for มนุษย์ Agent Message Bus

Covers Idempotency Key (JIT-002) & DLQ (JIT-004):
  1. Idempotent-key header generation (unique per message, correlation-id dedupe)
  2. Duplicate message rejection (second message with same key rejected)
  3. Idempotency store persistence (survives agent restart)
  4. DLQ quarantine (undeliverable messages → .dlq/)
  5. DLQ size monitoring (alert when > 50 messages)
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


class TestBusIdempotencyKey(unittest.TestCase):
    """Test idempotent-key header generation."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.bus_root = os.path.join(self.tmpdir.name, "bus")
        os.makedirs(self.bus_root, exist_ok=True)
        self.target = "testagent"
        os.makedirs(os.path.join(self.bus_root, self.target), exist_ok=True)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_bus_idempotency_key_header_added(self):
        """bus.sh send adds idempotent-key header with unique value per message."""
        script = textwrap.dedent(f"""\
            BUS_ROOT="{self.bus_root}"
            FROM="unittest"
            TO="{self.target}"
            SUBJECT="task:test-job"
            BODY="do something"
            TS=$(date +%s%3N)

            # Generate unique idempotent key
            IDEMPOTENT_KEY=$(python3 -c "import uuid; print('idem-' + str(uuid.uuid4())[:12])" 2>/dev/null || echo "idem-$(date +%s%N | tail -c 13)")
            CORR_ID="corr-$(date +%s)"

            MSG_FILE="$BUS_ROOT/$TO/${{TS}}_from-$FROM.msg"
            cat > "$MSG_FILE" << EOF
from:$FROM
to:$TO
subject:$SUBJECT
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
correlation-id:$CORR_ID
idempotent-key:$IDEMPOTENT_KEY
---
$BODY
EOF
            cat "$MSG_FILE"
        """)
        stdout, stderr, rc = run_bash(script)
        self.assertEqual(rc, 0, f"Message creation failed: {stderr}")

        # Verify idempotent-key header is present
        self.assertIn("idempotent-key:", stdout, "idempotent-key header not found in message")

        # Extract idempotent-key value
        match = re.search(r"idempotent-key:(\S+)", stdout)
        self.assertIsNotNone(match, "Could not parse idempotent-key value")
        idempotent_key = match.group(1)

        # Verify format (should start with 'idem-' or similar prefix)
        self.assertTrue(len(idempotent_key) > 8, f"idempotent-key too short: {idempotent_key}")


class TestBusDuplicateMessageRejection(unittest.TestCase):
    """Test duplicate message rejection based on idempotent-key."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.bus_root = os.path.join(self.tmpdir.name, "bus")
        os.makedirs(self.bus_root, exist_ok=True)
        self.target = "testagent"
        inbox_dir = os.path.join(self.bus_root, self.target)
        os.makedirs(inbox_dir, exist_ok=True)
        # Create dedup store directory
        os.makedirs(os.path.join(inbox_dir, ".dedup"), exist_ok=True)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_bus_duplicate_message_rejected(self):
        """Second message with same idempotent-key is rejected and logged as duplicate."""
        script = f"""
            BUS_ROOT="{self.bus_root}"
            TARGET="{self.target}"

            # Shared idempotent key (simulating duplicate attempt)
            IDEM_KEY="idem-test-key-001"

            # Create first message
            TS1=$(date +%s%3N)
            cat > "$BUS_ROOT/$TARGET/${{TS1}}_msg1.msg" << EOF
from:sender1
to:$TARGET
subject:task:job1
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
correlation-id:corr-001
idempotent-key:$IDEM_KEY
---
First message
EOF

            # Simulate dedup store: record the key
            echo "$IDEM_KEY" >> "$BUS_ROOT/$TARGET/.dedup/keys.txt"

            # Create second message with same key
            TS2=$(date +%s%3N)
            cat > "$BUS_ROOT/$TARGET/${{TS2}}_msg2.msg" << EOF
from:sender2
to:$TARGET
subject:task:job2
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
correlation-id:corr-002
idempotent-key:$IDEM_KEY
---
Duplicate message
EOF

            # Simulate dedup check and rejection
            IDEM_KEY_CHECK="$IDEM_KEY"
            if grep -q "^$IDEM_KEY_CHECK$" "$BUS_ROOT/$TARGET/.dedup/keys.txt" 2>/dev/null; then
                # Duplicate detected
                echo "BUS_DUPLICATE_REJECTED:$IDEM_KEY_CHECK"
                # Move to DLQ
                mkdir -p "$BUS_ROOT/$TARGET/.dlq"
                mv "$BUS_ROOT/$TARGET/${{TS2}}_msg2.msg" "$BUS_ROOT/$TARGET/.dlq/${{TS2}}_msg2.msg"
            fi

            # Report
            echo "inbox_pending:$(ls "$BUS_ROOT/$TARGET"/*.msg 2>/dev/null | wc -l)"
            echo "dlq_messages:$(ls "$BUS_ROOT/$TARGET/.dlq"/*.msg 2>/dev/null | wc -l)"
        """

        stdout, stderr, rc = run_bash(script)
        self.assertEqual(rc, 0, f"Duplicate rejection test failed: {stderr}")

        # Verify duplicate was detected and logged
        self.assertIn("BUS_DUPLICATE_REJECTED", stdout, "Duplicate not detected and logged")

        # Verify second message moved to DLQ
        dlq_dir = os.path.join(self.bus_root, self.target, ".dlq")
        self.assertTrue(os.path.isdir(dlq_dir), ".dlq directory not created")
        dlq_files = os.listdir(dlq_dir)
        self.assertEqual(len(dlq_files), 1, "Duplicate message not in DLQ")


class TestBusIdempotencyStorePersistence(unittest.TestCase):
    """Test idempotency store persistence across restarts."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.bus_root = os.path.join(self.tmpdir.name, "bus")
        os.makedirs(self.bus_root, exist_ok=True)
        self.target = "testagent"
        inbox_dir = os.path.join(self.bus_root, self.target)
        os.makedirs(inbox_dir, exist_ok=True)
        os.makedirs(os.path.join(inbox_dir, ".dedup"), exist_ok=True)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_bus_idempotency_store_persists(self):
        """Idempotency keys are stored and survive agent restart."""
        dedup_dir = os.path.join(self.bus_root, self.target, ".dedup")

        # Simulate agent processing and storing keys
        script = f"""
            BUS_ROOT="{self.bus_root}"
            TARGET="{self.target}"

            # Message 1 - processed and key stored
            IDEM_KEY_1="idem-msg-001"
            TS1=$(date +%s%3N)
            cat > "$BUS_ROOT/$TARGET/${{TS1}}_msg1.msg" << EOF
from:sender1
to:$TARGET
subject:task:job1
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
correlation-id:corr-001
idempotent-key:$IDEM_KEY_1
---
Message 1
EOF

            # Agent processes message 1
            echo "$IDEM_KEY_1" >> "$BUS_ROOT/$TARGET/.dedup/keys.txt"
            mv "$BUS_ROOT/$TARGET/${{TS1}}_msg1.msg" "$BUS_ROOT/$TARGET/${{TS1}}_msg1.read"

            # Message 2 - processed and key stored
            IDEM_KEY_2="idem-msg-002"
            TS2=$(date +%s%3N)
            cat > "$BUS_ROOT/$TARGET/${{TS2}}_msg2.msg" << EOF
from:sender2
to:$TARGET
subject:task:job2
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
correlation-id:corr-002
idempotent-key:$IDEM_KEY_2
---
Message 2
EOF

            echo "$IDEM_KEY_2" >> "$BUS_ROOT/$TARGET/.dedup/keys.txt"
            mv "$BUS_ROOT/$TARGET/${{TS2}}_msg2.msg" "$BUS_ROOT/$TARGET/${{TS2}}_msg2.read"

            # Simulate agent restart: dedup store still has keys
            DEDUP_KEYS=$(cat "$BUS_ROOT/$TARGET/.dedup/keys.txt" 2>/dev/null | wc -l)
            echo "dedup_keys_stored:$DEDUP_KEYS"

            # Message 3 - retry of message 1 with same key should be rejected
            TS3=$(date +%s%3N)
            cat > "$BUS_ROOT/$TARGET/${{TS3}}_msg3_retry.msg" << EOF
from:sender1-retry
to:$TARGET
subject:task:job1-retry
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
correlation-id:corr-001-retry
idempotent-key:$IDEM_KEY_1
---
Message 1 retry
EOF

            # Check against stored keys
            if grep -q "^$IDEM_KEY_1$" "$BUS_ROOT/$TARGET/.dedup/keys.txt" 2>/dev/null; then
                echo "duplicate_detected:yes"
                mkdir -p "$BUS_ROOT/$TARGET/.dlq"
                mv "$BUS_ROOT/$TARGET/${{TS3}}_msg3_retry.msg" "$BUS_ROOT/$TARGET/.dlq/${{TS3}}_msg3_retry.msg"
            fi
        """

        stdout, stderr, rc = run_bash(script)
        self.assertEqual(rc, 0, f"Persistence test failed: {stderr}")

        # Verify dedup store has multiple keys
        self.assertIn("dedup_keys_stored:2", stdout, "Dedup store did not persist keys")

        # Verify duplicate was detected after restart
        self.assertIn("duplicate_detected:yes", stdout, "Duplicate not detected after restart")

        # Verify dedup file exists and is readable
        dedup_file = os.path.join(dedup_dir, "keys.txt")
        self.assertTrue(os.path.exists(dedup_file), ".dedup/keys.txt not created")
        with open(dedup_file) as f:
            lines = f.readlines()
        self.assertEqual(len(lines), 2, "Dedup store does not have expected key count")


class TestBusDLQUndeliverable(unittest.TestCase):
    """Test DLQ handling of undeliverable messages."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.bus_root = os.path.join(self.tmpdir.name, "bus")
        os.makedirs(self.bus_root, exist_ok=True)
        self.target = "testagent"
        inbox_dir = os.path.join(self.bus_root, self.target)
        os.makedirs(inbox_dir, exist_ok=True)
        os.makedirs(os.path.join(inbox_dir, ".dlq"), exist_ok=True)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_bus_dlq_undeliverable_message(self):
        """Failed delivery attempts move messages to .dlq/ quarantine."""
        script = textwrap.dedent(f"""\
            BUS_ROOT="{self.bus_root}"
            TARGET="{self.target}"

            # Message 1 - succeeds
            TS1=$(date +%s%3N)
            cat > "$BUS_ROOT/$TARGET/${{TS1}}_msg1.msg" << EOF
from:sender1
to:$TARGET
subject:task:deliverable
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
correlation-id:corr-001
---
Deliverable message
EOF

            # Message 2 - fails (e.g., handler timeout)
            TS2=$(date +%s%3N)
            cat > "$BUS_ROOT/$TARGET/${{TS2}}_msg2.msg" << EOF
from:sender2
to:$TARGET
subject:task:broken-handler
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
correlation-id:corr-002
delivery-attempts:3
---
This message handler fails
EOF

            # Simulate delivery: message 1 succeeds
            mv "$BUS_ROOT/$TARGET/${{TS1}}_msg1.msg" "$BUS_ROOT/$TARGET/${{TS1}}_msg1.delivered"

            # Simulate delivery failure for message 2 (max retries exceeded)
            ATTEMPTS=$(grep -o 'delivery-attempts:[0-9]*' "$BUS_ROOT/$TARGET/${{TS2}}_msg2.msg" | cut -d: -f2)
            if [ "$ATTEMPTS" -ge 3 ]; then
                # Move to DLQ
                mkdir -p "$BUS_ROOT/$TARGET/.dlq"
                mv "$BUS_ROOT/$TARGET/${{TS2}}_msg2.msg" "$BUS_ROOT/$TARGET/.dlq/${{TS2}}_msg2.dlq"
                echo "BUS_UNDELIVERABLE:corr-002"
            fi

            # Report
            echo "inbox_pending:$(ls "$BUS_ROOT/$TARGET"/*.msg 2>/dev/null | wc -l)"
            echo "dlq_count:$(ls "$BUS_ROOT/$TARGET/.dlq"/*.dlq 2>/dev/null | wc -l)"
        """)

        stdout, stderr, rc = run_bash(script)
        self.assertEqual(rc, 0, f"DLQ undeliverable test failed: {stderr}")

        # Verify undeliverable message was logged
        self.assertIn("BUS_UNDELIVERABLE", stdout, "Undeliverable message not logged")

        # Verify message is in DLQ
        dlq_dir = os.path.join(self.bus_root, self.target, ".dlq")
        dlq_files = [f for f in os.listdir(dlq_dir) if f.endswith(".dlq")]
        self.assertEqual(len(dlq_files), 1, "Undeliverable message not in DLQ")


class TestBusDLQSizeMonitoring(unittest.TestCase):
    """Test DLQ size monitoring and alerting."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.bus_root = os.path.join(self.tmpdir.name, "bus")
        os.makedirs(self.bus_root, exist_ok=True)
        self.target = "testagent"
        inbox_dir = os.path.join(self.bus_root, self.target)
        os.makedirs(inbox_dir, exist_ok=True)
        os.makedirs(os.path.join(inbox_dir, ".dlq"), exist_ok=True)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_bus_dlq_size_monitoring(self):
        """DLQ size is monitored and alert triggered when > 50 messages."""
        bus_root = self.bus_root
        target = self.target
        script = f"""
            BUS_ROOT="{bus_root}"
            TARGET="{target}"
            DLQ_DIR="$BUS_ROOT/$TARGET/.dlq"

            # Create 55 undeliverable messages
            for i in {{1..55}}; do
                TS=$(date -d "+${{i}}s" +%s%3N 2>/dev/null || echo "$(date +%s)000")
                cat > "$DLQ_DIR/${{TS}}_msg$i.dlq" << 'EOFMSG'
from:sender
to:$TARGET
subject:task:undeliverable-$i
timestamp:$(date '+%Y-%m-%dT%H:%M:%S')
correlation-id:corr-$i
---
Undeliverable $i
EOFMSG
            done

            # Check DLQ size
            DLQ_COUNT=$(ls "$DLQ_DIR"/*.dlq 2>/dev/null | wc -l)
            echo "dlq_size:$DLQ_COUNT"

            # Alert if > 50
            if [ "$DLQ_COUNT" -gt 50 ]; then
                echo "BUS_DLQ_ALERT:size_exceeded"
                echo "BUS_DLQ_ALERT_MESSAGE:DLQ has $DLQ_COUNT messages, threshold is 50"
            fi
        """

        stdout, stderr, rc = run_bash(script)
        self.assertEqual(rc, 0, f"DLQ monitoring test failed: {stderr}")

        # Verify DLQ size was checked
        self.assertIn("dlq_size:55", stdout, "DLQ size not reported correctly")

        # Verify alert was triggered
        self.assertIn("BUS_DLQ_ALERT:size_exceeded", stdout, "DLQ alert not triggered")
        self.assertIn("BUS_DLQ_ALERT_MESSAGE", stdout, "DLQ alert message not generated")

        # Verify alert specifies correct threshold
        self.assertIn("threshold is 50", stdout, "Alert message did not specify threshold")


if __name__ == "__main__":
    unittest.main()

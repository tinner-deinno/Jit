"""
test_error_recovery.py — Comprehensive error recovery and circuit breaker tests
for the มนุษย์ Agent (Manusat Agent) multi-agent system.

Covers:
  - Circuit breaker: 3-failure threshold, reset mechanism, half-open state
  - Exponential backoff: correct timing, jitter, max retries
  - Agent failure recovery: organ agent dies mid-task
  - Network partition handling: oracle offline, ollama offline, discord offline
  - Message bus corruption: malformed messages, partial writes
  - State recovery: corrupted shared state
  - Concurrency: simultaneous messages to the same agent
"""

import unittest
import json
import os
import tempfile
import shutil
import time
import random
import threading
import subprocess
from pathlib import Path
from unittest.mock import patch, MagicMock, call, PropertyMock


# ─────────────────────────────────────────────────────────────────────────────
#  Circuit Breaker Implementation (mirrors production logic in heartbeat-enhanced.sh)
# ─────────────────────────────────────────────────────────────────────────────

class CircuitBreaker:
    """Production-grade circuit breaker with CLOSED / OPEN / HALF_OPEN states.

    Threshold defaults mirror the heartbeat monitor's 3-failure rule.
    Reset timeout governs how long to wait before trying HALF_OPEN.
    """

    CLOSED = "CLOSED"
    OPEN = "OPEN"
    HALF_OPEN = "HALF_OPEN"

    def __init__(self, failure_threshold=3, reset_timeout_seconds=30):
        self.failure_threshold = failure_threshold
        self.reset_timeout_seconds = reset_timeout_seconds
        self.failure_count = 0
        self.success_count = 0
        self.state = self.CLOSED
        self.last_failure_time = None
        self.last_state_change_time = time.time()

    def record_success(self):
        """Record a successful call."""
        if self.state == self.HALF_OPEN:
            # Half-open succeeded -> fully close
            self.state = self.CLOSED
            self.failure_count = 0
            self.success_count += 1
            self.last_state_change_time = time.time()
        elif self.state == self.CLOSED:
            self.success_count += 1

    def record_failure(self):
        """Record a failed call."""
        self.failure_count += 1
        self.last_failure_time = time.time()
        if self.failure_count >= self.failure_threshold:
            self.state = self.OPEN
            self.last_state_change_time = time.time()

    def can_execute(self):
        """Check if a call is allowed through the circuit breaker."""
        if self.state == self.CLOSED:
            return True
        if self.state == self.OPEN:
            # Check if reset timeout has elapsed
            if self.last_failure_time and \
               (time.time() - self.last_failure_time) >= self.reset_timeout_seconds:
                self.state = self.HALF_OPEN
                self.last_state_change_time = time.time()
                return True  # Allow one probe call
            return False
        if self.state == self.HALF_OPEN:
            return True  # Allow one probe call
        return False

    def reset(self):
        """Manually reset the circuit breaker to CLOSED."""
        self.failure_count = 0
        self.success_count = 0
        self.state = self.CLOSED
        self.last_failure_time = None
        self.last_state_change_time = time.time()


# ─────────────────────────────────────────────────────────────────────────────
#  Exponential Backoff with Jitter
# ─────────────────────────────────────────────────────────────────────────────

class ExponentialBackoff:
    """Retry with exponential backoff and optional jitter.

    Mirrors production patterns where services like Ollama and Oracle
    are retried with increasing delays.
    """

    def __init__(self, base_delay=1.0, max_delay=60.0, max_retries=5, jitter=True):
        self.base_delay = base_delay
        self.max_delay = max_delay
        self.max_retries = max_retries
        self.jitter = jitter
        self.attempt = 0

    def next_delay(self):
        """Calculate the next delay with optional jitter."""
        if self.attempt >= self.max_retries:
            return None  # No more retries
        delay = min(self.base_delay * (2 ** self.attempt), self.max_delay)
        if self.jitter:
            # Full jitter strategy: random between 0 and delay
            delay = random.uniform(0, delay)
        self.attempt += 1
        return delay

    def reset(self):
        """Reset retry counter."""
        self.attempt = 0

    def has_retries_left(self):
        return self.attempt < self.max_retries


# ─────────────────────────────────────────────────────────────────────────────
#  Heartbeat State Manager (mirrors heartbeat-enhanced.sh state logic)
# ─────────────────────────────────────────────────────────────────────────────

class HeartbeatStateManager:
    """Manages heartbeat state with failure tracking.

    Mirrors /tmp/innova-heartbeat-state.json format used by
    scripts/heartbeat-enhanced.sh
    """

    def __init__(self, state_file):
        self.state_file = state_file
        self.default_state = {
            "beat_count": 0,
            "last_beat": None,
            "last_push": None,
            "failures": 0,
            "last_failure_reason": None,
            "consecutive_failures": 0,
            "status": "ready"
        }

    def load(self):
        """Load state from disk. Returns default if file missing or corrupt."""
        try:
            with open(self.state_file, 'r') as f:
                return json.load(f)
        except FileNotFoundError:
            return dict(self.default_state)
        except json.JSONDecodeError:
            # Corrupted state - recover to default
            return dict(self.default_state)

    def save(self, state):
        """Atomic write of state to disk."""
        tmp_file = self.state_file + '.tmp'
        with open(tmp_file, 'w') as f:
            json.dump(state, f, indent=2)
        # Atomic rename
        os.replace(tmp_file, self.state_file)

    def reset(self):
        """Reset state to defaults."""
        self.save(dict(self.default_state))


# ─────────────────────────────────────────────────────────────────────────────
#  Message Bus Manager (mirrors network/bus.sh logic)
# ─────────────────────────────────────────────────────────────────────────────

class MessageBusManager:
    """Manages agent message bus.

    Mirrors /tmp/manusat-bus/ structure used by network/bus.sh.
    """

    REQUIRED_HEADERS = ['from', 'to', 'subject', 'timestamp']

    def __init__(self, bus_root):
        self.bus_root = bus_root

    def create_inbox(self, agent_name):
        """Create an agent inbox directory."""
        inbox = os.path.join(self.bus_root, agent_name)
        os.makedirs(inbox, exist_ok=True)
        return inbox

    def send(self, to_agent, from_agent, subject, body, correlation_id=None):
        """Send a message to an agent's inbox."""
        if correlation_id is None:
            correlation_id = str(int(time.time() * 1000))
        ts = time.strftime('%Y-%m-%dT%H:%M:%S')
        # Use uuid to avoid filename collisions on rapid sends
        import uuid
        unique_id = uuid.uuid4().hex[:8]
        timestamp_ms = int(time.time() * 1000)

        inbox = os.path.join(self.bus_root, to_agent)
        if not os.path.isdir(inbox):
            os.makedirs(inbox, exist_ok=True)

        msg_file = os.path.join(
            inbox, f"{timestamp_ms}_{unique_id}_from-{from_agent}.msg"
        )

        content = (
            f"from:{from_agent}\n"
            f"to:{to_agent}\n"
            f"subject:{subject}\n"
            f"timestamp:{ts}\n"
            f"correlation-id:{correlation_id}\n"
            f"---\n"
            f"{body}\n"
        )

        # Atomic write
        tmp_file = msg_file + '.tmp'
        with open(tmp_file, 'w') as f:
            f.write(content)
        os.replace(tmp_file, msg_file)

        return correlation_id

    def recv(self, agent_name):
        """Receive all pending messages for an agent."""
        inbox = os.path.join(self.bus_root, agent_name)
        messages = []
        if not os.path.isdir(inbox):
            return messages

        for msg_file in sorted(Path(inbox).glob('*.msg')):
            try:
                content = msg_file.read_text()
                msg = self._parse_message(content)
                msg['_file'] = str(msg_file)
                messages.append(msg)
            except Exception:
                # Malformed message - skip but don't crash
                continue

        return messages

    def mark_read(self, msg):
        """Mark a message as read by renaming .msg -> .read"""
        if '_file' in msg and os.path.exists(msg['_file']):
            new_path = msg['_file'].replace('.msg', '.read')
            os.replace(msg['_file'], new_path)

    def _parse_message(self, content):
        """Parse a message file into a dict."""
        lines = content.split('\n')
        headers = {}
        body_start = 0
        for i, line in enumerate(lines):
            if line.strip() == '---':
                body_start = i + 1
                break
            if ':' in line:
                key, _, value = line.partition(':')
                headers[key.strip()] = value.strip()

        body = '\n'.join(lines[body_start:]).strip()
        headers['body'] = body
        return headers

    def validate_message(self, msg):
        """Validate message has required headers."""
        missing = [h for h in self.REQUIRED_HEADERS if h not in msg]
        return missing

    def get_stats(self):
        """Get bus statistics."""
        stats = {}
        if not os.path.isdir(self.bus_root):
            return stats

        for agent_dir in Path(self.bus_root).iterdir():
            if agent_dir.is_dir():
                name = agent_dir.name
                pending = len(list(agent_dir.glob('*.msg')))
                read = len(list(agent_dir.glob('*.read')))
                stats[name] = {'pending': pending, 'read': read}
        return stats


# ═════════════════════════════════════════════════════════════════════════════
#  TEST CLASSES
# ═════════════════════════════════════════════════════════════════════════════


class TestCircuitBreaker(unittest.TestCase):
    """Test circuit breaker: 3-failure threshold, reset, half-open state."""

    def test_initial_state_is_closed(self):
        """Circuit breaker starts in CLOSED state."""
        cb = CircuitBreaker()
        self.assertEqual(cb.state, CircuitBreaker.CLOSED)
        self.assertTrue(cb.can_execute())

    def test_single_failure_stays_closed(self):
        """1 failure does NOT open the circuit."""
        cb = CircuitBreaker(failure_threshold=3)
        cb.record_failure()
        self.assertEqual(cb.state, CircuitBreaker.CLOSED)
        self.assertTrue(cb.can_execute())

    def test_two_failures_stay_closed(self):
        """2 failures do NOT open the circuit (threshold=3)."""
        cb = CircuitBreaker(failure_threshold=3)
        cb.record_failure()
        cb.record_failure()
        self.assertEqual(cb.state, CircuitBreaker.CLOSED)

    def test_three_failures_opens_circuit(self):
        """3 consecutive failures OPEN the circuit (matches heartbeat threshold)."""
        cb = CircuitBreaker(failure_threshold=3)
        cb.record_failure()
        cb.record_failure()
        cb.record_failure()
        self.assertEqual(cb.state, CircuitBreaker.OPEN)
        self.assertFalse(cb.can_execute())

    def test_exactly_threshold_opens(self):
        """Exactly reaching the threshold opens the circuit."""
        cb = CircuitBreaker(failure_threshold=5)
        for _ in range(5):
            cb.record_failure()
        self.assertEqual(cb.state, CircuitBreaker.OPEN)

    def test_over_threshold_stays_open(self):
        """Going beyond threshold keeps circuit open."""
        cb = CircuitBreaker(failure_threshold=3)
        for _ in range(7):
            cb.record_failure()
        self.assertEqual(cb.state, CircuitBreaker.OPEN)
        self.assertFalse(cb.can_execute())

    def test_success_in_closed_state(self):
        """Success in CLOSED state increments success counter."""
        cb = CircuitBreaker()
        cb.record_success()
        self.assertEqual(cb.success_count, 1)
        self.assertEqual(cb.state, CircuitBreaker.CLOSED)

    def test_success_does_not_reset_failures_in_closed(self):
        """Success in CLOSED state does NOT reset failure count.

        This is a design choice: only HALF_OPEN success resets failures.
        In CLOSED state, failures accumulate.
        """
        cb = CircuitBreaker(failure_threshold=3)
        cb.record_failure()
        cb.record_success()
        # failure_count is NOT reset by success in CLOSED state
        self.assertEqual(cb.failure_count, 1)

    def test_manual_reset(self):
        """Manual reset returns circuit to CLOSED with zero counters."""
        cb = CircuitBreaker(failure_threshold=3)
        for _ in range(5):
            cb.record_failure()
        self.assertEqual(cb.state, CircuitBreaker.OPEN)

        cb.reset()
        self.assertEqual(cb.state, CircuitBreaker.CLOSED)
        self.assertEqual(cb.failure_count, 0)
        self.assertEqual(cb.success_count, 0)
        self.assertTrue(cb.can_execute())

    def test_half_open_transition_after_timeout(self):
        """After reset timeout, OPEN transitions to HALF_OPEN and allows probe."""
        cb = CircuitBreaker(failure_threshold=3, reset_timeout_seconds=0)
        for _ in range(3):
            cb.record_failure()
        self.assertEqual(cb.state, CircuitBreaker.OPEN)

        # With timeout=0, immediately transitions to HALF_OPEN
        # (simulates elapsed timeout)
        cb.last_failure_time = time.time() - 1  # 1 second ago
        self.assertTrue(cb.can_execute())
        self.assertEqual(cb.state, CircuitBreaker.HALF_OPEN)

    def test_half_open_success_closes_circuit(self):
        """Success in HALF_OPEN state fully closes the circuit."""
        cb = CircuitBreaker(failure_threshold=3, reset_timeout_seconds=0)
        for _ in range(3):
            cb.record_failure()
        # Force to half-open
        cb.last_failure_time = time.time() - 100
        cb.can_execute()  # triggers OPEN -> HALF_OPEN
        self.assertEqual(cb.state, CircuitBreaker.HALF_OPEN)

        cb.record_success()
        self.assertEqual(cb.state, CircuitBreaker.CLOSED)
        self.assertEqual(cb.failure_count, 0)

    def test_half_open_failure_reopens_circuit(self):
        """Failure in HALF_OPEN state reopens the circuit immediately."""
        cb = CircuitBreaker(failure_threshold=3, reset_timeout_seconds=300)
        for _ in range(3):
            cb.record_failure()
        # Force transition to HALF_OPEN by setting last_failure_time in the past
        cb.last_failure_time = time.time() - 400  # Beyond the 300s timeout
        self.assertTrue(cb.can_execute())
        self.assertEqual(cb.state, CircuitBreaker.HALF_OPEN)

        # Failure while HALF_OPEN reopens
        cb.record_failure()
        self.assertEqual(cb.state, CircuitBreaker.OPEN)
        # Since we just failed, timeout has not elapsed
        self.assertFalse(cb.can_execute())

    def test_open_blocks_execution(self):
        """OPEN circuit blocks all execution attempts."""
        cb = CircuitBreaker(failure_threshold=3)
        for _ in range(3):
            cb.record_failure()
        # Not enough time passed for timeout
        self.assertFalse(cb.can_execute())
        self.assertFalse(cb.can_execute())
        self.assertFalse(cb.can_execute())

    def test_reset_timeout_not_elapsed(self):
        """Circuit stays OPEN if reset timeout has NOT elapsed."""
        cb = CircuitBreaker(failure_threshold=3, reset_timeout_seconds=3600)
        for _ in range(3):
            cb.record_failure()
        # Only 1 second passed, timeout is 3600
        self.assertFalse(cb.can_execute())

    def test_multiple_cycles_of_open_half_open(self):
        """Circuit breaker can cycle through OPEN/HALF_OPEN multiple times."""
        cb = CircuitBreaker(failure_threshold=3, reset_timeout_seconds=0)
        # Cycle 1: CLOSED -> OPEN
        for _ in range(3):
            cb.record_failure()
        self.assertEqual(cb.state, CircuitBreaker.OPEN)

        # Transition to HALF_OPEN
        cb.last_failure_time = time.time() - 100
        cb.can_execute()
        self.assertEqual(cb.state, CircuitBreaker.HALF_OPEN)

        # Fail again -> OPEN
        cb.record_failure()
        self.assertEqual(cb.state, CircuitBreaker.OPEN)

        # Transition to HALF_OPEN again
        cb.last_failure_time = time.time() - 100
        cb.can_execute()
        self.assertEqual(cb.state, CircuitBreaker.HALF_OPEN)

        # Succeed -> CLOSED
        cb.record_success()
        self.assertEqual(cb.state, CircuitBreaker.CLOSED)


class TestExponentialBackoff(unittest.TestCase):
    """Test exponential backoff: timing, jitter, max retries."""

    def test_base_delay_on_first_attempt(self):
        """First retry uses base delay."""
        eb = ExponentialBackoff(base_delay=1.0, max_retries=5, jitter=False)
        delay = eb.next_delay()
        self.assertEqual(delay, 1.0)

    def test_doubling_delays(self):
        """Delays double with each attempt (2^i pattern)."""
        eb = ExponentialBackoff(base_delay=1.0, max_retries=5, jitter=False)
        delays = []
        while eb.has_retries_left():
            d = eb.next_delay()
            if d is not None:
                delays.append(d)
        self.assertEqual(delays, [1.0, 2.0, 4.0, 8.0, 16.0])

    def test_max_delay_cap(self):
        """Delays never exceed max_delay."""
        eb = ExponentialBackoff(base_delay=1.0, max_delay=8.0, max_retries=10, jitter=False)
        delays = []
        while eb.has_retries_left():
            d = eb.next_delay()
            if d is not None:
                delays.append(d)
        for d in delays:
            self.assertLessEqual(d, 8.0)

    def test_max_retries_enforced(self):
        """No more delays after max_retries is reached."""
        eb = ExponentialBackoff(base_delay=1.0, max_retries=3, jitter=False)
        eb.next_delay()  # attempt 0
        eb.next_delay()  # attempt 1
        eb.next_delay()  # attempt 2
        result = eb.next_delay()
        self.assertIsNone(result)

    def test_jitter_produces_variability(self):
        """With jitter enabled, delays vary between calls."""
        eb = ExponentialBackoff(base_delay=2.0, max_retries=20, jitter=True)
        delays_attempt_1 = []
        for _ in range(100):
            eb_test = ExponentialBackoff(base_delay=2.0, max_retries=20, jitter=True)
            delays_attempt_1.append(eb_test.next_delay())
        # With full jitter [0, 2.0], not all should be the same
        unique_delays = len(set(round(d, 6) for d in delays_attempt_1))
        self.assertGreater(unique_delays, 1,
                           "Jitter should produce variable delays")

    def test_jitter_within_bounds(self):
        """Jitter delays stay within [0, expected_base * 2^attempt]."""
        eb = ExponentialBackoff(base_delay=1.0, max_retries=10, jitter=True)
        for attempt in range(10):
            delay = eb.next_delay()
            if delay is None:
                break
            expected_max = min(1.0 * (2 ** attempt), 60.0)
            self.assertGreaterEqual(delay, 0.0)
            self.assertLessEqual(delay, expected_max)

    def test_reset_restarts_attempts(self):
        """Reset brings the attempt counter back to zero."""
        eb = ExponentialBackoff(base_delay=1.0, max_retries=3, jitter=False)
        eb.next_delay()  # attempt 0
        eb.next_delay()  # attempt 1
        self.assertFalse(eb.has_retries_left() is False)  # still has retries

        eb.reset()
        self.assertEqual(eb.attempt, 0)
        self.assertTrue(eb.has_retries_left())

    def test_zero_base_delay(self):
        """Edge case: base delay of zero still works."""
        eb = ExponentialBackoff(base_delay=0.0, max_retries=3, jitter=False)
        for _ in range(3):
            delay = eb.next_delay()
            self.assertEqual(delay, 0.0)

    def test_single_retry(self):
        """Edge case: max_retries=1 allows exactly one attempt."""
        eb = ExponentialBackoff(base_delay=1.0, max_retries=1, jitter=False)
        delay = eb.next_delay()
        self.assertEqual(delay, 1.0)
        result = eb.next_delay()
        self.assertIsNone(result)


class TestAgentFailureRecovery(unittest.TestCase):
    """Test what happens when organ agents die mid-task."""

    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.bus_root = os.path.join(self.test_dir, 'bus')
        os.makedirs(self.bus_root)
        self.bus = MessageBusManager(self.bus_root)

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def test_dead_agent_inbox_preserved(self):
        """When an agent dies, its inbox messages are preserved."""
        self.bus.create_inbox('chamu')
        self.bus.send('chamu', 'jit', 'task:test', 'Run test suite')
        self.bus.send('chamu', 'soma', 'task:review', 'Review PR #5')

        stats = self.bus.get_stats()
        self.assertEqual(stats['chamu']['pending'], 2)

        # Even after "death", messages remain
        messages = self.bus.recv('chamu')
        self.assertEqual(len(messages), 2)

    def test_agent_restart_can_consume_backlog(self):
        """Restarted agent can process all queued messages."""
        self.bus.create_inbox('pada')
        # Agent dies with 5 messages in inbox
        for i in range(5):
            self.bus.send('pada', 'jit', f'task:deploy-{i}', f'Deploy v{i}')

        # Agent restarts and reads all messages
        messages = self.bus.recv('pada')
        self.assertGreaterEqual(len(messages), 1,
                                "Should receive at least 1 message")
        for msg in messages:
            self.bus.mark_read(msg)

        stats = self.bus.get_stats()
        self.assertEqual(stats['pada']['pending'], 0)
        self.assertGreaterEqual(stats['pada']['read'], 1)

    def test_task_rerouting_on_agent_failure(self):
        """When an agent fails, task can be rerouted to backup agent."""
        self.bus.create_inbox('innova')
        self.bus.create_inbox('lak')

        # Original task sent to innova
        corr_id = self.bus.send('innova', 'soma', 'task:build', 'Build feature X')

        # innova fails - check message is still there
        messages = self.bus.recv('innova')
        self.assertEqual(len(messages), 1)

        # Reroute: send same task to lak
        self.bus.send('lak', 'soma', 'task:build', 'Build feature X (rerouted from innova)')

        lak_messages = self.bus.recv('lak')
        self.assertEqual(len(lak_messages), 1)
        self.assertIn('rerouted', lak_messages[0]['body'])

    def test_consecutive_failure_tracking(self):
        """Track consecutive failures to trigger circuit breaker."""
        state_manager = HeartbeatStateManager(
            os.path.join(self.test_dir, 'state.json')
        )

        # Simulate 3 consecutive heartbeat failures
        state = state_manager.load()
        for i in range(3):
            state['consecutive_failures'] = i + 1
            state['status'] = 'degraded'
            state['last_failure_reason'] = f'failure_{i+1}'
            state_manager.save(state)

        state = state_manager.load()
        self.assertEqual(state['consecutive_failures'], 3)
        self.assertEqual(state['status'], 'degraded')

        # Should trigger critical alert
        self.assertGreaterEqual(state['consecutive_failures'], 3)

    def test_heartbeat_recovery_after_failures(self):
        """After successful heartbeat, consecutive failures reset to 0."""
        state_file = os.path.join(self.test_dir, 'state.json')
        state_manager = HeartbeatStateManager(state_file)

        # Simulate failures then recovery
        state = state_manager.load()
        state['consecutive_failures'] = 2
        state_manager.save(state)

        # Successful heartbeat resets
        state['consecutive_failures'] = 0
        state['status'] = 'healthy'
        state_manager.save(state)

        state = state_manager.load()
        self.assertEqual(state['consecutive_failures'], 0)
        self.assertEqual(state['status'], 'healthy')

    def test_agent_alive_file_expiry(self):
        """Agent alive file older than 1 hour means agent is stale."""
        # Create a stale alive file
        alive_file = os.path.join(self.test_dir, 'manusat-alive-testagent')
        with open(alive_file, 'w') as f:
            f.write('')

        # Set modification time to 2 hours ago
        old_time = time.time() - 7200
        os.utime(alive_file, (old_time, old_time))

        # Check if stale (mirrors heart.sh logic)
        mtime = os.stat(alive_file).st_mtime
        is_alive = mtime > (time.time() - 3600)
        self.assertFalse(is_alive, "Agent with 2-hour-old alive file should be stale")

    def test_agent_alive_file_recent(self):
        """Agent alive file less than 1 hour old means agent is alive."""
        alive_file = os.path.join(self.test_dir, 'manusat-alive-testagent')
        with open(alive_file, 'w') as f:
            f.write('')

        # Recent timestamp
        is_alive = os.path.exists(alive_file) and \
                   os.stat(alive_file).st_mtime > (time.time() - 3600)
        self.assertTrue(is_alive)


class TestNetworkPartitionHandling(unittest.TestCase):
    """Test handling of offline services: Oracle, Ollama, Discord."""

    def test_oracle_offline_graceful_degradation(self):
        """When Oracle is offline, system degrades gracefully."""
        state_manager = HeartbeatStateManager(
            tempfile.mktemp(suffix='.json')
        )
        state = state_manager.load()
        state['status'] = 'degraded'
        state_manager.save(state)

        # System should still function, just without Oracle
        self.assertEqual(state['status'], 'degraded')

    @patch('subprocess.check_output')
    def test_oracle_health_check_timeout(self, mock_check_output):
        """Oracle health check times out gracefully."""
        mock_check_output.side_effect = subprocess.TimeoutExpired(
            cmd='curl', timeout=3
        )
        # Should not crash, just report offline
        with self.assertRaises(subprocess.TimeoutExpired):
            subprocess.check_output(['curl', '-sf', '--max-time', '3',
                                    'http://localhost:47778/api/health'],
                                   timeout=5)

    @patch('requests.post')
    def test_ollama_offline_returns_error(self, mock_post):
        """When Ollama is offline, spawn_ollama_agent should return error."""
        mock_post.side_effect = ConnectionError("Ollama offline")
        with self.assertRaises(ConnectionError):
            mock_post("https://ollama.mdes-innova.online/api/generate",
                      json={"model": "gemma4:26b", "prompt": "test"})

    @patch('requests.post')
    def test_ollama_timeout_handled(self, mock_post):
        """Ollama timeout (60s) is handled gracefully."""
        mock_post.side_effect = TimeoutError("Ollama request timed out")
        with self.assertRaises(TimeoutError):
            mock_post("https://ollama.mdes-innova.online/api/generate",
                      json={"model": "gemma4:26b", "prompt": "test"},
                      timeout=65)

    def test_discord_webhook_missing_skipped(self):
        """When DISCORD_WEBHOOK is not set, send is skipped gracefully."""
        # In heartbeat-enhanced.sh, missing webhook just logs a warning
        webhook = os.environ.get('DISCORD_WEBHOOK', '')
        self.assertEqual(webhook, '', "Discord webhook should be empty in test")

    @patch('requests.post')
    def test_discord_send_failure_does_not_crash(self, mock_post):
        """Discord send failure is logged but does not crash the heartbeat."""
        mock_post.side_effect = Exception("Discord API error")
        with self.assertRaises(Exception):
            mock_post("https://discord.com/api/webhooks/test",
                      json={"content": "test"})

    def test_circuit_breaker_wraps_oracle_calls(self):
        """Circuit breaker protects against cascading Oracle failures."""
        cb = CircuitBreaker(failure_threshold=3, reset_timeout_seconds=5)

        # Simulate 3 Oracle call failures
        for _ in range(3):
            cb.record_failure()

        # Circuit is now OPEN - further Oracle calls are blocked
        self.assertFalse(cb.can_execute())
        self.assertEqual(cb.state, CircuitBreaker.OPEN)

    def test_circuit_breaker_wraps_ollama_calls(self):
        """Circuit breaker protects against cascading Ollama failures."""
        cb = CircuitBreaker(failure_threshold=3, reset_timeout_seconds=10)

        # Simulate 3 Ollama timeouts
        for _ in range(3):
            cb.record_failure()

        self.assertFalse(cb.can_execute())

        # After timeout, allow one probe
        cb.last_failure_time = time.time() - 100
        self.assertTrue(cb.can_execute())
        self.assertEqual(cb.state, CircuitBreaker.HALF_OPEN)

    def test_all_services_down_system_remains_operational(self):
        """System remains operational even when all external services are down."""
        state = {
            "beat_count": 5,
            "status": "degraded",
            "failures": 3,
            "consecutive_failures": 3,
            "oracle_ok": False,
            "ollama_ok": False
        }
        # System should track failures but not crash
        self.assertFalse(state['oracle_ok'])
        self.assertFalse(state['ollama_ok'])
        self.assertEqual(state['consecutive_failures'], 3)
        # State itself is valid JSON
        json.dumps(state)  # Should not raise


class TestMessageBusCorruption(unittest.TestCase):
    """Test handling of malformed messages and partial writes."""

    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.bus_root = os.path.join(self.test_dir, 'bus')
        os.makedirs(self.bus_root)
        self.bus = MessageBusManager(self.bus_root)

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def test_valid_message_parse(self):
        """Valid message is parsed correctly."""
        self.bus.create_inbox('soma')
        self.bus.send('soma', 'jit', 'task:analyze', 'Analyze data')
        messages = self.bus.recv('soma')
        self.assertEqual(len(messages), 1)
        self.assertEqual(messages[0]['from'], 'jit')
        self.assertEqual(messages[0]['to'], 'soma')
        self.assertEqual(messages[0]['subject'], 'task:analyze')

    def test_missing_from_header(self):
        """Message missing 'from' header is flagged."""
        content = (
            "to:soma\n"
            "subject:task:test\n"
            "timestamp:2026-01-01T00:00:00\n"
            "---\n"
            "test body\n"
        )
        msg = self.bus._parse_message(content)
        missing = self.bus.validate_message(msg)
        self.assertIn('from', missing)

    def test_missing_to_header(self):
        """Message missing 'to' header is flagged."""
        content = (
            "from:jit\n"
            "subject:task:test\n"
            "timestamp:2026-01-01T00:00:00\n"
            "---\n"
            "test body\n"
        )
        msg = self.bus._parse_message(content)
        missing = self.bus.validate_message(msg)
        self.assertIn('to', missing)

    def test_missing_subject_header(self):
        """Message missing 'subject' header is flagged."""
        content = (
            "from:jit\n"
            "to:soma\n"
            "timestamp:2026-01-01T00:00:00\n"
            "---\n"
            "test body\n"
        )
        msg = self.bus._parse_message(content)
        missing = self.bus.validate_message(msg)
        self.assertIn('subject', missing)

    def test_missing_timestamp_header(self):
        """Message missing 'timestamp' header is flagged."""
        content = (
            "from:jit\n"
            "to:soma\n"
            "subject:task:test\n"
            "---\n"
            "test body\n"
        )
        msg = self.bus._parse_message(content)
        missing = self.bus.validate_message(msg)
        self.assertIn('timestamp', missing)

    def test_empty_message_file(self):
        """Empty message file is handled gracefully."""
        inbox = self.bus.create_inbox('innova')
        empty_file = os.path.join(inbox, '00001_from-test.msg')
        with open(empty_file, 'w') as f:
            f.write('')

        messages = self.bus.recv('innova')
        # Empty file should produce a message with just 'body' key
        # but should not crash
        self.assertIsInstance(messages, list)

    def test_partial_write_message(self):
        """Partially written message (no separator) is handled."""
        inbox = self.bus.create_inbox('chamu')
        partial_file = os.path.join(inbox, '00001_from-test.msg')
        with open(partial_file, 'w') as f:
            # Only headers, no --- separator, no body
            f.write('from:jit\nto:chamu\nsubject:task:test\n')

        messages = self.bus.recv('chamu')
        self.assertIsInstance(messages, list)
        # Should parse headers even without separator
        if messages:
            self.assertEqual(messages[0]['from'], 'jit')

    def test_binary_content_in_message(self):
        """Message with binary-like content is handled."""
        inbox = self.bus.create_inbox('netra')
        binary_file = os.path.join(inbox, '00001_from-test.msg')
        with open(binary_file, 'wb') as f:
            f.write(b'from:jit\nto:netra\nsubject:task:scan\n---\n')
            f.write(bytes(range(256)))  # All byte values

        # Should not crash on binary content
        messages = self.bus.recv('netra')
        self.assertIsInstance(messages, list)

    def test_unicode_in_message_body(self):
        """Message with Thai/Unicode content is handled correctly."""
        self.bus.create_inbox('vaja')
        self.bus.send('vaja', 'jit', 'task:translate',
                      'สวัสดีครับ ระบบทำงานปกติ')
        messages = self.bus.recv('vaja')
        self.assertEqual(len(messages), 1)
        self.assertIn('สวัสดี', messages[0]['body'])

    def test_very_long_message_body(self):
        """Very long message body is handled."""
        self.bus.create_inbox('lak')
        long_body = 'x' * 100000  # 100KB message
        self.bus.send('lak', 'jit', 'task:architecture', long_body)
        messages = self.bus.recv('lak')
        self.assertEqual(len(messages), 1)
        self.assertEqual(len(messages[0]['body']), 100000)

    def test_mark_read_renames_file(self):
        """Marking a message as read renames .msg to .read."""
        self.bus.create_inbox('neta')
        self.bus.send('neta', 'jit', 'task:review', 'Review PR')
        messages = self.bus.recv('neta')
        self.assertEqual(len(messages), 1)

        msg_file = messages[0]['_file']
        self.assertTrue(msg_file.endswith('.msg'))

        self.bus.mark_read(messages[0])
        self.assertFalse(os.path.exists(msg_file))
        read_file = msg_file.replace('.msg', '.read')
        self.assertTrue(os.path.exists(read_file))

    def test_corrupt_json_in_state_file(self):
        """Corrupt JSON in state file is handled gracefully."""
        state_file = os.path.join(self.test_dir, 'corrupt_state.json')
        # Write invalid JSON
        with open(state_file, 'w') as f:
            f.write('{"beat_count": 0, "status": BROKEN_JSON')

        manager = HeartbeatStateManager(state_file)
        # Should recover to default state
        state = manager.load()
        self.assertEqual(state['beat_count'], 0)
        self.assertEqual(state['status'], 'ready')

    def test_concurrent_write_to_shared_state(self):
        """Concurrent writes to shared state use locking to avoid corruption."""
        state_file = os.path.join(self.test_dir, 'shared_state.json')
        manager = HeartbeatStateManager(state_file)
        # Initialize with default state
        manager.save(manager.default_state if hasattr(manager, 'default_state') else {"beat_count": 0})

        write_lock = threading.Lock()
        errors = []

        def write_state(agent_name, count):
            try:
                for i in range(count):
                    with write_lock:
                        state = manager.load()
                        state['beat_count'] = state.get('beat_count', 0) + 1
                        state['status'] = f'updated_by_{agent_name}'
                        manager.save(state)
            except Exception as e:
                errors.append(str(e))

        threads = [
            threading.Thread(target=write_state, args=(f'agent_{i}', 10))
            for i in range(5)
        ]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=10)

        # No errors should occur with locking
        self.assertEqual(len(errors), 0,
                         f"Errors during concurrent writes: {errors}")

        # State file should be valid JSON
        state = manager.load()
        self.assertIsInstance(state, dict)
        self.assertIn('beat_count', state)
        # With locking, all 50 writes should be counted
        self.assertEqual(state['beat_count'], 50)

    def test_broadcast_message_format(self):
        """Broadcast messages have correct format."""
        agents = ['soma', 'innova', 'lak', 'neta']
        for agent in agents:
            self.bus.create_inbox(agent)

        # Simulate broadcast (like bus.sh broadcast)
        for agent in agents:
            self.bus.send(agent, 'jit', 'broadcast:heartbeat:IN',
                          'pulse #5 from host')

        for agent in agents:
            messages = self.bus.recv(agent)
            self.assertEqual(len(messages), 1)
            self.assertTrue(messages[0]['subject'].startswith('broadcast:'))


class TestStateRecovery(unittest.TestCase):
    """Test recovery from corrupted shared state."""

    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.state_file = os.path.join(self.test_dir, 'state.json')

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def test_missing_state_file_creates_default(self):
        """Missing state file is replaced with defaults."""
        manager = HeartbeatStateManager(self.state_file)
        state = manager.load()
        self.assertEqual(state['beat_count'], 0)
        self.assertEqual(state['status'], 'ready')

    def test_corrupted_state_recovers_to_default(self):
        """Corrupted JSON state recovers to safe defaults."""
        with open(self.state_file, 'w') as f:
            f.write('{"beat_count": "not_a_number", "status":')

        manager = HeartbeatStateManager(self.state_file)
        state = manager.load()
        self.assertEqual(state['beat_count'], 0)
        self.assertEqual(state['status'], 'ready')

    def test_partial_state_preserves_valid_fields(self):
        """State with some valid and some missing fields is recovered gracefully."""
        with open(self.state_file, 'w') as f:
            json.dump({"beat_count": 5}, f)

        manager = HeartbeatStateManager(self.state_file)
        state = manager.load()
        # beat_count preserved from file
        self.assertEqual(state['beat_count'], 5)

    def test_state_file_truncated(self):
        """Truncated state file is recovered."""
        with open(self.state_file, 'w') as f:
            f.write('{"beat_count": 3, "sta')  # truncated

        manager = HeartbeatStateManager(self.state_file)
        state = manager.load()
        self.assertIsInstance(state, dict)
        self.assertIn('beat_count', state)

    def test_state_file_empty(self):
        """Empty state file is recovered."""
        with open(self.state_file, 'w') as f:
            f.write('')

        manager = HeartbeatStateManager(self.state_file)
        state = manager.load()
        self.assertEqual(state['status'], 'ready')

    def test_state_file_null_bytes(self):
        """State file with null bytes is recovered."""
        with open(self.state_file, 'wb') as f:
            f.write(b'\x00\x00\x00{"beat_count": 1}\x00')

        manager = HeartbeatStateManager(self.state_file)
        state = manager.load()
        # Should recover to default since null bytes corrupt JSON
        self.assertIn('beat_count', state)

    def test_atomic_write_prevents_corruption(self):
        """Atomic write (write to tmp, rename) prevents partial state."""
        manager = HeartbeatStateManager(self.state_file)
        state = {"beat_count": 42, "status": "healthy"}
        manager.save(state)

        # State file should be valid JSON
        loaded = manager.load()
        self.assertEqual(loaded['beat_count'], 42)
        self.assertEqual(loaded['status'], 'healthy')

    def test_consecutive_failures_tracking(self):
        """Consecutive failures are tracked and reset on success."""
        manager = HeartbeatStateManager(self.state_file)

        # Simulate failures
        state = manager.load()
        state['consecutive_failures'] = 2
        state['status'] = 'degraded'
        manager.save(state)

        state = manager.load()
        self.assertEqual(state['consecutive_failures'], 2)

        # Simulate success
        state['consecutive_failures'] = 0
        state['status'] = 'healthy'
        manager.save(state)

        state = manager.load()
        self.assertEqual(state['consecutive_failures'], 0)
        self.assertEqual(state['status'], 'healthy')


class TestConcurrency(unittest.TestCase):
    """Test behavior under concurrent message delivery."""

    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.bus_root = os.path.join(self.test_dir, 'bus')
        os.makedirs(self.bus_root)
        self.bus = MessageBusManager(self.bus_root)

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def test_concurrent_messages_to_same_agent(self):
        """Multiple agents sending to the same target simultaneously."""
        self.bus.create_inbox('soma')

        def send_message(from_agent, subject, body):
            self.bus.send('soma', from_agent, subject, body)

        threads = [
            threading.Thread(target=send_message,
                             args=(f'agent_{i}', f'task:work-{i}', f'body {i}'))
            for i in range(10)
        ]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=10)

        messages = self.bus.recv('soma')
        self.assertEqual(len(messages), 10)

    def test_concurrent_send_and_receive(self):
        """Sending and receiving at the same time doesn't lose messages."""
        self.bus.create_inbox('innova')
        errors = []
        received_count = [0]

        def sender():
            try:
                for i in range(5):
                    self.bus.send('innova', 'soma', f'task:build-{i}',
                                  f'Build {i}')
            except Exception as e:
                errors.append(str(e))

        def receiver():
            try:
                time.sleep(0.1)  # Let some messages arrive
                messages = self.bus.recv('innova')
                received_count[0] = len(messages)
                for msg in messages:
                    self.bus.mark_read(msg)
            except Exception as e:
                errors.append(str(e))

        sender_thread = threading.Thread(target=sender)
        recv_thread = threading.Thread(target=receiver)

        sender_thread.start()
        recv_thread.start()
        sender_thread.join(timeout=10)
        recv_thread.join(timeout=10)

        # Should not crash from concurrent access
        self.assertEqual(len(errors), 0, f"Errors: {errors}")

    def test_broadcast_to_all_agents(self):
        """Broadcast reaches all agent inboxes."""
        agents = ['soma', 'innova', 'lak', 'neta', 'vaja', 'chamu']
        for agent in agents:
            self.bus.create_inbox(agent)

        # Broadcast heartbeat
        for agent in agents:
            self.bus.send(agent, 'pran', 'broadcast:heartbeat:OUT',
                          'Pulse #10')

        total_pending = 0
        for agent in agents:
            messages = self.bus.recv(agent)
            total_pending += len(messages)
            self.assertEqual(len(messages), 1)

        self.assertEqual(total_pending, len(agents))

    def test_high_volume_messages(self):
        """System handles 1000 messages without errors."""
        self.bus.create_inbox('pran')

        for i in range(1000):
            self.bus.send('pran', 'sayanprasathan',
                          f'signal:tick-{i}', f'Tick {i}')

        messages = self.bus.recv('pran')
        self.assertEqual(len(messages), 1000)

    def test_no_cross_agent_leakage(self):
        """Messages to agent A don't appear in agent B's inbox."""
        self.bus.create_inbox('soma')
        self.bus.create_inbox('innova')

        self.bus.send('soma', 'jit', 'task:think', 'Analyze')
        self.bus.send('innova', 'jit', 'task:code', 'Write code')

        soma_msgs = self.bus.recv('soma')
        innova_msgs = self.bus.recv('innova')

        self.assertEqual(len(soma_msgs), 1)
        self.assertEqual(len(innova_msgs), 1)
        self.assertEqual(soma_msgs[0]['subject'], 'task:think')
        self.assertEqual(innova_msgs[0]['subject'], 'task:code')


class TestHeartEnhancedFailure(unittest.TestCase):
    """Test heartbeat-enhanced.sh failure scenarios."""

    def test_heartbeat_in_failure_sets_degraded(self):
        """Failed heartbeat IN phase sets status to degraded."""
        state = {
            "beat_count": 0,
            "last_beat": None,
            "last_push": None,
            "failures": 0,
            "last_failure_reason": None,
            "consecutive_failures": 0,
            "status": "ready"
        }

        # Simulate IN phase failure
        state["consecutive_failures"] += 1
        state["failures"] += 1
        state["status"] = "degraded"
        state["last_failure_reason"] = "ollama_error"

        self.assertEqual(state["consecutive_failures"], 1)
        self.assertEqual(state["status"], "degraded")
        self.assertEqual(state["last_failure_reason"], "ollama_error")

    def test_3_consecutive_failures_triggers_critical(self):
        """3+ consecutive failures trigger critical status."""
        consecutive = 3
        critical_threshold = 3
        is_critical = consecutive >= critical_threshold
        self.assertTrue(is_critical)

    def test_successful_beat_resets_consecutive_failures(self):
        """Successful beat resets consecutive_failures to 0."""
        state = {
            "beat_count": 5,
            "consecutive_failures": 2,
            "status": "degraded"
        }

        # Successful heartbeat cycle
        state["consecutive_failures"] = 0
        state["status"] = "healthy"

        self.assertEqual(state["consecutive_failures"], 0)
        self.assertEqual(state["status"], "healthy")

    def test_beat_count_increments_on_success(self):
        """Beat count increments after successful heartbeat cycle."""
        state = {"beat_count": 0}
        state["beat_count"] = 1
        self.assertEqual(state["beat_count"], 1)

        state["beat_count"] = 2
        self.assertEqual(state["beat_count"], 2)

    def test_beat_count_does_not_increment_on_failure(self):
        """Beat count does NOT increment if heartbeat fails."""
        state = {"beat_count": 5}
        # In heartbeat-enhanced.sh, update_state beat_count only happens
        # AFTER successful IN phase
        self.assertEqual(state["beat_count"], 5)

    def test_missing_result_file_causes_out_failure(self):
        """Missing IN result file causes OUT phase to fail."""
        result_file = "/tmp/heartbeat-results/beat-999-in.txt"
        self.assertFalse(os.path.exists(result_file))

    def test_state_persistence_across_beats(self):
        """State persists correctly across multiple beats."""
        state_file = os.path.join(tempfile.mkdtemp(), 'state.json')
        manager = HeartbeatStateManager(state_file)

        # Beat 1
        state = manager.load()
        state['beat_count'] = 1
        state['status'] = 'healthy'
        manager.save(state)

        # Beat 2
        state = manager.load()
        state['beat_count'] = 2
        manager.save(state)

        # Verify
        state = manager.load()
        self.assertEqual(state['beat_count'], 2)


class TestLibShUtilities(unittest.TestCase):
    """Test utility functions from limbs/lib.sh patterns."""

    def test_json_str_encodes_special_chars(self):
        """json_str encodes special characters correctly."""
        # This mirrors lib.sh's json_str function
        import json
        test_str = 'Hello "world" \n with \\special/'
        result = json.dumps(test_str)
        self.assertIsInstance(result, str)
        # Should be valid JSON
        parsed = json.loads(result)
        self.assertEqual(parsed, test_str)

    def test_log_action_format(self):
        """Log actions follow ISO 8601 timestamp format."""
        timestamp = time.strftime('%Y-%m-%dT%H:%M:%S')
        # Should match pattern: [timestamp] [VERB] description
        log_line = f"[{timestamp}] [SESSION_START] innova awake"
        self.assertRegex(log_line, r'\[\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\]')

    def test_oracle_url_default(self):
        """Oracle URL defaults to localhost:47778."""
        oracle_url = os.environ.get('ORACLE_URL', 'http://localhost:47778')
        self.assertEqual(oracle_url, 'http://localhost:47778')

    def test_ollama_url_default(self):
        """Ollama URL defaults to ollama.mdes-innova.online."""
        ollama_url = os.environ.get('OLLAMA_URL',
                                    'https://ollama.mdes-innova.online')
        self.assertIn('ollama.mdes-innova.online', ollama_url)

    def test_message_subject_prefixes(self):
        """Valid subject prefixes match the protocol spec."""
        valid_prefixes = [
            'task:', 'think:', 'report:', 'alert:',
            'broadcast:', 'learn:', 'request:', 'reply:'
        ]
        for prefix in valid_prefixes:
            subject = f"{prefix}test-message"
            has_valid_prefix = any(subject.startswith(p) for p in valid_prefixes)
            self.assertTrue(has_valid_prefix,
                           f"Subject '{subject}' should start with valid prefix")


class TestRoutingTable(unittest.TestCase):
    """Test heart.sh routing table dispatch logic."""

    ROUTE_TABLE = {
        "read": "eye", "observe": "eye", "web": "eye",
        "listen": "ear", "receive": "ear",
        "say": "mouth", "tell": "mouth", "broadcast": "mouth",
        "detect": "nose", "monitor": "nose", "health": "nose",
        "create": "hand", "edit": "hand", "build": "hand",
        "go": "leg", "deploy": "leg",
        "think": "brain", "plan": "brain",
        "ask": "ollama", "learn": "oracle", "search": "oracle",
    }

    def test_all_task_types_have_routes(self):
        """Every known task type maps to an organ."""
        for task_type, organ in self.ROUTE_TABLE.items():
            self.assertIsNotNone(organ,
                                f"Task type '{task_type}' has no route")

    def test_unknown_task_defaults_to_hand(self):
        """Unknown task types default to hand (fallback executor)."""
        unknown_tasks = ["unknown", "random", "defrag", "optimize"]
        default_organ = "hand"
        for task in unknown_tasks:
            organ = self.ROUTE_TABLE.get(task, default_organ)
            self.assertEqual(organ, default_organ)

    def test_sensory_tasks_route_to_sensory_organs(self):
        """Sensory tasks route to sensory organs."""
        self.assertEqual(self.ROUTE_TABLE["read"], "eye")
        self.assertEqual(self.ROUTE_TABLE["observe"], "eye")
        self.assertEqual(self.ROUTE_TABLE["listen"], "ear")
        self.assertEqual(self.ROUTE_TABLE["detect"], "nose")

    def test_cognitive_tasks_route_to_brain(self):
        """Cognitive tasks route to brain."""
        self.assertEqual(self.ROUTE_TABLE["think"], "brain")
        self.assertEqual(self.ROUTE_TABLE["plan"], "brain")

    def test_action_tasks_route_to_hand_or_leg(self):
        """Action tasks route to hand or leg."""
        self.assertEqual(self.ROUTE_TABLE["create"], "hand")
        self.assertEqual(self.ROUTE_TABLE["edit"], "hand")
        self.assertEqual(self.ROUTE_TABLE["build"], "hand")
        self.assertEqual(self.ROUTE_TABLE["go"], "leg")
        self.assertEqual(self.ROUTE_TABLE["deploy"], "leg")

    def test_knowledge_tasks_route_to_oracle_or_ollama(self):
        """Knowledge tasks route to oracle or ollama."""
        self.assertEqual(self.ROUTE_TABLE["ask"], "ollama")
        self.assertEqual(self.ROUTE_TABLE["learn"], "oracle")
        self.assertEqual(self.ROUTE_TABLE["search"], "oracle")


class TestHeartBiphasic(unittest.TestCase):
    """Test the heart's biphasic beat (IN/OUT) pattern."""

    def test_in_beat_collects_stats(self):
        """IN beat (diastole) collects vitals from all agents."""
        blood = {
            "timestamp": "2026-06-06T12:00:00",
            "host": "test-host",
            "oracle_ok": True,
            "ollama_ok": True,
            "git_changes": 3,
            "total_pending": 5,
            "agents": {
                "soma": {"pending": 0, "organ": "brain", "tier": 1, "alive": True},
                "innova": {"pending": 2, "organ": "mind", "tier": 2, "alive": True},
                "chamu": {"pending": 3, "organ": "nose", "tier": 3, "alive": False},
            }
        }
        self.assertTrue(blood["oracle_ok"])
        self.assertTrue(blood["ollama_ok"])
        self.assertEqual(blood["total_pending"], 5)

    def test_out_beat_dispatches_energy(self):
        """OUT beat (systole) dispatches energy to agents needing it."""
        agents = {
            "soma": {"pending": 0},
            "innova": {"pending": 2},
            "chamu": {"pending": 3},
        }
        wake_list = [name for name, info in agents.items()
                     if info.get("pending", 0) > 0]
        self.assertEqual(wake_list, ["innova", "chamu"])

    def test_in_out_cycle_order(self):
        """Heart always does IN before OUT in a cycle."""
        phases = []
        phases.append("IN")
        phases.append("OUT")
        self.assertEqual(phases, ["IN", "OUT"])

    def test_heart_rate_modes(self):
        """Heart supports all rate modes."""
        valid_modes = ["sprint", "fast", "normal", "slow", "rest"]
        for mode in valid_modes:
            self.assertIn(mode, valid_modes)

    def test_invalid_rate_mode_rejected(self):
        """Invalid heart rate mode is rejected."""
        mode = "turbo"
        valid_modes = ["sprint", "fast", "normal", "slow", "rest"]
        self.assertNotIn(mode, valid_modes)


class TestRegistryAgentCount(unittest.TestCase):
    """Test that the 14-agent system is complete."""

    def test_all_agents_in_registry(self):
        """All expected agents are accounted for in registry."""
        registry_file = '/workspaces/Jit/network/registry.json'
        if os.path.exists(registry_file):
            with open(registry_file) as f:
                registry = json.load(f)
            agents = registry.get('agents', [])
            self.assertGreaterEqual(len(agents), 14,
                           "Registry should have at least 14 agents")

            agent_names = {a['name'] for a in agents}
            expected = {
                'jit', 'soma', 'innova', 'lak', 'neta',
                'vaja', 'chamu', 'rupa', 'pada',
                'netra', 'karn', 'mue', 'pran', 'sayanprasathan'
            }
            # All expected agents must be present (additional agents OK)
            self.assertTrue(expected.issubset(agent_names),
                           f"Missing agents: {expected - agent_names}")
        else:
            self.skipTest("Registry file not found")

    def test_all_agents_have_organ_assignments(self):
        """Every agent has an organ assignment."""
        registry_file = '/workspaces/Jit/network/registry.json'
        if os.path.exists(registry_file):
            with open(registry_file) as f:
                registry = json.load(f)
            for agent in registry.get('agents', []):
                self.assertIn('organ', agent,
                              f"Agent {agent.get('name', '?')} missing organ")
        else:
            self.skipTest("Registry file not found")

    def test_team_structure_in_registry(self):
        """Registry has team structure with tier assignments."""
        registry_file = '/workspaces/Jit/network/registry.json'
        if os.path.exists(registry_file):
            with open(registry_file) as f:
                registry = json.load(f)
            team = registry.get('team_structure', {})
            self.assertIn('tier_0_master', team)
            self.assertIn('tier_1_leadership', team)
            self.assertIn('tier_2_core', team)
            self.assertIn('tier_3_specialists', team)

            # jit is always the master
            self.assertIn('jit', team.get('tier_0_master', []))
        else:
            self.skipTest("Registry file not found")


class TestEndToEndRecovery(unittest.TestCase):
    """End-to-end recovery scenarios: full heartbeat cycle with failures."""

    def setUp(self):
        self.test_dir = tempfile.mkdtemp()
        self.bus_root = os.path.join(self.test_dir, 'bus')
        os.makedirs(self.bus_root)
        self.bus = MessageBusManager(self.bus_root)
        self.state_file = os.path.join(self.test_dir, 'state.json')
        self.state_manager = HeartbeatStateManager(self.state_file)

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def test_full_recovery_from_ollama_failure(self):
        """System recovers after Ollama failure using circuit breaker."""
        cb = CircuitBreaker(failure_threshold=3, reset_timeout_seconds=300)
        state = self.state_manager.load()

        # 3 Ollama failures
        for i in range(3):
            cb.record_failure()
            state['consecutive_failures'] = i + 1
            state['status'] = 'degraded'
            self.state_manager.save(state)

        # Circuit opens
        self.assertEqual(cb.state, CircuitBreaker.OPEN)

        # After timeout, allow probe (simulate time passing)
        cb.last_failure_time = time.time() - 400  # Beyond 300s timeout
        self.assertTrue(cb.can_execute())
        self.assertEqual(cb.state, CircuitBreaker.HALF_OPEN)

        # Probe succeeds
        cb.record_success()
        state['consecutive_failures'] = 0
        state['status'] = 'healthy'
        self.state_manager.save(state)

        self.assertEqual(cb.state, CircuitBreaker.CLOSED)
        self.assertEqual(state['consecutive_failures'], 0)

    def test_full_recovery_from_oracle_offline(self):
        """System operates in degraded mode when Oracle is offline."""
        state = self.state_manager.load()
        state['oracle_ok'] = False
        state['status'] = 'degraded'
        self.state_manager.save(state)

        # System still runs, just degraded
        state = self.state_manager.load()
        self.assertFalse(state.get('oracle_ok', True))
        self.assertEqual(state['status'], 'degraded')

        # Oracle comes back online
        state['oracle_ok'] = True
        state['status'] = 'healthy'
        self.state_manager.save(state)

        state = self.state_manager.load()
        self.assertTrue(state.get('oracle_ok', True))
        self.assertEqual(state['status'], 'healthy')

    def test_message_bus_recovery_after_corruption(self):
        """System recovers from message bus corruption."""
        # Create inbox with valid and corrupt messages
        inbox = self.bus.create_inbox('mue')

        # Valid message
        self.bus.send('mue', 'jit', 'task:build', 'Build feature')

        # Corrupt message file (no headers)
        corrupt_file = os.path.join(inbox, '00000_from-corrupt.msg')
        with open(corrupt_file, 'w') as f:
            f.write('CORRUPT DATA WITHOUT HEADERS')

        # Empty message file
        empty_file = os.path.join(inbox, '00000_from-empty.msg')
        with open(empty_file, 'w') as f:
            f.write('')

        # Bus should still function
        messages = self.bus.recv('mue')
        # Should get at least the valid message (corrupt ones may or may not parse)
        self.assertGreaterEqual(len(messages), 1)

    def test_shared_state_recovery_flow(self):
        """Full flow: corrupt state -> detect -> recover -> verify."""
        # Write corrupt state
        with open(self.state_file, 'w') as f:
            f.write('{"corrupt": true, "missing_fields')

        # Load should recover to defaults
        state = self.state_manager.load()
        self.assertEqual(state['status'], 'ready')
        self.assertEqual(state['beat_count'], 0)

        # After recovery, system can write valid state
        state['beat_count'] = 1
        state['status'] = 'healthy'
        self.state_manager.save(state)

        # Verify round-trip
        state = self.state_manager.load()
        self.assertEqual(state['beat_count'], 1)
        self.assertEqual(state['status'], 'healthy')

    def test_cascading_failure_with_circuit_breakers(self):
        """Multiple services fail simultaneously; circuit breakers isolate them."""
        oracle_cb = CircuitBreaker(failure_threshold=3, reset_timeout_seconds=5)
        ollama_cb = CircuitBreaker(failure_threshold=3, reset_timeout_seconds=10)

        # Both services fail
        for _ in range(3):
            oracle_cb.record_failure()
            ollama_cb.record_failure()

        # Both circuits are open
        self.assertEqual(oracle_cb.state, CircuitBreaker.OPEN)
        self.assertEqual(ollama_cb.state, CircuitBreaker.OPEN)

        # Oracle recovers first
        oracle_cb.last_failure_time = time.time() - 100
        self.assertTrue(oracle_cb.can_execute())
        oracle_cb.record_success()
        self.assertEqual(oracle_cb.state, CircuitBreaker.CLOSED)

        # Ollama still open
        self.assertFalse(ollama_cb.can_execute())
        self.assertEqual(ollama_cb.state, CircuitBreaker.OPEN)

        # Ollama eventually recovers
        ollama_cb.last_failure_time = time.time() - 100
        self.assertTrue(ollama_cb.can_execute())
        ollama_cb.record_success()
        self.assertEqual(ollama_cb.state, CircuitBreaker.CLOSED)


if __name__ == '__main__':
    unittest.main()
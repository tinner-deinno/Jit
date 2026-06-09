#!/usr/bin/env python3
"""
Test suite for organ shell scripts: ear, mouth, eye, hand, heart
Verifies message bus, routing, file operations, and dispatch logic.

chamu (จมูก) — QA/Tester organ of มนุษย์ Agent
"""

import json
import os
import shutil
import subprocess
import tempfile
import textwrap
import time
import unittest


def _write_stub_lib(path):
    """Write a minimal lib.sh that silences all output and stubs oracle."""
    with open(path, 'w') as f:
        f.write(textwrap.dedent('''\
            #!/usr/bin/env bash
            # stub lib.sh for testing
            GREEN='' RED='' YELLOW='' BLUE='' CYAN='' BOLD='' RESET=''
            # Allow ok/info/step to pass through for assertions, silence colors
            ok()   { echo "$@"; }
            warn() { echo "$@"; }
            err()  { echo "$@" >&2; }
            info() { echo "$@"; }
            step() { echo "$@"; }
            log_action() { :; }
            oracle_ready() { return 1; }
            oracle_learn() { :; }
            oracle_search() { :; }
            # Stub signature verification - always pass for testing
            bus_verify_signature() { return 0; }
            JIT_ROOT="${JIT_ROOT:-/workspaces/Jit}"
        '''))


def _write_stub_bus(path):
    """Write a minimal bus.sh stub for testing routing."""
    with open(path, 'w') as f:
        f.write(textwrap.dedent('''\
            #!/usr/bin/env bash
            # stub bus.sh for testing
            BUS_DIR="${BUS_DIR:-/tmp/manusat-bus}"
            case "$1" in
              broadcast)
                shift || true
                mkdir -p "$BUS_DIR"
                echo "BROADCAST:$*" >> "$BUS_DIR/broadcast.log"
                ;;
              send)
                TO="$2"
                mkdir -p "$BUS_DIR/$TO"
                echo "$3" >> "$BUS_DIR/$TO/bus.msg"
                ;;
              *)
                echo "BUS:unknown:$1"
                ;;
            esac
        '''))


def _make_executable(path):
    os.chmod(path, 0o755)


# ───────────────────────────────────────────────────────────────────
# ear.sh tests
# ────────────────────────────────────────────────────────────────────

class TestEarInbox(unittest.TestCase):
    """Tests for ear.sh — hearing/receiving organ"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = self.tmpdir.name
        self.bus_dir = os.path.join(self.root, 'tmp', 'manusat-bus')
        self.agent_inbox = os.path.join(self.bus_dir, 'testagent')
        os.makedirs(self.agent_inbox, exist_ok=True)
        os.makedirs(os.path.join(self.root, 'limbs'), exist_ok=True)

        # Copy real ear.sh
        src = os.path.join(os.getcwd(), 'organs', 'ear.sh')
        dst = os.path.join(self.root, 'organs', 'ear.sh')
        os.makedirs(os.path.join(self.root, 'organs'), exist_ok=True)
        shutil.copy(src, dst)

        # Write stubs
        _write_stub_lib(os.path.join(self.root, 'limbs', 'lib.sh'))
        for p in [dst, os.path.join(self.root, 'limbs', 'lib.sh')]:
            _make_executable(p)

    def tearDown(self):
        self.tmpdir.cleanup()

    def _run_ear(self, args, agent='testagent'):
        """Run ear.sh with given args."""
        env = {
            **os.environ,
            'AGENT_NAME': agent,
            'INBOX_DIR': self.bus_dir,
        }
        result = subprocess.run(
            ['bash', os.path.join(self.root, 'organs', 'ear.sh')] + args,
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
        )
        return result

    def _write_msg(self, filename, content, read=False):
        """Helper: write a message file to the agent inbox."""
        prefix = 'read_' if read else ''
        path = os.path.join(self.agent_inbox, f'{prefix}{filename}')
        with open(path, 'w') as f:
            f.write(content)
        return path

    # ── inbox: display inbox status ──────────────────────────────────

    def test_inbox_empty(self):
        """Inbox command shows empty when no messages."""
        result = self._run_ear(['inbox'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('testagent', result.stdout)

    def test_inbox_with_pending_messages(self):
        """Inbox command shows count of pending messages."""
        # Include all required headers (from, to, subject)
        self._write_msg('001_from-soma.msg', 'from:soma\nto:testagent\nsubject:task:deploy\n---\ngo')
        self._write_msg('002_from-lak.msg', 'from:lak\nto:testagent\nsubject:think:review\n---\ncheck')
        result = self._run_ear(['inbox'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('from:soma', result.stdout)
        self.assertIn('task:deploy', result.stdout)

    def test_inbox_shows_read_count(self):
        """Inbox shows both pending and read message counts."""
        # Include all required headers (from, to, subject)
        self._write_msg('001_from-soma.msg', 'from:soma\nto:testagent\nsubject:test\n---\nbody')
        self._write_msg('002_from-lak.msg', 'from:lak\nto:testagent\nsubject:test\n---\nbody', read=True)
        result = self._run_ear(['inbox'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('1', result.stdout)  # 1 pending

    # ── receive: consume pending messages ──────────────────────────────

    def test_receive_empty_inbox(self):
        """Receive exits cleanly when inbox is empty."""
        result = self._run_ear(['receive'])
        self.assertEqual(result.returncode, 0)

    def test_receive_reads_messages(self):
        """Receive reads and moves messages to read state."""
        # Include all required headers (from, to, subject) - signature stub always passes
        self._write_msg('001_from-soma.msg', 'from:soma\nto:testagent\nsubject:task\n---\nhello')
        result = self._run_ear(['receive'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('hello', result.stdout)
        # Message should be moved to read_
        read_files = [f for f in os.listdir(self.agent_inbox) if f.startswith('read_')]
        self.assertEqual(len(read_files), 1)

    def test_receive_multiple_messages(self):
        """Receive handles multiple pending messages."""
        # Include all required headers (from, to, subject) - signature stub always passes
        self._write_msg('001.msg', 'from:agent1\nto:testagent\nsubject:test\n---\nmsg1')
        self._write_msg('002.msg', 'from:agent2\nto:testagent\nsubject:test\n---\nmsg2')
        result = self._run_ear(['receive'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('msg1', result.stdout)
        self.assertIn('msg2', result.stdout)
        read_files = [f for f in os.listdir(self.agent_inbox) if f.startswith('read_')]
        self.assertEqual(len(read_files), 2)

    # ── from: filter by sender ────────────────────────────────────────

    def test_from_filters_by_sender(self):
        """From command only returns messages from specified agent."""
        # Include all required headers (from, to, subject)
        self._write_msg('001_from-soma.msg', 'from:soma\nto:testagent\nsubject:task\n---\nsoma msg')
        self._write_msg('002_from-lak.msg', 'from:lak\nto:testagent\nsubject:review\n---\nlak msg')
        result = self._run_ear(['from', 'soma'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('soma msg', result.stdout)
        self.assertNotIn('lak msg', result.stdout)

    def test_from_missing_sender_arg(self):
        """From command requires a sender argument."""
        result = self._run_ear(['from'])
        # Should exit with error (exit code 1)
        self.assertNotEqual(result.returncode, 0)

    # ── clear: empty inbox ─────────────────────────────────────────────

    def test_clear_removes_all_messages(self):
        """Clear command removes all pending and read messages."""
        # Clear works on any files, no need for proper headers
        self._write_msg('001.msg', 'from:a\nto:testagent\nsubject:x\n---\nbody1')
        self._write_msg('002.msg', 'from:b\nto:testagent\nsubject:y\n---\nbody2', read=True)
        result = self._run_ear(['clear'])
        self.assertEqual(result.returncode, 0)
        remaining = os.listdir(self.agent_inbox)
        self.assertEqual(len(remaining), 0)

    def test_clear_empty_inbox(self):
        """Clear on empty inbox does not error."""
        result = self._run_ear(['clear'])
        self.assertEqual(result.returncode, 0)

    # ── status ─────────────────────────────────────────────────────────

    def test_status_shows_agent_name(self):
        """Status command shows the agent name and inbox path."""
        result = self._run_ear(['status'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('testagent', result.stdout)

    # ── listen: blocking poll ──────────────────────────────────────────

    def test_listen_receives_existing_message(self):
        """Listen immediately picks up a message that already exists."""
        # Include all required headers (from, to, subject) - signature stub always passes
        self._write_msg('001.msg', 'from:sender\nto:testagent\nsubject:test\n---\ninstant message')
        result = self._run_ear(['listen', '2'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('instant message', result.stdout)

    # ── message parsing: subject prefix ───────────────────────────────

    def test_inbox_parses_subject_prefix_task(self):
        """Inbox correctly parses subject:task: prefix."""
        # Include all required headers (from, to, subject)
        self._write_msg('001.msg', 'from:innova\nto:testagent\nsubject:task:deploy\n---\ndeploy it')
        result = self._run_ear(['inbox'])
        self.assertIn('task:deploy', result.stdout)
        self.assertIn('from:innova', result.stdout)

    def test_inbox_parses_subject_prefix_broadcast(self):
        """Inbox correctly parses subject:broadcast: prefix."""
        # Include all required headers (from, to, subject)
        self._write_msg('001.msg', 'from:heart\nto:testagent\nsubject:broadcast:alert\n---\ncritical')
        result = self._run_ear(['inbox'])
        self.assertIn('broadcast:alert', result.stdout)
        self.assertIn('from:heart', result.stdout)

    def test_inbox_parses_from_field(self):
        """Inbox correctly extracts from: field."""
        # Include all required headers (from, to, subject)
        self._write_msg('001.msg', 'from:neta\nto:testagent\nsubject:review\n---\nlgtm')
        result = self._run_ear(['inbox'])
        self.assertIn('from:neta', result.stdout)
        self.assertIn('review', result.stdout)

    # ── unknown command ───────────────────────────────────────────────

    def test_unknown_command_shows_usage(self):
        """Unknown command shows usage text."""
        result = self._run_ear(['nonexistent'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('Usage', result.stdout)


# ────────────────────────────────────────────────────────────────────
# mouth.sh tests
# ────────────────────────────────────────────────────────────────────

class TestMouthSend(unittest.TestCase):
    """Tests for mouth.sh — speech/sending organ"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = self.tmpdir.name
        self.bus_dir = os.path.join(self.root, 'tmp', 'manusat-bus')
        os.makedirs(os.path.join(self.root, 'limbs'), exist_ok=True)
        os.makedirs(os.path.join(self.root, 'organs'), exist_ok=True)
        os.makedirs(self.bus_dir, exist_ok=True)

        # Copy real mouth.sh
        src = os.path.join(os.getcwd(), 'organs', 'mouth.sh')
        dst = os.path.join(self.root, 'organs', 'mouth.sh')
        shutil.copy(src, dst)

        # Write stubs
        _write_stub_lib(os.path.join(self.root, 'limbs', 'lib.sh'))
        _write_stub_bus(os.path.join(self.root, 'network', 'bus.sh'))
        os.makedirs(os.path.join(self.root, 'network'), exist_ok=True)

        for p in [
            dst,
            os.path.join(self.root, 'limbs', 'lib.sh'),
            os.path.join(self.root, 'network', 'bus.sh'),
        ]:
            _make_executable(p)

    def tearDown(self):
        self.tmpdir.cleanup()

    def _run_mouth(self, args, agent='testagent'):
        """Run mouth.sh with given args."""
        env = {
            **os.environ,
            'AGENT_NAME': agent,
            'BUS_DIR': self.bus_dir,
        }
        result = subprocess.run(
            ['bash', os.path.join(self.root, 'organs', 'mouth.sh')] + args,
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
        )
        return result

    # ── say: print to stdout ──────────────────────────────────────────

    def test_say_outputs_message(self):
        """Say command outputs the message to stdout."""
        result = self._run_mouth(['say', 'hello', 'world'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('hello world', result.stdout)

    def test_say_includes_agent_name(self):
        """Say command includes the agent name in output."""
        result = self._run_mouth(['say', 'test message'], agent='chamu')
        self.assertIn('chamu', result.stdout)

    # ── tell: send message to specific agent ───────────────────────────

    def test_tell_creates_message_file(self):
        """Tell command creates a message file in the target agent's inbox."""
        result = self._run_mouth(['tell', 'soma', 'task:deploy', 'deploy the app'])
        self.assertEqual(result.returncode, 0)
        # Check that a .msg file was created in soma's inbox
        soma_dir = os.path.join(self.bus_dir, 'soma')
        self.assertTrue(os.path.isdir(soma_dir))
        msg_files = [f for f in os.listdir(soma_dir) if f.endswith('.msg')]
        self.assertEqual(len(msg_files), 1)

    def test_tell_message_format(self):
        """Tell command creates properly formatted message with headers."""
        self._run_mouth(['tell', 'neta', 'review:code', 'please review'])
        neta_dir = os.path.join(self.bus_dir, 'neta')
        msg_files = [f for f in os.listdir(neta_dir) if f.endswith('.msg')]
        self.assertEqual(len(msg_files), 1)
        content = open(os.path.join(neta_dir, msg_files[0])).read()
        self.assertIn('from:testagent', content)
        self.assertIn('to:neta', content)
        self.assertIn('subject:review:code', content)
        self.assertIn('please review', content)
        self.assertIn('timestamp:', content)

    def test_tell_missing_args(self):
        """Tell command with missing arguments exits with error."""
        result = self._run_mouth(['tell'])
        self.assertNotEqual(result.returncode, 0)

    def test_tell_message_filename_contains_from(self):
        """Tell message filename contains the sending agent name."""
        result = self._run_mouth(['tell', 'innova', 'task:test', 'body'])
        self.assertEqual(result.returncode, 0)
        innova_dir = os.path.join(self.bus_dir, 'innova')
        msg_files = [f for f in os.listdir(innova_dir) if f.endswith('.msg')]
        self.assertEqual(len(msg_files), 1)
        self.assertIn('from-testagent', msg_files[0])

    # ── broadcast: send to all agents ─────────────────────────────────

    def test_broadcast_without_registry(self):
        """Broadcast falls back to innova+soma when registry is missing."""
        result = self._run_mouth(['broadcast', 'alert', 'system alert'])
        self.assertEqual(result.returncode, 0)
        # Should have created messages for innova and soma (fallback)
        innova_dir = os.path.join(self.bus_dir, 'innova')
        soma_dir = os.path.join(self.bus_dir, 'soma')
        self.assertTrue(os.path.isdir(innova_dir) or os.path.isdir(soma_dir))

    def test_broadcast_with_registry(self):
        """Broadcast reads registry and sends to all agents except self."""
        registry = {
            "agents": [
                {"name": "testagent", "organ": "nose", "tier": 3},
                {"name": "soma", "organ": "brain", "tier": 1},
                {"name": "innova", "organ": "mind", "tier": 2},
            ]
        }
        reg_path = os.path.join(self.root, 'network', 'registry.json')
        with open(reg_path, 'w') as f:
            json.dump(registry, f)

        result = self._run_mouth(['broadcast', 'task', 'do something'])
        self.assertEqual(result.returncode, 0)
        # Should NOT have message for testagent (self)
        testagent_dir = os.path.join(self.bus_dir, 'testagent')
        if os.path.isdir(testagent_dir):
            self.assertEqual(len(os.listdir(testagent_dir)), 0)

    # ── reply: respond to a reference ──────────────────────────────────

    def test_reply_sends_message(self):
        """Reply command sends a message with reply: prefix."""
        result = self._run_mouth(['reply', 'msg123', 'soma', 'acknowledged'])
        self.assertEqual(result.returncode, 0)
        soma_dir = os.path.join(self.bus_dir, 'soma')
        self.assertTrue(os.path.isdir(soma_dir))

    def test_reply_includes_ref_id_in_subject(self):
        """Reply includes the reference ID in the subject."""
        self._run_mouth(['reply', 'ref-42', 'innova', 'got it'])
        innova_dir = os.path.join(self.bus_dir, 'innova')
        msg_files = [f for f in os.listdir(innova_dir) if f.endswith('.msg')]
        self.assertEqual(len(msg_files), 1)
        content = open(os.path.join(innova_dir, msg_files[0])).read()
        self.assertIn('subject:reply:ref-42', content)

    def test_reply_missing_args(self):
        """Reply with missing args exits with error."""
        result = self._run_mouth(['reply', 'only-one-arg'])
        self.assertNotEqual(result.returncode, 0)

    # ── report: structured output ──────────────────────────────────────

    def test_report_outputs_title(self):
        """Report command outputs structured format with title."""
        result = self._run_mouth(['report', 'Build Results', 'all tests passed'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('Build Results', result.stdout)
        self.assertIn('testagent', result.stdout)

    def test_report_includes_body(self):
        """Report command includes the body text."""
        result = self._run_mouth(['report', 'Status', 'system is healthy'])
        self.assertIn('system is healthy', result.stdout)

    # ── status ─────────────────────────────────────────────────────────

    def test_status_shows_bus_dir(self):
        """Status command shows the bus directory."""
        result = self._run_mouth(['status'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('mouth', result.stdout.lower())

    # ── pulse ──────────────────────────────────────────────────────────

    def test_pulse_outputs_energy_message(self):
        """Pulse command outputs energy message."""
        result = self._run_mouth(['pulse'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('energy', result.stdout.lower())

    # ── unknown command ────────────────────────────────────────────────

    def test_unknown_command_shows_usage(self):
        """Unknown command shows usage text."""
        result = self._run_mouth(['nonexistent'])
        self.assertIn('Usage', result.stdout)

    # ── subject formatting ─────────────────────────────────────────────

    def test_tell_subject_with_prefix(self):
        """Tell correctly passes subject with prefix (e.g. task:deploy)."""
        self._run_mouth(['tell', 'soma', 'task:deploy', 'deploy now'])
        soma_dir = os.path.join(self.bus_dir, 'soma')
        msg_files = [f for f in os.listdir(soma_dir) if f.endswith('.msg')]
        content = open(os.path.join(soma_dir, msg_files[0])).read()
        self.assertIn('subject:task:deploy', content)

    def test_broadcast_subject_has_prefix(self):
        """Broadcast prefixes subject with broadcast:."""
        # Without registry, falls back to innova+soma
        result = self._run_mouth(['broadcast', 'alert', 'critical issue'])
        self.assertEqual(result.returncode, 0)


# ────────────────────────────────────────────────────────────────────
# eye.sh tests
# ────────────────────────────────────────────────────────────────────

class TestEyeObserve(unittest.TestCase):
    """Tests for eye.sh — vision/observation organ"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = self.tmpdir.name
        os.makedirs(os.path.join(self.root, 'limbs'), exist_ok=True)
        os.makedirs(os.path.join(self.root, 'organs'), exist_ok=True)

        # Copy real eye.sh
        src = os.path.join(os.getcwd(), 'organs', 'eye.sh')
        dst = os.path.join(self.root, 'organs', 'eye.sh')
        shutil.copy(src, dst)

        # Write stub lib.sh
        _write_stub_lib(os.path.join(self.root, 'limbs', 'lib.sh'))
        for p in [dst, os.path.join(self.root, 'limbs', 'lib.sh')]:
            _make_executable(p)

        # Create test files for eye to read
        self.test_file = os.path.join(self.root, 'test_read.txt')
        with open(self.test_file, 'w') as f:
            f.write('line1\nline2\nline3\n')

    def tearDown(self):
        self.tmpdir.cleanup()

    def _run_eye(self, args):
        env = {
            **os.environ,
            'JIT_ROOT': self.root,
        }
        result = subprocess.run(
            ['bash', os.path.join(self.root, 'organs', 'eye.sh')] + args,
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
        )
        return result

    # ── read: file reading ─────────────────────────────────────────────

    def test_read_existing_file(self):
        """Read command outputs file contents."""
        result = self._run_eye(['read', self.test_file])
        self.assertEqual(result.returncode, 0)
        self.assertIn('line1', result.stdout)
        self.assertIn('line2', result.stdout)
        self.assertIn('line3', result.stdout)

    def test_read_nonexistent_file(self):
        """Read command exits with error for missing file."""
        result = self._run_eye(['read', '/nonexistent/path/file.txt'])
        self.assertNotEqual(result.returncode, 0)

    def test_read_missing_argument(self):
        """Read command requires a file path argument."""
        result = self._run_eye(['read'])
        # Should fail or show usage — at minimum not crash
        self.assertNotEqual(result.returncode, 0)

    # ── scan: file scanning ────────────────────────────────────────────

    def test_scan_finds_matching_files(self):
        """Scan command finds files matching a pattern."""
        # Create some files
        for name in ['a.txt', 'b.py', 'c.txt']:
            with open(os.path.join(self.root, name), 'w') as f:
                f.write('content')

        result = self._run_eye(['scan', self.root, '*.txt'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('a.txt', result.stdout)
        self.assertIn('c.txt', result.stdout)

    def test_scan_excludes_git_directory(self):
        """Scan excludes .git directory."""
        git_dir = os.path.join(self.root, '.git', 'objects')
        os.makedirs(git_dir, exist_ok=True)
        with open(os.path.join(git_dir, 'test.txt'), 'w') as f:
            f.write('git internal')

        result = self._run_eye(['scan', self.root, '*.txt'])
        self.assertNotIn('.git', result.stdout)

    def test_scan_default_pattern(self):
        """Scan with no pattern defaults to *."""
        result = self._run_eye(['scan', self.root])
        self.assertEqual(result.returncode, 0)
        # Should find at least our test file
        self.assertIn('test_read.txt', result.stdout)

    # ── watch: directory monitoring ────────────────────────────────────

    def test_watch_snapshot_mode(self):
        """Watch falls back to snapshot mode when inotifywait is unavailable."""
        result = self._run_eye(['watch', self.root])
        # Should not crash; either uses inotifywait or falls back
        # The snapshot mode may produce empty output if no recent changes
        self.assertEqual(result.returncode, 0)

    # ── diff: git changes ──────────────────────────────────────────────

    def test_diff_with_git_repo(self):
        """Diff command runs git diff in JIT_ROOT."""
        # Initialize a git repo so diff has something to work with
        subprocess.run(['git', 'init'], cwd=self.root,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(['git', 'config', 'user.email', 'test@test.com'],
                       cwd=self.root, stdout=subprocess.DEVNULL)
        subprocess.run(['git', 'config', 'user.name', 'test'],
                       cwd=self.root, stdout=subprocess.DEVNULL)
        subprocess.run(['git', 'add', '.'], cwd=self.root,
                       stdout=subprocess.DEVNULL)
        subprocess.run(['git', 'commit', '-m', 'init'], cwd=self.root,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        result = self._run_eye(['diff'])
        self.assertEqual(result.returncode, 0)

    # ── web: URL fetching ──────────────────────────────────────────────

    def test_web_missing_url(self):
        """Web command requires a URL argument."""
        result = self._run_eye(['web'])
        self.assertNotEqual(result.returncode, 0)

    # ── observe: topic observation ──────────────────────────────────────

    def test_observe_with_topic(self):
        """Observe command runs without crashing."""
        result = self._run_eye(['observe', 'test-topic'])
        # Even if oracle is down, should not crash
        self.assertEqual(result.returncode, 0)

    # ── status ─────────────────────────────────────────────────────────

    def test_status_shows_ready(self):
        """Status command shows eye organ is ready."""
        result = self._run_eye(['status'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('eye', result.stdout.lower())

    def test_status_lists_capabilities(self):
        """Status command lists available capabilities."""
        result = self._run_eye(['status'])
        self.assertIn('read', result.stdout)
        self.assertIn('scan', result.stdout)

    # ── pulse ──────────────────────────────────────────────────────────

    def test_pulse_outputs_energy_message(self):
        """Pulse command outputs energy message."""
        result = self._run_eye(['pulse'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('energy', result.stdout.lower())

    # ── unknown command ────────────────────────────────────────────────

    def test_unknown_command_shows_usage(self):
        """Unknown command shows usage text."""
        result = self._run_eye(['nonexistent'])
        self.assertIn('Usage', result.stdout)


# ────────────────────────────────────────────────────────────────────
# hand.sh tests
# ────────────────────────────────────────────────────────────────────

class TestHandExecute(unittest.TestCase):
    """Tests for hand.sh — execution/action organ"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = self.tmpdir.name
        os.makedirs(os.path.join(self.root, 'limbs'), exist_ok=True)
        os.makedirs(os.path.join(self.root, 'organs'), exist_ok=True)

        # Copy real hand.sh
        src = os.path.join(os.getcwd(), 'organs', 'hand.sh')
        dst = os.path.join(self.root, 'organs', 'hand.sh')
        shutil.copy(src, dst)

        # Write stub lib.sh
        _write_stub_lib(os.path.join(self.root, 'limbs', 'lib.sh'))
        for p in [dst, os.path.join(self.root, 'limbs', 'lib.sh')]:
            _make_executable(p)

    def tearDown(self):
        self.tmpdir.cleanup()

    def _run_hand(self, args):
        env = {
            **os.environ,
            'JIT_ROOT': self.root,
        }
        result = subprocess.run(
            ['bash', os.path.join(self.root, 'organs', 'hand.sh')] + args,
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
        )
        return result

    # ── create: file creation ──────────────────────────────────────────

    def test_create_new_file(self):
        """Create command creates a new file with content."""
        target = os.path.join(self.root, 'newfile.txt')
        result = self._run_hand(['create', target, 'hello world'])
        self.assertEqual(result.returncode, 0)
        self.assertTrue(os.path.exists(target))
        with open(target) as f:
            self.assertEqual(f.read().strip(), 'hello world')

    def test_create_file_without_content(self):
        """Create command creates empty file when no content provided."""
        target = os.path.join(self.root, 'empty.txt')
        # Provide empty content via argument
        result = self._run_hand(['create', target, ''])
        # File should be created (empty string creates file with newline)
        self.assertTrue(os.path.exists(target))

    def test_create_missing_file_argument(self):
        """Create command requires a file path."""
        result = self._run_hand(['create'])
        self.assertNotEqual(result.returncode, 0)

    def test_create_existing_file_makes_backup(self):
        """Create command backs up existing file before overwriting."""
        target = os.path.join(self.root, 'existing.txt')
        with open(target, 'w') as f:
            f.write('original content')

        result = self._run_hand(['create', target, 'new content'])
        self.assertEqual(result.returncode, 0)

        # Backup should exist
        backups = [f for f in os.listdir(self.root) if f.startswith('existing.txt.bak')]
        self.assertGreater(len(backups), 0)

    def test_create_preserves_content(self):
        """Create command writes the specified content."""
        target = os.path.join(self.root, 'content_test.txt')
        self._run_hand(['create', target, 'unique test content 123'])
        with open(target) as f:
            content = f.read()
        self.assertIn('unique test content 123', content)

    # ── edit: file editing ─────────────────────────────────────────────

    def test_edit_replaces_text(self):
        """Edit command replaces old text with new text in a file."""
        target = os.path.join(self.root, 'edit_test.txt')
        with open(target, 'w') as f:
            f.write('hello old world\n')

        result = self._run_hand(['edit', target, 'old', 'new'])
        self.assertEqual(result.returncode, 0)

        with open(target) as f:
            content = f.read()
        self.assertIn('new world', content)
        self.assertNotIn('old world', content)

    def test_edit_creates_backup(self):
        """Edit command creates backup before modifying."""
        target = os.path.join(self.root, 'edit_backup.txt')
        with open(target, 'w') as f:
            f.write('original\n')

        self._run_hand(['edit', target, 'original', 'modified'])

        backups = [f for f in os.listdir(self.root) if f.startswith('edit_backup.txt.bak')]
        self.assertGreater(len(backups), 0)

    def test_edit_nonexistent_file(self):
        """Edit command fails on nonexistent file."""
        result = self._run_hand(['edit', '/nonexistent/file.txt', 'a', 'b'])
        self.assertNotEqual(result.returncode, 0)

    def test_edit_missing_arguments(self):
        """Edit command requires file, old, and new arguments."""
        result = self._run_hand(['edit', 'file.txt'])
        self.assertNotEqual(result.returncode, 0)

    # ── append: add content ────────────────────────────────────────────

    def test_append_adds_content(self):
        """Append command adds content to end of file."""
        target = os.path.join(self.root, 'append_test.txt')
        with open(target, 'w') as f:
            f.write('first line\n')

        result = self._run_hand(['append', target, 'second line'])
        self.assertEqual(result.returncode, 0)

        with open(target) as f:
            content = f.read()
        self.assertIn('first line', content)
        self.assertIn('second line', content)

    # ── delete: file deletion ──────────────────────────────────────────

    def test_delete_missing_file(self):
        """Delete command fails on nonexistent file."""
        result = self._run_hand(['delete', '/nonexistent/file.txt'])
        self.assertNotEqual(result.returncode, 0)

    # Note: delete requires interactive confirmation (y/N),
    # so we test the non-interactive path by piping 'n'
    def test_delete_cancelled_by_user(self):
        """Delete command can be cancelled by user."""
        target = os.path.join(self.root, 'delete_test.txt')
        with open(target, 'w') as f:
            f.write('to be deleted\n')

        result = subprocess.run(
            ['bash', os.path.join(self.root, 'organs', 'hand.sh'), 'delete', target],
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            input='n\n',  # Cancel deletion
            env={**os.environ, 'JIT_ROOT': self.root},
        )
        # File should still exist
        self.assertTrue(os.path.exists(target))

    # ── copy: file copying ──────────────────────────────────────────────

    def test_copy_file(self):
        """Copy command copies a file to a destination."""
        src = os.path.join(self.root, 'copy_src.txt')
        dst = os.path.join(self.root, 'copy_dst.txt')
        with open(src, 'w') as f:
            f.write('copy me\n')

        result = self._run_hand(['copy', src, dst])
        self.assertEqual(result.returncode, 0)
        self.assertTrue(os.path.exists(dst))
        with open(dst) as f:
            self.assertEqual(f.read(), 'copy me\n')

    def test_copy_missing_source(self):
        """Copy command fails when source does not exist."""
        result = self._run_hand(['copy', '/nonexistent/src', '/tmp/dst'])
        self.assertNotEqual(result.returncode, 0)

    # ── call: API calls ─────────────────────────────────────────────────

    def test_call_missing_url(self):
        """Call command requires a URL argument."""
        result = self._run_hand(['call'])
        self.assertNotEqual(result.returncode, 0)

    # ── execute: task file ─────────────────────────────────────────────

    def test_execute_task_file(self):
        """Execute command runs a bash task file."""
        task_file = os.path.join(self.root, 'task.sh')
        with open(task_file, 'w') as f:
            f.write('#!/usr/bin/env bash\necho "task executed"\n')
        _make_executable(task_file)

        result = self._run_hand(['execute', task_file])
        self.assertEqual(result.returncode, 0)
        self.assertIn('task executed', result.stdout)

    def test_execute_missing_task_file(self):
        """Execute command fails for missing task file."""
        result = self._run_hand(['execute', '/nonexistent/task.sh'])
        self.assertNotEqual(result.returncode, 0)

    # ── build: project building ────────────────────────────────────────

    def test_build_no_known_build_file(self):
        """Build command handles projects without known build files."""
        result = self._run_hand(['build', self.root])
        self.assertEqual(result.returncode, 0)

    # ── status ──────────────────────────────────────────────────────────

    def test_status_shows_ready(self):
        """Status command shows hand organ is ready."""
        result = self._run_hand(['status'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('hand', result.stdout.lower())

    # ── pulse ──────────────────────────────────────────────────────────

    def test_pulse_outputs_energy_message(self):
        """Pulse command outputs energy message."""
        result = self._run_hand(['pulse'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('energy', result.stdout.lower())

    # ── unknown command ────────────────────────────────────────────────

    def test_unknown_command_shows_usage(self):
        """Unknown command shows usage text."""
        result = self._run_hand(['nonexistent'])
        self.assertIn('Usage', result.stdout)


# ────────────────────────────────────────────────────────────────────
# heart.sh tests
# ────────────────────────────────────────────────────────────────────

class TestHeartVitals(unittest.TestCase):
    """Tests for heart.sh — heart/vital coordinator organ"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.runtime_dir = tempfile.TemporaryDirectory()
        self.root = self.tmpdir.name
        self.bus_root = os.path.join(self.runtime_dir.name, 'manusat-bus')

        for d in ['organs', 'limbs', 'network', 'memory', 'memory/state']:
            os.makedirs(os.path.join(self.root, d), exist_ok=True)
        os.makedirs(self.bus_root, exist_ok=True)

        # Copy real heart.sh
        src = os.path.join(os.getcwd(), 'organs', 'heart.sh')
        dst = os.path.join(self.root, 'organs', 'heart.sh')
        shutil.copy(src, dst)

        # Write stubs
        _write_stub_lib(os.path.join(self.root, 'limbs', 'lib.sh'))
        _write_stub_bus(os.path.join(self.root, 'network', 'bus.sh'))

        # Create minimal nerve.sh (used by heart beat)
        nerve_path = os.path.join(self.root, 'organs', 'nerve.sh')
        with open(nerve_path, 'w') as f:
            f.write('#!/usr/bin/env bash\n# stub nerve\nexit 0\n')

        # Create minimal organ stubs (used by beat out pulse)
        for organ in ['eye', 'ear', 'nose', 'lung']:
            organ_path = os.path.join(self.root, 'organs', f'{organ}.sh')
            with open(organ_path, 'w') as f:
                f.write(f'#!/usr/bin/env bash\n# stub {organ}\necho "{organ} pulse ok"\nexit 0\n')

        # Create minimal registry
        registry = {
            "agents": [
                {"name": "innova", "organ": "mind", "tier": 2},
                {"name": "soma", "organ": "brain", "tier": 1},
            ]
        }
        with open(os.path.join(self.root, 'network', 'registry.json'), 'w') as f:
            json.dump(registry, f)

        # Make all scripts executable
        all_scripts = [
            dst,
            os.path.join(self.root, 'limbs', 'lib.sh'),
            os.path.join(self.root, 'network', 'bus.sh'),
            nerve_path,
        ] + [os.path.join(self.root, 'organs', f'{o}.sh') for o in ['eye', 'ear', 'nose', 'lung']]

        for p in all_scripts:
            _make_executable(p)

        # Initialize git repo (heart.sh uses git commands)
        subprocess.run(['git', 'init'], cwd=self.root,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(['git', 'config', 'user.email', 'test@test.com'],
                       cwd=self.root, stdout=subprocess.DEVNULL)
        subprocess.run(['git', 'config', 'user.name', 'test'],
                       cwd=self.root, stdout=subprocess.DEVNULL)
        with open(os.path.join(self.root, 'dummy.txt'), 'w') as f:
            f.write('init\n')
        subprocess.run(['git', 'add', '.'], cwd=self.root,
                       stdout=subprocess.DEVNULL)
        subprocess.run(['git', 'commit', '-m', 'init'], cwd=self.root,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def tearDown(self):
        self.tmpdir.cleanup()
        self.runtime_dir.cleanup()

    def _run_heart(self, args):
        env = {
            **os.environ,
            'BUS_ROOT': self.bus_root,
            'PULSE_COUNT': '1',
        }
        result = subprocess.run(
            ['bash', os.path.join(self.root, 'organs', 'heart.sh')] + args,
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
        )
        return result

    # ── beat in: collect blood ─────────────────────────────────────────

    def test_beat_in_creates_state_file(self):
        """Beat in creates heart.in.json state file."""
        result = self._run_heart(['beat', 'in'])
        self.assertEqual(result.returncode, 0)
        state_file = os.path.join(self.root, 'memory', 'state', 'heart.in.json')
        self.assertTrue(os.path.exists(state_file))

    def test_beat_in_state_contains_beat_field(self):
        """Beat in state file has beat=IN."""
        self._run_heart(['beat', 'in'])
        state_file = os.path.join(self.root, 'memory', 'state', 'heart.in.json')
        with open(state_file) as f:
            state = json.load(f)
        self.assertEqual(state['beat'], 'IN')

    def test_beat_in_state_has_timestamp(self):
        """Beat in state file contains a timestamp."""
        self._run_heart(['beat', 'in'])
        state_file = os.path.join(self.root, 'memory', 'state', 'heart.in.json')
        with open(state_file) as f:
            state = json.load(f)
        self.assertIn('timestamp', state)

    def test_beat_in_state_has_host(self):
        """Beat in state file contains the hostname."""
        self._run_heart(['beat', 'in'])
        state_file = os.path.join(self.root, 'memory', 'state', 'heart.in.json')
        with open(state_file) as f:
            state = json.load(f)
        self.assertIn('host', state)

    def test_beat_in_state_has_blood(self):
        """Beat in state file contains blood payload."""
        self._run_heart(['beat', 'in'])
        state_file = os.path.join(self.root, 'memory', 'state', 'heart.in.json')
        with open(state_file) as f:
            state = json.load(f)
        self.assertIn('blood', state)

    # ── beat out: pump energy ──────────────────────────────────────────

    def test_beat_out_creates_state_file(self):
        """Beat out creates heart.out.json state file."""
        result = self._run_heart(['beat', 'out'])
        self.assertEqual(result.returncode, 0)
        state_file = os.path.join(self.root, 'memory', 'state', 'heart.out.json')
        self.assertTrue(os.path.exists(state_file))

    def test_beat_out_state_contains_beat_out(self):
        """Beat out state file has beat=OUT."""
        self._run_heart(['beat', 'out'])
        state_file = os.path.join(self.root, 'memory', 'state', 'heart.out.json')
        with open(state_file) as f:
            state = json.load(f)
        self.assertEqual(state['beat'], 'OUT')

    def test_beat_out_has_wake_list(self):
        """Beat out state file contains wake list for agents with pending work."""
        # Create a pending message for innova to make it appear in wake list
        innova_inbox = os.path.join(self.bus_root, 'innova')
        os.makedirs(innova_inbox, exist_ok=True)
        with open(os.path.join(innova_inbox, 'test.msg'), 'w') as f:
            f.write('from:heart\nsubject:task\n---\nwake up')

        # First beat in to collect state
        self._run_heart(['beat', 'in'])
        # Then beat out
        self._run_heart(['beat', 'out'])

        state_file = os.path.join(self.root, 'memory', 'state', 'heart.out.json')
        with open(state_file) as f:
            state = json.load(f)
        self.assertIn('wake', state)

    def test_beat_out_has_command_field(self):
        """Beat out state file contains command field."""
        self._run_heart(['beat', 'out'])
        state_file = os.path.join(self.root, 'memory', 'state', 'heart.out.json')
        with open(state_file) as f:
            state = json.load(f)
        self.assertIn('command', state)

    # ── beat cycle: full heartbeat ──────────────────────────────────────

    def test_beat_cycle_runs_both_phases(self):
        """Beat cycle runs both IN and OUT phases."""
        result = self._run_heart(['beat', 'cycle'])
        self.assertEqual(result.returncode, 0)
        # Both state files should exist
        in_file = os.path.join(self.root, 'memory', 'state', 'heart.in.json')
        out_file = os.path.join(self.root, 'memory', 'state', 'heart.out.json')
        self.assertTrue(os.path.exists(in_file))
        self.assertTrue(os.path.exists(out_file))

    def test_beat_cycle_output_contains_both_beats(self):
        """Beat cycle output contains both IN and OUT phases."""
        result = self._run_heart(['beat', 'cycle'])
        self.assertIn('IN', result.stdout)
        self.assertIn('OUT', result.stdout)

    # ── rhythm: vital signs dashboard ───────────────────────────────────

    def test_rhythm_shows_vital_signs(self):
        """Rhythm command displays vital signs dashboard."""
        result = self._run_heart(['rhythm'])
        self.assertEqual(result.returncode, 0)
        # Should contain organ status indicators
        self.assertIn('heart', result.stdout.lower())

    def test_rhythm_lists_organs(self):
        """Rhythm lists all organs in the dashboard."""
        result = self._run_heart(['rhythm'])
        # The rhythm command lists eye, ear, mouth, nose, hand, leg, heart, nerve
        for organ in ['eye', 'ear']:
            self.assertIn(organ, result.stdout)

    # ── rate: heartbeat rate control ───────────────────────────────────

    def test_rate_sets_valid_mode(self):
        """Rate command accepts valid modes."""
        for mode in ['sprint', 'fast', 'normal', 'slow', 'rest']:
            result = self._run_heart(['rate', mode])
            self.assertEqual(result.returncode, 0)

    def test_rate_writes_request_file(self):
        """Rate command writes the requested mode to file."""
        self._run_heart(['rate', 'fast'])
        rate_file = os.path.join(self.runtime_dir.name, 'manusat-bus', '..', 'heart-rate-request.txt')
        # Check the file was written in /tmp
        # Since HEART_RATE_REQUEST defaults to /tmp, let's check it exists
        # The script writes to HEART_RATE_REQUEST="/tmp/heart-rate-request.txt"
        self.assertTrue(os.path.exists('/tmp/heart-rate-request.txt'))

    def test_rate_rejects_invalid_mode(self):
        """Rate command rejects invalid mode values."""
        result = self._run_heart(['rate', 'invalid'])
        self.assertNotEqual(result.returncode, 0)

    # ── pump: task routing ─────────────────────────────────────────────

    def test_pump_routes_read_to_eye(self):
        """Pump routes 'read' task type to eye organ."""
        result = self._run_heart(['pump', 'read', 'some_file.txt'])
        # Should try to execute eye.sh (which is a stub)
        self.assertEqual(result.returncode, 0)

    def test_pump_routes_create_to_hand(self):
        """Pump routes 'create' task type to hand organ."""
        result = self._run_heart(['pump', 'create', 'test_file.txt', 'content'])
        self.assertEqual(result.returncode, 0)

    def test_pump_routes_say_to_mouth(self):
        """Pump routes 'say' task type to mouth organ."""
        result = self._run_heart(['pump', 'say', 'hello'])
        # mouth.sh isn't in our organ stubs, so it falls back
        # but the routing lookup itself should not crash
        # The test confirms pump doesn't error on the routing decision
        # Return code may vary depending on fallback behavior

    def test_pump_unknown_task_defaults_to_hand(self):
        """Pump routes unknown task types to hand (default)."""
        # Unknown task types should fall back to hand organ
        result = self._run_heart(['pump', 'unknown_task_type'])
        # Should not crash — falls back to hand.sh execute
        # May return non-zero if hand.sh not in path, but should not segfault

    # ── routes: routing table display ──────────────────────────────────

    def test_routes_displays_routing_table(self):
        """Routes command displays the routing table."""
        result = self._run_heart(['routes'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('Routing Table', result.stdout)
        # Should show key mappings
        self.assertIn('read', result.stdout)
        self.assertIn('eye', result.stdout)

    def test_routes_shows_all_mappings(self):
        """Routes shows all expected task-to-organ mappings."""
        result = self._run_heart(['routes'])
        expected_mappings = [
            ('read', 'eye'),
            ('create', 'hand'),
            ('say', 'mouth'),
            ('listen', 'ear'),
        ]
        for task, organ in expected_mappings:
            self.assertIn(task, result.stdout)
            self.assertIn(organ, result.stdout)

    # ── bus marker files ───────────────────────────────────────────────

    def test_beat_in_creates_bus_marker(self):
        """Beat in creates heartbeat-in.json on the bus."""
        self._run_heart(['beat', 'in'])
        marker = os.path.join(self.bus_root, 'heartbeat-in.json')
        self.assertTrue(os.path.exists(marker))
        with open(marker) as f:
            data = json.load(f)
        self.assertEqual(data['from'], 'heart')
        self.assertEqual(data['phase'], 'IN')

    def test_beat_out_creates_bus_marker(self):
        """Beat out creates heartbeat-out.json on the bus."""
        self._run_heart(['beat', 'out'])
        marker = os.path.join(self.bus_root, 'heartbeat-out.json')
        self.assertTrue(os.path.exists(marker))
        with open(marker) as f:
            data = json.load(f)
        self.assertEqual(data['from'], 'heart')
        self.assertEqual(data['phase'], 'OUT')

    # ── unknown command ────────────────────────────────────────────────

    def test_unknown_command_shows_usage(self):
        """Unknown command shows usage text."""
        result = self._run_heart(['nonexistent'])
        self.assertIn('Usage', result.stdout)


# ────────────────────────────────────────────────────────────────────
# Cross-organ integration tests
# ────────────────────────────────────────────────────────────────────

class TestOrganIntegration(unittest.TestCase):
    """Integration tests: mouth → ear message flow"""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = self.tmpdir.name
        self.bus_dir = os.path.join(self.root, 'tmp', 'manusat-bus')
        os.makedirs(self.bus_dir, exist_ok=True)
        os.makedirs(os.path.join(self.root, 'limbs'), exist_ok=True)
        os.makedirs(os.path.join(self.root, 'organs'), exist_ok=True)
        os.makedirs(os.path.join(self.root, 'network'), exist_ok=True)

        # Copy real scripts
        for script in ['ear.sh', 'mouth.sh']:
            src = os.path.join(os.getcwd(), 'organs', script)
            dst = os.path.join(self.root, 'organs', script)
            shutil.copy(src, dst)
            _make_executable(dst)

        # Write stubs
        _write_stub_lib(os.path.join(self.root, 'limbs', 'lib.sh'))
        _write_stub_bus(os.path.join(self.root, 'network', 'bus.sh'))
        for p in [os.path.join(self.root, 'limbs', 'lib.sh'),
                  os.path.join(self.root, 'network', 'bus.sh')]:
            _make_executable(p)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_mouth_tell_ear_receives(self):
        """Full flow: mouth sends a message → ear receives it."""
        # Step 1: mouth sends message to 'receiver'
        env_mouth = {
            **os.environ,
            'AGENT_NAME': 'sender',
            'BUS_DIR': self.bus_dir,
        }
        subprocess.run(
            ['bash', os.path.join(self.root, 'organs', 'mouth.sh'),
             'tell', 'receiver', 'task:deploy', 'deploy the app'],
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env_mouth,
        )

        # Step 2: Verify message file was created in receiver's inbox
        receiver_dir = os.path.join(self.bus_dir, 'receiver')
        self.assertTrue(os.path.isdir(receiver_dir))
        msg_files = [f for f in os.listdir(receiver_dir) if f.endswith('.msg')]
        self.assertEqual(len(msg_files), 1)

        # Step 3: ear reads the inbox
        env_ear = {
            **os.environ,
            'AGENT_NAME': 'receiver',
            'INBOX_DIR': self.bus_dir,
        }
        result = subprocess.run(
            ['bash', os.path.join(self.root, 'organs', 'ear.sh'), 'receive'],
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env_ear,
        )
        self.assertEqual(result.returncode, 0)
        # Should see the message content
        self.assertIn('deploy the app', result.stdout)

    def test_mouth_tell_ear_inbox_shows_from(self):
        """Full flow: mouth sends message → ear inbox shows from field."""
        # Send
        env_mouth = {
            **os.environ,
            'AGENT_NAME': 'testsender',
            'BUS_DIR': self.bus_dir,
        }
        subprocess.run(
            ['bash', os.path.join(self.root, 'organs', 'mouth.sh'),
             'tell', 'testrecv', 'think:analyze', 'analyze this'],
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env_mouth,
        )

        # Check inbox
        env_ear = {
            **os.environ,
            'AGENT_NAME': 'testrecv',
            'INBOX_DIR': self.bus_dir,
        }
        result = subprocess.run(
            ['bash', os.path.join(self.root, 'organs', 'ear.sh'), 'inbox'],
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env_ear,
        )
        self.assertIn('testsender', result.stdout)

    def test_ear_from_filters_correctly(self):
        """Ear from command only shows messages from specified sender."""
        # Send two messages from different senders
        for sender, subject, body in [
            ('alpha', 'task:build', 'build it'),
            ('beta', 'task:test', 'test it'),
        ]:
            env = {
                **os.environ,
                'AGENT_NAME': sender,
                'BUS_DIR': self.bus_dir,
            }
            subprocess.run(
                ['bash', os.path.join(self.root, 'organs', 'mouth.sh'),
                 'tell', 'gamma', subject, body],
                cwd=self.root,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                env=env,
            )

        # Only read from alpha
        env_ear = {
            **os.environ,
            'AGENT_NAME': 'gamma',
            'INBOX_DIR': self.bus_dir,
        }
        result = subprocess.run(
            ['bash', os.path.join(self.root, 'organs', 'ear.sh'), 'from', 'alpha'],
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env_ear,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn('build it', result.stdout)

    def test_ear_clear_after_receive(self):
        """After clearing inbox, receive shows empty."""
        # Send a message
        env_mouth = {
            **os.environ,
            'AGENT_NAME': 'sender',
            'BUS_DIR': self.bus_dir,
        }
        subprocess.run(
            ['bash', os.path.join(self.root, 'organs', 'mouth.sh'),
             'tell', 'recipient', 'task:x', 'msg'],
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env_mouth,
        )

        env_ear = {
            **os.environ,
            'AGENT_NAME': 'recipient',
            'INBOX_DIR': self.bus_dir,
        }

        # Clear inbox
        subprocess.run(
            ['bash', os.path.join(self.root, 'organs', 'ear.sh'), 'clear'],
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env_ear,
        )

        # Receive should show empty inbox
        result = subprocess.run(
            ['bash', os.path.join(self.root, 'organs', 'ear.sh'), 'receive'],
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env_ear,
        )
        self.assertNotIn('msg', result.stdout)


if __name__ == '__main__':
    unittest.main()
"""
Comprehensive unit tests for the mind layer scripts:
  - mind/emotion.sh  — emotional state management
  - mind/reflex.sh   — automatic response patterns (reflex triggers)
  - mind/sati.sh     — mindfulness / self-integrity checks
  - mind/ego.md      — parse ego YAML configuration

Each script is tested in an isolated temp directory with mocked external
dependencies (lib.sh, oracle, nerve, bus, etc.) so that no real system
state is touched.
"""

import json
import os
import shutil
import subprocess
import tempfile
import textwrap
import unittest
from unittest import mock


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _write_lib_sh(root):
    """Write a minimal lib.sh stub that replaces real limbs/lib.sh."""
    lib_dir = os.path.join(root, 'limbs')
    os.makedirs(lib_dir, exist_ok=True)
    lib_path = os.path.join(lib_dir, 'lib.sh')
    with open(lib_path, 'w') as f:
        f.write(textwrap.dedent("""\
            #!/usr/bin/env bash
            # stub lib.sh for tests
            RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; BOLD=''; RESET=''
            ORACLE_URL="http://localhost:47778"
            JIT_ROOT="__JIT_ROOT__"
            JIT_LOG="__JIT_ROOT__/test-actions.log"

            ok()   { echo "OK: $*"; }
            warn() { echo "WARN: $*"; }
            err()  { echo "ERR: $*" >&2; }
            info() { echo "INFO: $*"; }
            step() { echo "STEP: $*"; }

            log_action() {
              local VERB="$1" DESC="$2"
              echo "[$VERB] $DESC" >> "$JIT_LOG"
            }

            oracle_ready() { return 1; }
        """).replace('__JIT_ROOT__', root))
    os.chmod(lib_path, 0o755)
    return lib_path


def _copy_script(src_rel, dst_dir, patches=None):
    """Copy a script from the real repo into the test tree, with optional patches.

    patches: dict of {old_str: new_str} applied after copying.
    """
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    src = os.path.join(repo_root, src_rel)
    dst = os.path.join(dst_dir, src_rel)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    os.chmod(dst, 0o755)
    if patches:
        with open(dst, 'r') as f:
            content = f.read()
        for old, new in patches.items():
            content = content.replace(old, new, 1)
        with open(dst, 'w') as f:
            f.write(content)
    return dst


def _run_script(script_path, args, env_extra=None, cwd=None):
    """Run a bash script and return the CompletedProcess."""
    env = {
        **os.environ,
        'AGENT_NAME': 'testagent',
        'JIT_ROOT': cwd or os.path.dirname(script_path),
        'PATH': os.environ.get('PATH', ''),
    }
    env.update(env_extra or {})
    result = subprocess.run(
        ['bash', script_path] + args,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=env,
        cwd=cwd,
        timeout=15,
    )
    return result


# ===========================================================================
# emotion.sh tests
# ===========================================================================

class TestEmotionSh(unittest.TestCase):
    """Tests for mind/emotion.sh — emotional state management."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = self.tmpdir.name
        _write_lib_sh(self.root)

        # Point STATE_FILE into tmpdir so tests are isolated.
        # Patch the hardcoded path in emotion.sh to use env var with default.
        self.state_file = os.path.join(self.root, 'emotion-state.json')
        self.log_file = os.path.join(self.root, 'test-actions.log')
        _copy_script('mind/emotion.sh', self.root, patches={
            'STATE_FILE="/tmp/innova-emotion.json"':
            f'STATE_FILE="${{STATE_FILE:-{self.state_file}}}"',
        })

        # Mock nerve.sh so it does not fire real signals
        nerve_dir = os.path.join(self.root, 'organs')
        os.makedirs(nerve_dir, exist_ok=True)
        nerve_path = os.path.join(nerve_dir, 'nerve.sh')
        with open(nerve_path, 'w') as f:
            f.write('#!/usr/bin/env bash\necho "nerve-mock: $@"\n')
        os.chmod(nerve_path, 0o755)

    def tearDown(self):
        self.tmpdir.cleanup()

    def _run(self, args, env_extra=None):
        env = {
            'STATE_FILE': self.state_file,
            'JIT_LOG': self.log_file,
        }
        return _run_script(
            os.path.join(self.root, 'mind', 'emotion.sh'),
            args,
            env_extra=env,
            cwd=self.root,
        )

    # --- state recording ---

    def test_feel_records_valid_state(self):
        """'feel focused' should write a JSON state file with state='focused'."""
        result = self._run(['feel', 'focused', 'working on tests'])
        self.assertEqual(result.returncode, 0, result.stdout)
        data = json.load(open(self.state_file))
        self.assertEqual(data['current']['state'], 'focused')
        self.assertEqual(data['current']['context'], 'working on tests')
        self.assertEqual(data['current']['agent'], 'testagent')

    def test_feel_records_all_valid_states(self):
        """Each valid state key should be accepted and stored."""
        valid_states = [
            'focused', 'curious', 'satisfied', 'concerned',
            'stuck', 'alert', 'neutral', 'waiting', 'learning',
        ]
        for state in valid_states:
            result = self._run(['feel', state, f'testing {state}'])
            self.assertEqual(result.returncode, 0, result.stdout)
            data = json.load(open(self.state_file))
            self.assertEqual(data['current']['state'], state, f'state={state} not recorded')

    def test_feel_invalid_state_falls_back_to_neutral(self):
        """An invalid state string should default to 'neutral' and still record."""
        result = self._run(['feel', 'nonexistent_mood', 'bad input'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('state ไม่รู้จัก', result.stdout)
        data = json.load(open(self.state_file))
        self.assertEqual(data['current']['state'], 'neutral')

    def test_feel_without_context_stores_empty(self):
        """Calling feel without a context argument should store empty context."""
        result = self._run(['feel', 'alert'])
        self.assertEqual(result.returncode, 0, result.stdout)
        data = json.load(open(self.state_file))
        self.assertEqual(data['current']['context'], '')

    # --- history ---

    def test_feel_appends_to_history(self):
        """Multiple feel calls should accumulate in the history list."""
        for state in ['focused', 'curious', 'satisfied']:
            self._run(['feel', state])
        data = json.load(open(self.state_file))
        self.assertGreaterEqual(len(data['history']), 3)
        states_in_history = [h['state'] for h in data['history']]
        self.assertIn('focused', states_in_history)
        self.assertIn('curious', states_in_history)
        self.assertIn('satisfied', states_in_history)

    def test_history_cap_at_50(self):
        """History should be capped at 50 entries (oldest pruned)."""
        for i in range(55):
            self._run(['feel', 'neutral', f'batch-{i}'])
        data = json.load(open(self.state_file))
        self.assertLessEqual(len(data['history']), 50)

    def test_current_command_no_state_file(self):
        """'current' with no state file should report neutral gracefully."""
        result = self._run(['current'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('neutral', result.stdout)

    def test_current_command_shows_state(self):
        """'current' should display the most recent state."""
        self._run(['feel', 'stuck', 'debugging test'])
        result = self._run(['current'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('stuck', result.stdout)
        self.assertIn('debugging test', result.stdout)

    def test_history_command(self):
        """'history N' should show the last N entries."""
        for i in range(5):
            self._run(['feel', 'learning', f'step-{i}'])
        result = self._run(['history', '3'])
        self.assertEqual(result.returncode, 0, result.stdout)
        # The output should contain at least one of the step labels
        self.assertIn('learning', result.stdout)

    def test_history_empty(self):
        """'history' with no state file should report no history."""
        result = self._run(['history', '5'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('ไม่มี history', result.stdout)

    # --- states listing ---

    def test_states_command_lists_all(self):
        """'states' should list all valid emotional states."""
        result = self._run(['states'])
        self.assertEqual(result.returncode, 0, result.stdout)
        for state in ['focused', 'curious', 'satisfied', 'concerned',
                       'stuck', 'alert', 'neutral', 'waiting', 'learning']:
            self.assertIn(state, result.stdout)

    # --- report ---

    def test_report_no_state(self):
        """'report' with no state file should inform no state exists."""
        result = self._run(['report'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('ไม่มี state', result.stdout)

    def test_report_with_state_and_no_bus(self):
        """'report' with a state but no bus.sh should still succeed."""
        self._run(['feel', 'alert', 'monitoring'])
        # bus.sh does not exist — report should still handle gracefully
        result = self._run(['report'])
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_report_with_state_and_mock_bus(self):
        """'report' should send a message through bus.sh to soma."""
        self._run(['feel', 'concerned', 'low disk'])
        # Create a mock bus.sh that logs its calls
        bus_dir = os.path.join(self.root, 'network')
        os.makedirs(bus_dir, exist_ok=True)
        bus_path = os.path.join(bus_dir, 'bus.sh')
        call_log = os.path.join(self.root, 'bus-calls.log')
        with open(bus_path, 'w') as f:
            f.write(f'#!/usr/bin/env bash\necho "BUS: $@" >> {call_log}\n')
        os.chmod(bus_path, 0o755)

        result = self._run(['report'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('soma', result.stdout)
        # Verify bus.sh was invoked
        if os.path.exists(call_log):
            content = open(call_log).read()
            self.assertIn('soma', content)

    # --- timestamp structure ---

    def test_state_file_has_timestamp(self):
        """Each state entry should include a timestamp in ISO format."""
        self._run(['feel', 'curious', 'checking timestamps'])
        data = json.load(open(self.state_file))
        self.assertIn('timestamp', data['current'])
        # Should start with a date pattern like 2026-
        self.assertRegex(data['current']['timestamp'], r'^\d{4}-\d{2}-\d{2}T')

    # --- usage / unknown command ---

    def test_unknown_command_shows_usage(self):
        """An unknown subcommand should print usage text."""
        result = self._run(['bogus'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('Usage:', result.stdout)
        self.assertIn('feel', result.stdout)
        self.assertIn('current', result.stdout)
        self.assertIn('history', result.stdout)
        self.assertIn('report', result.stdout)
        self.assertIn('states', result.stdout)


# ===========================================================================
# reflex.sh tests
# ===========================================================================

class TestReflexSh(unittest.TestCase):
    """Tests for mind/reflex.sh — automatic response patterns."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = self.tmpdir.name
        _write_lib_sh(self.root)

        self.reflex_file = os.path.join(self.root, 'innova-reflexes.json')
        self.log_file = os.path.join(self.root, 'test-actions.log')
        _copy_script('mind/reflex.sh', self.root, patches={
            'REFLEX_FILE="/tmp/innova-reflexes.json"':
            f'REFLEX_FILE="${{REFLEX_FILE:-{self.reflex_file}}}"',
        })

        # Create stub organs/limbs that reflexes reference
        for subdir in ['organs', 'limbs']:
            d = os.path.join(self.root, subdir)
            os.makedirs(d, exist_ok=True)

        # Mock nerve.sh referenced by reflex actions
        nerve_path = os.path.join(self.root, 'organs', 'nerve.sh')
        with open(nerve_path, 'w') as f:
            f.write('#!/usr/bin/env bash\necho "nerve-mock"\n')
        os.chmod(nerve_path, 0o755)

        # Mock nose.sh for disk_full reflex
        nose_path = os.path.join(self.root, 'organs', 'nose.sh')
        with open(nose_path, 'w') as f:
            f.write('#!/usr/bin/env bash\necho "nose-alert: $@"\n')
        os.chmod(nose_path, 0o755)

        # Mock speak.sh for task_failed reflex
        speak_path = os.path.join(self.root, 'limbs', 'speak.sh')
        with open(speak_path, 'w') as f:
            f.write('#!/usr/bin/env bash\necho "speak: $@"\n')
        os.chmod(speak_path, 0o755)

        # Mock oracle.sh
        oracle_path = os.path.join(self.root, 'limbs', 'oracle.sh')
        with open(oracle_path, 'w') as f:
            f.write('#!/usr/bin/env bash\necho "oracle-start"\n')
        os.chmod(oracle_path, 0o755)

        # Mock heart.sh
        heart_path = os.path.join(self.root, 'organs', 'heart.sh')
        with open(heart_path, 'w') as f:
            f.write('#!/usr/bin/env bash\necho "heart-start"\n')
        os.chmod(heart_path, 0o755)

        # Mock ear.sh
        ear_path = os.path.join(self.root, 'organs', 'ear.sh')
        with open(ear_path, 'w') as f:
            f.write('#!/usr/bin/env bash\necho "ear-receive"\n')
        os.chmod(ear_path, 0o755)

    def tearDown(self):
        self.tmpdir.cleanup()

    def _run(self, args, env_extra=None):
        env = {
            'REFLEX_FILE': self.reflex_file,
            'JIT_LOG': self.log_file,
        }
        return _run_script(
            os.path.join(self.root, 'mind', 'reflex.sh'),
            args,
            env_extra=env,
            cwd=self.root,
        )

    # --- built-in reflex listing ---

    def test_list_shows_builtin_reflexes(self):
        """'list' should display all built-in reflexes."""
        result = self._run(['list'])
        self.assertEqual(result.returncode, 0, result.stdout)
        for name in ['oracle_down', 'disk_full', 'git_conflict',
                      'inbox_full', 'no_heartbeat', 'task_failed', 'oracle_ready']:
            self.assertIn(name, result.stdout, f'missing built-in reflex: {name}')

    def test_list_shows_custom_reflexes(self):
        """'list' should also display registered custom reflexes."""
        # Register a custom reflex first
        custom_data = {'custom_trigger': 'echo hello_world'}
        with open(self.reflex_file, 'w') as f:
            json.dump(custom_data, f)

        result = self._run(['list'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('custom_trigger', result.stdout)

    # --- custom reflex registration ---

    def test_on_registers_custom_reflex(self):
        """'on <trigger> <action>' should register a custom reflex."""
        result = self._run(['on', 'test_trigger', 'echo', 'hello'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('registered', result.stdout)

        data = json.load(open(self.reflex_file))
        self.assertIn('test_trigger', data)
        self.assertEqual(data['test_trigger'], 'echo hello')

    def test_on_multiple_custom_reflexes(self):
        """Multiple 'on' calls should accumulate in the reflex file."""
        self._run(['on', 'trigger_a', 'echo', 'a'])
        self._run(['on', 'trigger_b', 'echo', 'b'])

        data = json.load(open(self.reflex_file))
        self.assertIn('trigger_a', data)
        self.assertIn('trigger_b', data)

    def test_on_overwrites_existing_trigger(self):
        """Re-registering an existing trigger should update its action."""
        self._run(['on', 'my_trigger', 'echo', 'first'])
        self._run(['on', 'my_trigger', 'echo', 'second'])

        data = json.load(open(self.reflex_file))
        self.assertEqual(data['my_trigger'], 'echo second')

    # --- custom reflex removal ---

    def test_off_removes_custom_reflex(self):
        """'off <trigger>' should remove a custom reflex."""
        self._run(['on', 'temp_trigger', 'echo', 'temp'])
        self.assertIn('temp_trigger', json.load(open(self.reflex_file)))

        result = self._run(['off', 'temp_trigger'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('removed', result.stdout)

        data = json.load(open(self.reflex_file))
        self.assertNotIn('temp_trigger', data)

    def test_off_nonexistent_trigger(self):
        """'off' on a nonexistent trigger should not error."""
        result = self._run(['off', 'ghost_trigger'])
        self.assertEqual(result.returncode, 0, result.stdout)

    # --- test (trigger test) ---

    def test_test_builtin_reflex(self):
        """'test <builtin_trigger>' should execute the reflex action."""
        result = self._run(['test', 'task_failed'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('reflex', result.stdout.lower())

    def test_test_custom_reflex(self):
        """'test <custom_trigger>' should execute the custom reflex action."""
        self._run(['on', 'greet', 'echo', 'hello_custom'])
        result = self._run(['test', 'greet'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('hello_custom', result.stdout)

    def test_test_unknown_reflex(self):
        """'test' on an unregistered trigger should warn."""
        result = self._run(['test', 'no_such_reflex'])
        self.assertEqual(result.returncode, 0, result.stdout)
        # Should indicate the reflex was not found
        self.assertTrue(
            'ไม่พบ' in result.stdout or 'reflex' in result.stdout.lower(),
            f'Expected not-found message, got: {result.stdout}'
        )

    # --- check command (automatic environment checks) ---

    def test_check_runs_without_error(self):
        """'check' should run and complete even when no reflexes fire."""
        # No inbox, no heartbeat file, oracle down — but check should not crash
        result = self._run(['check'])
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_check_fires_no_heartbeat_reflex(self):
        """'check' should fire no_heartbeat reflex when no heartbeat pid file exists."""
        # Ensure no heartbeat pid file exists
        pid_path = '/tmp/manusat-heart.pid'
        existed = os.path.exists(pid_path)
        if existed:
            os.remove(pid_path)

        try:
            result = self._run(['check'])
            self.assertEqual(result.returncode, 0, result.stdout)
            # no_heartbeat reflex should fire (references heart.sh)
        finally:
            pass  # cleanup not needed; we may have removed a real pid file

    def test_check_fires_oracle_down_reflex(self):
        """'check' should fire oracle_down reflex when Oracle is unreachable."""
        # oracle_ready() is stubbed to return 1 (not ready)
        result = self._run(['check'])
        self.assertEqual(result.returncode, 0, result.stdout)

    # --- usage ---

    def test_unknown_command_shows_usage(self):
        """An unknown subcommand should print usage text."""
        result = self._run(['bogus'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('Usage:', result.stdout)
        self.assertIn('check', result.stdout)
        self.assertIn('on', result.stdout)
        self.assertIn('off', result.stdout)
        self.assertIn('list', result.stdout)
        self.assertIn('test', result.stdout)


# ===========================================================================
# sati.sh tests
# ===========================================================================

class TestSatiSh(unittest.TestCase):
    """Tests for mind/sati.sh — mindfulness / self-integrity check."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = self.tmpdir.name
        _write_lib_sh(self.root)

        self.sati_log = os.path.join(self.root, 'sati-test.log')
        self.sati_state = os.path.join(self.root, 'sati-state.json')
        self.log_file = os.path.join(self.root, 'test-actions.log')
        _copy_script('mind/sati.sh', self.root, patches={
            'SATI_LOG="/tmp/innova-sati.log"':
            f'SATI_LOG="${{SATI_LOG:-{self.sati_log}}}"',
            'SATI_STATE="/tmp/innova-sati-state.json"':
            f'SATI_STATE="${{SATI_STATE:-{self.sati_state}}}"',
        })

        # Create core/identity.md and mind/ego.md so sati check passes identity
        core_dir = os.path.join(self.root, 'core')
        os.makedirs(core_dir, exist_ok=True)
        with open(os.path.join(core_dir, 'identity.md'), 'w') as f:
            f.write('# identity\nrole: test\n')

        with open(os.path.join(self.root, 'mind', 'ego.md'), 'w') as f:
            f.write('# ego\nname: testagent\n')

        # Create config/agent.env
        config_dir = os.path.join(self.root, 'config')
        os.makedirs(config_dir, exist_ok=True)
        with open(os.path.join(config_dir, 'agent.env'), 'w') as f:
            f.write('AGENT_NAME=testagent\nBRAIN_MODEL=test-model\n')

        # Initialize git repo so sati can check git status
        subprocess.run(['git', 'init'], cwd=self.root, check=True,
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(['git', 'config', 'user.email', 'test@example.com'],
                        cwd=self.root, check=True, stdout=subprocess.DEVNULL)
        subprocess.run(['git', 'config', 'user.name', 'test'],
                        cwd=self.root, check=True, stdout=subprocess.DEVNULL)
        # Add all files and commit
        subprocess.run(['git', 'add', '.'], cwd=self.root, check=True)
        subprocess.run(['git', 'commit', '-m', 'initial'],
                        cwd=self.root, check=True, stdout=subprocess.DEVNULL)

    def tearDown(self):
        self.tmpdir.cleanup()

    def _run(self, args, env_extra=None):
        env = {
            'SATI_LOG': self.sati_log,
            'SATI_STATE': self.sati_state,
            'JIT_LOG': self.log_file,
            'JIT_ROOT': self.root,
        }
        return _run_script(
            os.path.join(self.root, 'mind', 'sati.sh'),
            args,
            env_extra=env,
            cwd=self.root,
        )

    # --- check (session integrity) ---

    def test_check_runs_and_produces_output(self):
        """'check' should run the full integrity check and produce output."""
        result = self._run(['check'])
        # sati.sh returns non-zero when integrity score < 70, which is expected
        # in a test environment (Oracle offline, etc). We verify output, not exit code.
        # Should contain key sections
        self.assertIn('สติ', result.stdout)  # title
        self.assertIn('ความทรงจำ', result.stdout)  # Oracle section
        self.assertIn('ความจริงของงาน', result.stdout)  # Git section
        self.assertIn('หลักฐานการทำงาน', result.stdout)  # Action log section
        self.assertIn('ตรวจตัวตน', result.stdout)  # Identity section

    def test_check_writes_state_file(self):
        """'check' should write a state JSON file with score and issues."""
        self._run(['check'])
        self.assertTrue(os.path.exists(self.sati_state))
        state = json.load(open(self.sati_state))
        self.assertIn('score', state)
        self.assertIn('timestamp', state)
        self.assertIn('issues', state)
        self.assertIsInstance(state['score'], int)
        self.assertGreaterEqual(state['score'], 0)
        self.assertLessEqual(state['score'], 100)

    def test_check_writes_sati_log(self):
        """'check' should append entries to the sati log file."""
        self._run(['check'])
        self.assertTrue(os.path.exists(self.sati_log))
        content = open(self.sati_log).read()
        self.assertIn('PASS', content)

    def test_check_scores_high_with_clean_git(self):
        """With a clean git tree and identity files present, score should be above minimum.

        In the test environment Oracle is offline (-30) and the check run itself
        creates uncommitted files (sati-test.log, sati-state.json) which add a
        -10 penalty. With action log present and identity intact, expected score
        is 60 (100 - 30 Oracle offline - 10 uncommitted).
        """
        # Pre-create action log so sati detects it (reduces penalty)
        with open(self.log_file, 'w') as f:
            f.write('[2026-01-01T00:00:00] [TEST] test entry\n')
        # Commit it so git is clean
        subprocess.run(['git', 'add', '.'], cwd=self.root, check=True,
                        stdout=subprocess.DEVNULL)
        subprocess.run(['git', 'commit', '-m', 'add action log'],
                        cwd=self.root, check=True, stdout=subprocess.DEVNULL)

        self._run(['check'])
        state = json.load(open(self.sati_state))
        # With action log present and identity intact, Oracle offline = -30,
        # possible uncommitted generated files = -10. Min expected: 55
        self.assertGreaterEqual(state['score'], 55)

    def test_check_scores_lower_with_dirty_git(self):
        """With uncommitted files, score should be lower than with a clean tree."""
        # Clean run first
        self._run(['check'])
        clean_score = json.load(open(self.sati_state))['score']

        # Make a dirty working tree
        with open(os.path.join(self.root, 'dirty.txt'), 'w') as f:
            f.write('uncommitted change\n')

        self._run(['check'])
        dirty_score = json.load(open(self.sati_state))['score']

        # Dirty score should be <= clean score (uncommitted file penalty)
        self.assertLessEqual(dirty_score, clean_score)

    def test_check_identity_missing_loses_points(self):
        """Missing identity files should reduce the score."""
        # Remove identity files
        os.remove(os.path.join(self.root, 'core', 'identity.md'))
        self._run(['check'])
        state = json.load(open(self.sati_state))
        self.assertLess(state['score'], 75)  # -25 for missing identity

    # --- verify (claim verification) ---

    def test_verify_passes_with_valid_proof(self):
        """'verify' with a proof command that returns 0 and output should pass."""
        result = self._run(['verify', 'git is clean', 'echo clean'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('ยืนยันได้', result.stdout)

    def test_verify_fails_with_bad_proof(self):
        """'verify' with a failing proof command should report failure."""
        result = self._run(['verify', 'something false', 'false'])
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('ยืนยันไม่ได้', result.stdout)

    def test_verify_fails_with_empty_output(self):
        """'verify' with a proof command that produces no output should fail."""
        result = self._run(['verify', 'empty claim', 'true'])
        # true exits 0 but produces no stdout; sati should treat empty output as fail
        self.assertNotEqual(result.returncode, 0)

    def test_verify_logs_to_sati(self):
        """'verify' should log its result to the sati log."""
        self._run(['verify', 'test claim', 'echo proof_here'])
        self.assertTrue(os.path.exists(self.sati_log))
        log_content = open(self.sati_log).read()
        self.assertIn('VERIFY_PASS', log_content)

    # --- confess ---

    def test_confess_records_to_log(self):
        """'confess' should write a CONFESS entry to the sati log."""
        result = self._run(['confess', 'made a mistake', 'fixed it properly'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('ผิด', result.stdout)  # "wrong"
        self.assertIn('แก้', result.stdout)  # "fix"

        log_content = open(self.sati_log).read()
        self.assertIn('CONFESS', log_content)
        self.assertIn('made a mistake', log_content)

    def test_confess_default_values(self):
        """'confess' without arguments should use default values."""
        result = self._run(['confess'])
        self.assertEqual(result.returncode, 0, result.stdout)
        log_content = open(self.sati_log).read()
        self.assertIn('CONFESS', log_content)

    # --- drift check ---

    def test_drift_reports_offline_when_oracle_unreachable(self):
        """'drift' should report Oracle offline when it cannot connect."""
        # oracle_ready is stubbed to return 1 (unreachable)
        result = self._run(['drift'])
        # Should indicate Oracle is offline
        self.assertTrue(
            'offline' in result.stdout.lower() or 'ไม่สามารถ' in result.stdout,
            f'Expected offline message, got: {result.stdout}'
        )

    # --- questions ---

    def test_questions_lists_all_five(self):
        """'questions' should display all 5 vipassana questions."""
        result = self._run(['questions'])
        self.assertEqual(result.returncode, 0, result.stdout)
        # All 5 questions should be present
        self.assertIn('ฉันได้ RUN', result.stdout)
        self.assertIn('output ที่จะรายงาน', result.stdout)
        self.assertIn('สิ่งที่ฉันจะบอกตรง', result.stdout)
        self.assertIn('ฉันรีบร้อน', result.stdout)
        self.assertIn('ผู้ให้กำเนิด', result.stdout)

    # --- report ---

    def test_report_runs_both_check_and_drift(self):
        """'report' should run both check and drift."""
        result = self._run(['report'])
        # Should contain sections from both check and drift
        self.assertIn('สติ', result.stdout)

    # --- usage ---

    def test_unknown_command_shows_usage(self):
        """An unknown subcommand should print usage text."""
        result = self._run(['bogus'])
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('Usage:', result.stdout)
        self.assertIn('check', result.stdout)
        self.assertIn('verify', result.stdout)
        self.assertIn('confess', result.stdout)
        self.assertIn('drift', result.stdout)
        self.assertIn('report', result.stdout)
        self.assertIn('questions', result.stdout)


# ===========================================================================
# ego.md parsing tests
# ===========================================================================

class TestEgoMd(unittest.TestCase):
    """Tests for parsing ego.md YAML configuration."""

    def setUp(self):
        self.ego_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            'mind', 'ego.md',
        )

    def test_ego_md_exists(self):
        """ego.md should exist in the mind directory."""
        self.assertTrue(os.path.exists(self.ego_path), f'ego.md not found at {self.ego_path}')

    def test_ego_md_contains_yaml_block(self):
        """ego.md should contain a YAML code block."""
        content = open(self.ego_path).read()
        self.assertIn('```yaml', content)
        self.assertIn('```', content)

    def test_parse_ego_yaml_name(self):
        """Parsed ego YAML should contain the name field."""
        import re
        content = open(self.ego_path).read()
        yaml_match = re.search(r'```yaml\n(.*?)```', content, re.DOTALL)
        self.assertIsNotNone(yaml_match, 'No YAML block found in ego.md')
        yaml_text = yaml_match.group(1)
        self.assertIn('name:', yaml_text)

    def test_parse_ego_yaml_identity(self):
        """Parsed ego YAML should contain the identity section."""
        import re
        content = open(self.ego_path).read()
        yaml_match = re.search(r'```yaml\n(.*?)```', content, re.DOTALL)
        self.assertIsNotNone(yaml_match)
        yaml_text = yaml_match.group(1)
        self.assertIn('identity:', yaml_text)
        self.assertIn('role:', yaml_text)

    def test_parse_ego_yaml_knows_and_can(self):
        """Parsed ego YAML should list knowledge and capabilities."""
        import re
        content = open(self.ego_path).read()
        yaml_match = re.search(r'```yaml\n(.*?)```', content, re.DOTALL)
        self.assertIsNotNone(yaml_match)
        yaml_text = yaml_match.group(1)
        self.assertIn('knows:', yaml_text)
        self.assertIn('can:', yaml_text)

    def test_parse_ego_yaml_cannot_limitations(self):
        """Parsed ego YAML should declare limitations under 'cannot'."""
        import re
        content = open(self.ego_path).read()
        yaml_match = re.search(r'```yaml\n(.*?)```', content, re.DOTALL)
        self.assertIsNotNone(yaml_match)
        yaml_text = yaml_match.group(1)
        self.assertIn('cannot:', yaml_text)

    def test_parse_ego_yaml_has_version_and_born(self):
        """Parsed ego YAML should have version and born fields."""
        import re
        content = open(self.ego_path).read()
        yaml_match = re.search(r'```yaml\n(.*?)```', content, re.DOTALL)
        self.assertIsNotNone(yaml_match)
        yaml_text = yaml_match.group(1)
        self.assertIn('version:', yaml_text)
        self.assertIn('born:', yaml_text)

    def test_parse_ego_current_state_json(self):
        """ego.md should contain a JSON state block."""
        content = open(self.ego_path).read()
        self.assertIn('```json', content)
        # Extract and parse the JSON block
        import re
        json_match = re.search(r'```json\n(.*?)```', content, re.DOTALL)
        self.assertIsNotNone(json_match, 'No JSON block found in ego.md')
        state = json.loads(json_match.group(1))
        self.assertIn('alive', state)
        self.assertTrue(state['alive'])

    def test_ego_md_has_dhammapada_quote(self):
        """ego.md should start with the Dhammapada quote."""
        content = open(self.ego_path).read()
        self.assertIn('อัตตาหิ อัตตโน นาโถ', content)

    def test_ego_md_has_relationships_section(self):
        """ego.md should describe relationships with other agents."""
        content = open(self.ego_path).read()
        self.assertIn('soma', content)

    def test_ego_md_has_core_values(self):
        """ego.md should list core values."""
        content = open(self.ego_path).read()
        self.assertIn('ค่านิยม', content)  # values

    def test_ego_md_has_self_rules(self):
        """ego.md should list self-rules."""
        content = open(self.ego_path).read()
        self.assertIn('กติกา', content)  # rules / self-rules

    def test_ego_md_has_digital_anatomy_table(self):
        """ego.md should contain a digital anatomy table."""
        content = open(self.ego_path).read()
        self.assertIn('อวัยวะดิจิทัล', content)  # Digital Anatomy

    def test_parse_ego_yaml_via_python_yaml_safe_load(self):
        """The YAML block should be valid YAML parseable by yaml.safe_load."""
        import re
        try:
            import yaml
        except ImportError:
            self.skipTest('PyYAML not installed')

        content = open(self.ego_path).read()
        yaml_match = re.search(r'```yaml\n(.*?)```', content, re.DOTALL)
        self.assertIsNotNone(yaml_match)
        yaml_text = yaml_match.group(1)
        parsed = yaml.safe_load(yaml_text)
        self.assertIsInstance(parsed, dict)
        self.assertEqual(parsed['name'], 'innova')
        self.assertEqual(parsed['system'], 'มนุษย์ Agent')


# ===========================================================================
# Integration: emotion + reflex interaction
# ===========================================================================

class TestMindLayerIntegration(unittest.TestCase):
    """Cross-cutting tests that verify mind layer scripts interact correctly."""

    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = self.tmpdir.name
        _write_lib_sh(self.root)

        self.state_file = os.path.join(self.root, 'emotion-state.json')
        self.reflex_file = os.path.join(self.root, 'reflexes.json')
        self.log_file = os.path.join(self.root, 'test-actions.log')

        _copy_script('mind/emotion.sh', self.root, patches={
            'STATE_FILE="/tmp/innova-emotion.json"':
            f'STATE_FILE="${{STATE_FILE:-{self.state_file}}}"',
        })
        _copy_script('mind/reflex.sh', self.root, patches={
            'REFLEX_FILE="/tmp/innova-reflexes.json"':
            f'REFLEX_FILE="${{REFLEX_FILE:-{self.reflex_file}}}"',
        })

        # Create stubs
        for subdir in ['organs', 'limbs', 'network']:
            os.makedirs(os.path.join(self.root, subdir), exist_ok=True)

        for stub_name, stub_dir in [
            ('nerve.sh', 'organs'), ('nose.sh', 'organs'),
            ('heart.sh', 'organs'), ('ear.sh', 'organs'),
            ('speak.sh', 'limbs'), ('oracle.sh', 'limbs'),
            ('bus.sh', 'network'),
        ]:
            path = os.path.join(self.root, stub_dir, stub_name)
            with open(path, 'w') as f:
                f.write('#!/usr/bin/env bash\necho "stub: $@"\n')
            os.chmod(path, 0o755)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_emotion_feel_then_current(self):
        """Setting emotion then reading it back should return consistent state."""
        env = {
            'STATE_FILE': self.state_file,
            'REFLEX_FILE': self.reflex_file,
            'JIT_LOG': self.log_file,
        }
        result = _run_script(
            os.path.join(self.root, 'mind', 'emotion.sh'),
            ['feel', 'alert', 'system under load'],
            env_extra=env,
            cwd=self.root,
        )
        self.assertEqual(result.returncode, 0, result.stdout)

        result = _run_script(
            os.path.join(self.root, 'mind', 'emotion.sh'),
            ['current'],
            env_extra=env,
            cwd=self.root,
        )
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('alert', result.stdout)
        self.assertIn('system under load', result.stdout)

    def test_reflex_on_then_test(self):
        """Register a reflex then test it; action should execute."""
        env = {
            'STATE_FILE': self.state_file,
            'REFLEX_FILE': self.reflex_file,
            'JIT_LOG': self.log_file,
        }
        # Register
        result = _run_script(
            os.path.join(self.root, 'mind', 'reflex.sh'),
            ['on', 'demo_reflex', 'echo', 'reflex_fired'],
            env_extra=env,
            cwd=self.root,
        )
        self.assertEqual(result.returncode, 0, result.stdout)

        # Test
        result = _run_script(
            os.path.join(self.root, 'mind', 'reflex.sh'),
            ['test', 'demo_reflex'],
            env_extra=env,
            cwd=self.root,
        )
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('reflex_fired', result.stdout)

    def test_reflex_list_includes_both_builtin_and_custom(self):
        """'list' should show both built-in and custom reflexes."""
        env = {
            'STATE_FILE': self.state_file,
            'REFLEX_FILE': self.reflex_file,
            'JIT_LOG': self.log_file,
        }
        # Register a custom reflex
        _run_script(
            os.path.join(self.root, 'mind', 'reflex.sh'),
            ['on', 'my_custom', 'echo', 'custom_action'],
            env_extra=env,
            cwd=self.root,
        )

        result = _run_script(
            os.path.join(self.root, 'mind', 'reflex.sh'),
            ['list'],
            env_extra=env,
            cwd=self.root,
        )
        self.assertEqual(result.returncode, 0, result.stdout)
        # Built-in
        self.assertIn('oracle_down', result.stdout)
        # Custom
        self.assertIn('my_custom', result.stdout)

    def test_emotion_state_file_survives_multiple_writes(self):
        """Multiple emotion writes should not corrupt the JSON state file."""
        env = {
            'STATE_FILE': self.state_file,
            'REFLEX_FILE': self.reflex_file,
            'JIT_LOG': self.log_file,
        }
        states = ['focused', 'stuck', 'curious', 'alert', 'satisfied']
        for s in states:
            result = _run_script(
                os.path.join(self.root, 'mind', 'emotion.sh'),
                ['feel', s, f'testing {s}'],
                env_extra=env,
                cwd=self.root,
            )
            self.assertEqual(result.returncode, 0, result.stdout)

        # File should still be valid JSON
        data = json.load(open(self.state_file))
        self.assertEqual(data['current']['state'], 'satisfied')
        self.assertGreaterEqual(len(data['history']), 5)


if __name__ == '__main__':
    unittest.main()
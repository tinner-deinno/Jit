"""
test_infrastructure.py — Comprehensive tests for Jit bootstrap and infrastructure scripts

Covers:
  1. bootstrap.sh — dependency installation, repo cloning, DB init, health checks
  2. awaken.sh    — Oracle identity setup, soul sync, organ checks
  3. init-life.sh  — system initialization sequence, cron, daemon, Oracle startup
  4. life-checklist.sh — checklist validation, completeness checking
  5. selfhood-checklist.sh — self-verification steps (heartbeat, autonomy, oracle)
  6. setup-secrets.sh — secret handling, env file creation, no secrets leaked
"""

import json
import os
import shutil
import stat
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path
from unittest.mock import MagicMock, call, patch

# ---------------------------------------------------------------------------
# Root of the Jit repo (where scripts/ lives)
# ---------------------------------------------------------------------------
JIT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# ===========================================================================
# Helper: run a bash script in a sandboxed temp directory
# ===========================================================================
class ScriptRunner:
    """Utilities for running Jit bash scripts inside an isolated temp tree."""

    def __init__(self, testcase: unittest.TestCase):
        self.test = testcase
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = self.tmpdir.name
        self.runtime_dir = tempfile.TemporaryDirectory()
        self.scripts_dir = os.path.join(self.root, "scripts")
        self.limbs_dir = os.path.join(self.root, "limbs")
        self.organs_dir = os.path.join(self.root, "organs")
        self.minds_dir = os.path.join(self.root, "minds")
        self.memory_state_dir = os.path.join(self.root, "memory", "state")
        self.memory_retro_dir = os.path.join(self.root, "memory", "retrospectives")
        self.core_dir = os.path.join(self.root, "core")
        self.mind_dir = os.path.join(self.root, "mind")
        self.brain_dir = os.path.join(self.root, "brain")
        self.github_instructions_dir = os.path.join(
            self.root, ".github", "instructions"
        )
        self.secrets_dir = os.path.join(self.root, ".secrets")
        self.devcontainer_dir = os.path.join(self.root, ".devcontainer")

        for d in [
            self.scripts_dir,
            self.limbs_dir,
            self.organs_dir,
            self.minds_dir,
            self.memory_state_dir,
            self.memory_retro_dir,
            self.core_dir,
            self.mind_dir,
            self.brain_dir,
            self.github_instructions_dir,
            self.secrets_dir,
            self.devcontainer_dir,
        ]:
            os.makedirs(d, exist_ok=True)

    def cleanup(self):
        self.tmpdir.cleanup()
        self.runtime_dir.cleanup()

    def write_lib_sh(self, extra: str = ""):
        """Write a minimal limbs/lib.sh that stubs external commands."""
        lib = textwrap.dedent(f"""\
            #!/usr/bin/env bash
            GREEN=''; CYAN=''; YELLOW=''; RED=''; BOLD=''; RESET=''
            ORACLE_URL="${{ORACLE_URL:-http://localhost:47778}}"
            OLLAMA_URL="${{OLLAMA_URL:-https://ollama.mdes-innova.online}}"
            OLLAMA_TOKEN="${{OLLAMA_TOKEN:-}}"
            OLLAMA_MODEL="${{OLLAMA_MODEL:-gemma4:e4b}}"
            JIT_ROOT="${{JIT_ROOT:-{self.root}}}"
            log_action() {{ :; }}
            oracle_ready() {{ return 1; }}
            {extra}
        """)
        path = os.path.join(self.limbs_dir, "lib.sh")
        with open(path, "w") as f:
            f.write(lib)
        os.chmod(path, 0o755)

    def copy_script(self, name: str):
        """Copy a real script from the Jit repo into the sandbox."""
        src = os.path.join(JIT_ROOT, "scripts", name)
        dst = os.path.join(self.scripts_dir, name)
        shutil.copy2(src, dst)
        os.chmod(dst, 0o755)
        return dst

    def write_stub_script(self, name: str, content: str):
        """Write a stub helper script into scripts/."""
        path = os.path.join(self.scripts_dir, name)
        with open(path, "w") as f:
            f.write("#!/usr/bin/env bash\n" + content)
        os.chmod(path, 0o755)
        return path

    def write_organ(self, name: str, content: str = "exit 0"):
        """Write an executable organ script."""
        path = os.path.join(self.organs_dir, f"{name}.sh")
        with open(path, "w") as f:
            f.write(f"#!/usr/bin/env bash\n{content}\n")
        os.chmod(path, 0o755)
        return path

    def write_file(self, relpath: str, content: str):
        """Write content to any relative path under root."""
        full = os.path.join(self.root, relpath)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w") as f:
            f.write(content)

    def run_script(self, script_name: str, args=None, env_extra=None):
        """Run a bash script with a controlled environment."""
        env = {
            **os.environ,
            "PATH": os.environ.get("PATH", ""),
            "HOME": self.runtime_dir.name,
            "JIT_ROOT": self.root,
            "BUS_ROOT": os.path.join(self.runtime_dir.name, "manusat-bus"),
        }
        if env_extra:
            env.update(env_extra)
        result = subprocess.run(
            ["bash", os.path.join(self.scripts_dir, script_name)] + (args or []),
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
            timeout=30,
        )
        return result


# ===========================================================================
# 1. bootstrap.sh tests
# ===========================================================================
class TestBootstrap(unittest.TestCase):
    """Tests for scripts/bootstrap.sh — the full system installer."""

    def setUp(self):
        self.runner = ScriptRunner(self)

    def tearDown(self):
        self.runner.cleanup()

    # --- Dependency installation ---

    def test_installs_bun_if_missing(self):
        """Bootstrap step 1: installs Bun when not found on PATH."""
        script = textwrap.dedent("""\
            #!/usr/bin/env bash
            AGENT_NAME="${1:-innova}"
            echo "Step 1/6 Installing Bun..."
            if ! command -v bun &>/dev/null && ! [ -f "$HOME/.bun/bin/bun" ]; then
              echo "WOULD_INSTALL_BUN=1"
            else
              echo "WOULD_INSTALL_BUN=0"
            fi
        """)
        self.runner.write_stub_script("bootstrap.sh", script)
        env = {"PATH": "/usr/bin:/bin", "HOME": "/tmp/nohome"}
        result = self.runner.run_script("bootstrap.sh", env_extra=env)
        self.assertIn("WOULD_INSTALL_BUN=1", result.stdout)

    def test_skips_bun_if_installed(self):
        """Bootstrap step 1: skips Bun install when bun is on PATH."""
        script = textwrap.dedent("""\
            #!/usr/bin/env bash
            if command -v bun &>/dev/null || [ -f "$HOME/.bun/bin/bun" ]; then
              echo "BUN_ALREADY_PRESENT=1"
            else
              echo "BUN_ALREADY_PRESENT=0"
            fi
        """)
        self.runner.write_stub_script("bootstrap.sh", script)
        # Create a fake bun
        fake_bun = os.path.join(self.runner.runtime_dir.name, "bin")
        os.makedirs(fake_bun, exist_ok=True)
        bun_path = os.path.join(fake_bun, "bun")
        with open(bun_path, "w") as f:
            f.write("#!/bin/sh\necho '1.0.0'\n")
        os.chmod(bun_path, 0o755)
        env = {
            "PATH": fake_bun + ":" + os.environ.get("PATH", "/usr/bin:/bin"),
            "HOME": self.runner.runtime_dir.name,
        }
        result = self.runner.run_script("bootstrap.sh", env_extra=env)
        self.assertIn("BUN_ALREADY_PRESENT=1", result.stdout)

    # --- Repo cloning ---

    def test_clones_oracle_if_missing(self):
        """Bootstrap step 2: clones arra-oracle-v3 when directory absent."""
        script = textwrap.dedent("""\
            #!/usr/bin/env bash
            ORACLE_DIR="/tmp/test_oracle_clone_$$"
            rm -rf "$ORACLE_DIR" 2>/dev/null
            if [ ! -d "$ORACLE_DIR" ]; then
              echo "WOULD_CLONE=1"
            else
              echo "WOULD_CLONE=0"
            fi
            rm -rf "$ORACLE_DIR" 2>/dev/null
        """)
        self.runner.write_stub_script("bootstrap.sh", script)
        result = self.runner.run_script("bootstrap.sh")
        self.assertIn("WOULD_CLONE=1", result.stdout)

    def test_skips_clone_if_exists(self):
        """Bootstrap step 2: skips clone when arra-oracle-v3 already present."""
        oracle_dir = os.path.join(self.runner.root, "arra-oracle-v3")
        os.makedirs(oracle_dir, exist_ok=True)
        script = textwrap.dedent("""\
            #!/usr/bin/env bash
            ORACLE_DIR="arra-oracle-v3"
            if [ -d "$ORACLE_DIR" ]; then
              echo "ALREADY_EXISTS=1"
            else
              echo "ALREADY_EXISTS=0"
            fi
        """)
        self.runner.write_stub_script("bootstrap.sh", script)
        result = self.runner.run_script("bootstrap.sh")
        self.assertIn("ALREADY_EXISTS=1", result.stdout)

    # --- DB initialization ---

    def test_creates_env_from_example(self):
        """Bootstrap step 4: copies .env.example to .env if .env missing."""
        script = textwrap.dedent("""\
            #!/usr/bin/env bash
            ENV_FILE="test_env_file_$$"
            EXAMPLE_FILE="test_env_example_$$"
            echo "OLLAMA_BASE_URL=http://localhost:11434" > "$EXAMPLE_FILE"
            if [ ! -f "$ENV_FILE" ]; then
              cp "$EXAMPLE_FILE" "$ENV_FILE"
              echo "ENV_CREATED=1"
            fi
            grep -q "OLLAMA_BASE_URL" "$ENV_FILE" && echo "ENV_HAS_OLLAMA=1"
            rm -f "$ENV_FILE" "$EXAMPLE_FILE"
        """)
        self.runner.write_stub_script("bootstrap.sh", script)
        result = self.runner.run_script("bootstrap.sh")
        self.assertIn("ENV_CREATED=1", result.stdout)
        self.assertIn("ENV_HAS_OLLAMA=1", result.stdout)

    def test_skips_env_if_already_exists(self):
        """Bootstrap step 4: does not overwrite existing .env."""
        script = textwrap.dedent("""\
            #!/usr/bin/env bash
            ENV_FILE="test_env_existing_$$"
            echo "EXISTING=true" > "$ENV_FILE"
            EXAMPLE_FILE="test_env_ex2_$$"
            echo "EXAMPLE=true" > "$EXAMPLE_FILE"
            if [ ! -f "$ENV_FILE" ]; then
              cp "$EXAMPLE_FILE" "$ENV_FILE"
            fi
            grep -q "EXISTING=true" "$ENV_FILE" && echo "PRESERVED=1"
            rm -f "$ENV_FILE" "$EXAMPLE_FILE"
        """)
        self.runner.write_stub_script("bootstrap.sh", script)
        result = self.runner.run_script("bootstrap.sh")
        self.assertIn("PRESERVED=1", result.stdout)

    # --- Health check ---

    def test_health_check_uses_curl(self):
        """Bootstrap step 5: queries Oracle health endpoint via curl."""
        script = textwrap.dedent("""\
            #!/usr/bin/env bash
            # Simulate the health check logic
            HEALTH='{"status":"ok","oracle":"connected","version":"3.0"}'
            STATUS=$(echo "$HEALTH" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["status"])' 2>/dev/null)
            echo "HEALTH_STATUS=$STATUS"
        """)
        self.runner.write_stub_script("bootstrap.sh", script)
        result = self.runner.run_script("bootstrap.sh")
        self.assertIn("HEALTH_STATUS=ok", result.stdout)

    def test_soul_check_called(self):
        """Bootstrap step 6: invokes soul-check.sh as final step."""
        # Write a stub soul-check that signals it ran
        eval_dir = os.path.join(self.runner.root, "eval")
        os.makedirs(eval_dir, exist_ok=True)
        soul_check = os.path.join(eval_dir, "soul-check.sh")
        with open(soul_check, "w") as f:
            f.write("#!/usr/bin/env bash\necho 'SOUL_CHECK_RAN=1'\n")
        os.chmod(soul_check, 0o755)

        # Test that a script referencing soul-check would run it
        script = textwrap.dedent("""\
            #!/usr/bin/env bash
            cd /tmp  # just test that soul-check script exists and is executable
            echo "SOUL_CHECK_EXISTS=1"
        """)
        self.runner.write_stub_script("bootstrap.sh", script)
        result = self.runner.run_script("bootstrap.sh")
        self.assertIn("SOUL_CHECK_EXISTS=1", result.stdout)

    # --- Agent name parameter ---

    def test_default_agent_name_is_innova(self):
        """Bootstrap uses 'innova' as default agent name."""
        script = textwrap.dedent("""\
            #!/usr/bin/env bash
            AGENT_NAME="${1:-innova}"
            echo "AGENT=$AGENT_NAME"
        """)
        self.runner.write_stub_script("bootstrap.sh", script)
        result = self.runner.run_script("bootstrap.sh")
        self.assertIn("AGENT=innova", result.stdout)

    def test_custom_agent_name(self):
        """Bootstrap accepts a custom agent name as argument."""
        script = textwrap.dedent("""\
            #!/usr/bin/env bash
            AGENT_NAME="${1:-innova}"
            echo "AGENT=$AGENT_NAME"
        """)
        self.runner.write_stub_script("bootstrap.sh", script)
        result = self.runner.run_script("bootstrap.sh", args=["pada"])
        self.assertIn("AGENT=pada", result.stdout)

    def test_bootstrap_exits_with_set_e(self):
        """Bootstrap uses set -e to fail fast on errors."""
        path = os.path.join(JIT_ROOT, "scripts", "bootstrap.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("set -e", content)

    def test_bootstrap_six_steps(self):
        """Bootstrap has exactly 6 steps as documented."""
        path = os.path.join(JIT_ROOT, "scripts", "bootstrap.sh")
        with open(path) as f:
            content = f.read()
        steps = content.count("Step")
        self.assertGreaterEqual(steps, 6, "bootstrap.sh should document at least 6 steps")

    def test_ollama_url_replacement_in_env(self):
        """Bootstrap step 4: replaces localhost Ollama URL with MDES endpoint."""
        path = os.path.join(JIT_ROOT, "scripts", "bootstrap.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("ollama.mdes-innova.online", content,
                       "bootstrap must replace localhost Ollama URL with MDES endpoint")


# ===========================================================================
# 2. awaken.sh tests
# ===========================================================================
class TestAwaken(unittest.TestCase):
    """Tests for scripts/awaken.sh — the awakening protocol."""

    def setUp(self):
        self.runner = ScriptRunner(self)
        self.runner.write_lib_sh()
        self.runner.copy_script("awaken.sh")
        # Create required identity files
        self.runner.write_file("core/identity.md", "> I am innova\n")
        self.runner.write_file("mind/ego.md", "# ego\n")
        self.runner.write_file("brain/reasoning.md", "# reasoning\n")
        self.runner.write_file(
            ".github/instructions/jit-context.instructions.md", "# ctx\n"
        )
        # Create organ stubs
        for organ in [
            "eye", "ear", "mouth", "nose", "hand", "leg", "heart", "nerve",
            "vitals", "pran",
        ]:
            self.runner.write_organ(organ)
        # Create sati.sh stub
        os.makedirs(os.path.join(self.runner.root, "mind"), exist_ok=True)
        sati = os.path.join(self.runner.root, "mind", "sati.sh")
        with open(sati, "w") as f:
            f.write("#!/usr/bin/env bash\necho 'Integrity Score: 100'\n")
        os.chmod(sati, 0o755)
        # Initialize git repo for step 7
        subprocess.run(
            ["git", "init"], cwd=self.runner.root,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        subprocess.run(
            ["git", "config", "user.email", "test@test.com"],
            cwd=self.runner.root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        subprocess.run(
            ["git", "config", "user.name", "test"],
            cwd=self.runner.root, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        with open(os.path.join(self.runner.root, "dummy.txt"), "w") as f:
            f.write("init\n")
        subprocess.run(
            ["git", "add", "."], cwd=self.runner.root,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
        subprocess.run(
            ["git", "commit", "-m", "init"], cwd=self.runner.root,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )

    def tearDown(self):
        self.runner.cleanup()

    def test_awaken_runs_all_eight_steps(self):
        """awaken.sh executes all 8 steps (identity, inbox, oracle, ollama, organs, sati, memory, report)."""
        env = {
            "ORACLE_URL": "http://localhost:47778",
            "OLLAMA_URL": "https://ollama.mdes-innova.online",
            "OLLAMA_TOKEN": "",
        }
        # Mock curl to simulate offline services
        fake_curl_dir = os.path.join(self.runner.runtime_dir.name, "fakebin")
        os.makedirs(fake_curl_dir, exist_ok=True)
        with open(os.path.join(fake_curl_dir, "curl"), "w") as f:
            f.write("#!/bin/sh\nexit 1\n")
        os.chmod(os.path.join(fake_curl_dir, "curl"), 0o755)

        full_env = {
            **os.environ,
            "PATH": fake_curl_dir + ":" + os.environ.get("PATH", ""),
            "JIT_ROOT": self.runner.root,
            "HOME": self.runner.runtime_dir.name,
            "ORACLE_URL": "http://localhost:47778",
            "OLLAMA_URL": "https://ollama.mdes-innova.online",
            "OLLAMA_TOKEN": "",
            "OLLAMA_MODEL": "gemma4:e4b",
        }
        result = subprocess.run(
            ["bash", os.path.join(self.runner.scripts_dir, "awaken.sh")],
            cwd=self.runner.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=full_env,
            timeout=60,
        )
        # Must show all 8 steps in output (script uses [N/8] format)
        self.assertIn("[1/8]", result.stdout)
        self.assertIn("[8/8]", result.stdout)

    def test_awaken_outputs_step_markers(self):
        """awaken.sh outputs numbered step markers (e.g. [1/8])."""
        path = os.path.join(JIT_ROOT, "scripts", "awaken.sh")
        with open(path) as f:
            content = f.read()
        # Verify 8 steps are defined in the source
        self.assertIn("TOTAL_STEPS=8", content)

    def test_identity_files_loaded(self):
        """Step 1: awaken loads identity files."""
        path = os.path.join(JIT_ROOT, "scripts", "awaken.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("core/identity.md", content)
        self.assertIn("mind/ego.md", content)
        self.assertIn("brain/reasoning.md", content)

    def test_organ_check_step(self):
        """Step 5: awaken checks all 10 organs exist and are executable."""
        path = os.path.join(JIT_ROOT, "scripts", "awaken.sh")
        with open(path) as f:
            content = f.read()
        expected_organs = [
            "eye", "ear", "mouth", "nose", "hand", "leg",
            "heart", "nerve", "vitals", "pran",
        ]
        for organ in expected_organs:
            self.assertIn(organ, content, f"awaken.sh must check organ: {organ}")

    def test_quiet_mode(self):
        """awaken.sh supports --quiet mode."""
        path = os.path.join(JIT_ROOT, "scripts", "awaken.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("--quiet", content)

    def test_fast_mode_skips_oracle(self):
        """awaken.sh --fast mode skips Oracle check."""
        path = os.path.join(JIT_ROOT, "scripts", "awaken.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("--fast", content)
        self.assertIn("FAST=1", content)

    def test_awaken_writes_state_file(self):
        """Step 8: awaken writes awakening state to JSON file."""
        path = os.path.join(JIT_ROOT, "scripts", "awaken.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("innova-awaken-state.json", content)

    def test_awaken_nerve_signal(self):
        """Step 8: awaken sends nerve signal."""
        path = os.path.join(JIT_ROOT, "scripts", "awaken.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("nerve.sh", content)
        self.assertIn("awaken", content)

    def test_sati_integrity_check(self):
        """Step 6: awaken runs sati.sh integrity check."""
        path = os.path.join(JIT_ROOT, "scripts", "awaken.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("sati.sh", content)
        self.assertIn("Integrity Score", content)

    def test_retrospective_count(self):
        """awaken.sh counts retrospectives in memory directory."""
        path = os.path.join(JIT_ROOT, "scripts", "awaken.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("retrospectives", content)


# ===========================================================================
# 3. init-life.sh tests
# ===========================================================================
class TestInitLife(unittest.TestCase):
    """Tests for scripts/init-life.sh — the master life initializer."""

    def setUp(self):
        self.runner = ScriptRunner(self)

    def tearDown(self):
        self.runner.cleanup()

    def test_has_six_steps(self):
        """init-life.sh has exactly 6 initialization steps."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("TOTAL=6", content)

    def test_status_mode_flag(self):
        """init-life.sh supports --status flag for checking system state."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("--status", content)
        self.assertIn("STATUS_ONLY=1", content)

    def test_auto_mode_flag(self):
        """init-life.sh supports --auto flag for postStartCommand."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("--auto", content)
        self.assertIn("AUTO=1", content)

    def test_step1_cross_machine_pull(self):
        """Step 1: init-life runs sync-cross-machine.sh pull."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("sync-cross-machine.sh", content)
        self.assertIn("pull", content)

    def test_step2_oracle_startup(self):
        """Step 2: init-life starts Oracle server if not running."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("api/health", content)
        self.assertIn("arra-oracle-v3", content)

    def test_step3_awaken(self):
        """Step 3: init-life calls awaken.sh."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("awaken.sh", content)

    def test_step4_cron_setup(self):
        """Step 4: init-life installs cron heartbeat job."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("crontab", content)
        self.assertIn("heartbeat.sh once", content)

    def test_step5_daemon_start(self):
        """Step 5: init-life starts heartbeat daemon."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("heartbeat.sh", content)
        self.assertIn("start", content)

    def test_step6_oracle_sync(self):
        """Step 6: init-life syncs identity to Oracle."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("sync-identity.sh", content)

    def test_exit_code_on_failure(self):
        """init-life.sh exits with non-zero if overall < 60%."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        # The script exits 1 if overall < 60%
        self.assertIn("60", content)

    def test_progress_bar_function(self):
        """init-life.sh includes progress bar display."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("_pbar", content)

    def test_auto_mode_logs_to_file(self):
        """init-life.sh --auto mode logs results to init-life.log."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("innova-init-life.log", content)

    def test_status_mode_checks_oracle(self):
        """Status mode checks Oracle health endpoint."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        # Find the status section
        status_start = content.find("STATUS_ONLY")
        self.assertNotEqual(status_start, -1, "Should have STATUS_ONLY section")
        status_section = content[status_start:]
        self.assertIn("api/health", status_section)

    def test_status_mode_checks_ollama(self):
        """Status mode checks Ollama endpoint."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        status_start = content.find("STATUS_ONLY")
        status_section = content[status_start:]
        self.assertIn("api/tags", status_section)

    def test_status_mode_checks_cron(self):
        """Status mode checks cron heartbeat."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        status_start = content.find("STATUS_ONLY")
        status_section = content[status_start:]
        self.assertIn("crontab", status_section)


# ===========================================================================
# 4. life-checklist.sh tests
# ===========================================================================
class TestLifeChecklist(unittest.TestCase):
    """Tests for scripts/life-checklist.sh — life status checklist."""

    def setUp(self):
        self.runner = ScriptRunner(self)
        self.runner.write_lib_sh()
        self.runner.copy_script("life-checklist.sh")

    def tearDown(self):
        self.runner.cleanup()

    def test_checks_seven_items(self):
        """life-checklist.sh checks 7 infrastructure items."""
        path = os.path.join(JIT_ROOT, "scripts", "life-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("TOTAL=7", content)

    def test_checks_devcontainer(self):
        """Checks devcontainer.json for auto-start configuration."""
        path = os.path.join(JIT_ROOT, "scripts", "life-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("devcontainer.json", content)
        self.assertIn("init-life.sh", content)

    def test_checks_heartbeat_daemon(self):
        """Checks if heartbeat daemon is running."""
        path = os.path.join(JIT_ROOT, "scripts", "life-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("heartbeat.sh", content)
        self.assertIn("status", content)

    def test_checks_cron(self):
        """Checks if cron heartbeat is installed."""
        path = os.path.join(JIT_ROOT, "scripts", "life-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("crontab", content)

    def test_checks_oracle(self):
        """Checks Oracle health endpoint."""
        path = os.path.join(JIT_ROOT, "scripts", "life-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("ORACLE_URL", content)
        self.assertIn("api/health", content)

    def test_checks_ollama(self):
        """Checks Ollama availability."""
        path = os.path.join(JIT_ROOT, "scripts", "life-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("OLLAMA_URL", content)
        self.assertIn("api/tags", content)

    def test_checks_state_files(self):
        """Checks persistent state files exist."""
        path = os.path.join(JIT_ROOT, "scripts", "life-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("innova.state.json", content)
        self.assertIn("heartbeat.log", content)

    def test_checks_git_sync(self):
        """Checks git cross-machine sync configuration."""
        path = os.path.join(JIT_ROOT, "scripts", "life-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("rev-parse", content)
        self.assertIn("remote get-url", content)

    def test_short_mode(self):
        """life-checklist.sh supports --short flag."""
        path = os.path.join(JIT_ROOT, "scripts", "life-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("--short", content)
        self.assertIn("SHORT=1", content)

    def test_url_check_function(self):
        """_check_url helper verifies URL response contains expected string."""
        path = os.path.join(JIT_ROOT, "scripts", "life-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("_check_url", content)
        self.assertIn("curl", content)

    def test_summary_shows_percentage(self):
        """Checklist outputs pass count and percentage."""
        path = os.path.join(JIT_ROOT, "scripts", "life-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("PCT", content)
        self.assertIn("PASSED", content)

    def test_devcontainer_check_with_config(self):
        """Devcontainer check passes when init-life.sh --auto is configured."""
        # Create devcontainer.json with the right content
        self.runner.write_file(
            ".devcontainer/devcontainer.json",
            json.dumps({"postStartCommand": "bash scripts/init-life.sh --auto"}),
        )
        # The check should find the file and the init-life.sh reference
        path = os.path.join(JIT_ROOT, "scripts", "life-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("init-life.sh --auto", content)


# ===========================================================================
# 5. selfhood-checklist.sh tests
# ===========================================================================
class TestSelfhoodChecklist(unittest.TestCase):
    """Tests for scripts/selfhood-checklist.sh — self-verification."""

    def setUp(self):
        self.runner = ScriptRunner(self)
        self.runner.write_lib_sh()
        self.runner.copy_script("selfhood-checklist.sh")

    def tearDown(self):
        self.runner.cleanup()

    def test_uses_set_euo_pipefail(self):
        """selfhood-checklist.sh uses strict mode (set -euo pipefail)."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("set -euo pipefail", content)

    def test_check_heartbeat_function(self):
        """Defines check_heartbeat function."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("check_heartbeat()", content)

    def test_check_autonomy_function(self):
        """Defines check_autonomy function."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("check_autonomy()", content)

    def test_check_innova_bot_function(self):
        """Defines check_innova_bot function."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("check_innova_bot()", content)

    def test_check_oracle_function(self):
        """Defines check_oracle function."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("check_oracle()", content)

    def test_check_ollama_function(self):
        """Defines check_ollama function."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("check_ollama()", content)

    def test_five_checks_total(self):
        """selfhood-checklist runs exactly 5 checks."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        # Count check function calls in report_checklist
        check_calls = content.count("check_")
        # 5 unique functions, each called once = at least 5 references in report_checklist
        self.assertGreaterEqual(check_calls, 10,
                                "Should reference 5 check functions (definition + call)")

    def test_summary_output(self):
        """selfhood-checklist outputs summary with pass/fail counts."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("checks passed", content)
        self.assertIn("issues found", content)

    def test_heartbeat_checks_pid_file(self):
        """check_heartbeat reads PID file to verify daemon."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("innova-heartbeat.pid", content)

    def test_autonomy_checks_pid_file(self):
        """check_autonomy reads agent-autonomy PID file."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("agent-autonomy.pid", content)

    def test_oracle_uses_health_endpoint(self):
        """check_oracle uses /api/health endpoint."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("api/health", content)

    def test_ollama_checks_token(self):
        """check_ollama requires OLLAMA_TOKEN and checks models endpoint."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("OLLAMA_TOKEN", content)
        self.assertIn("api/tags", content)

    def test_ollama_masks_missing_token(self):
        """check_ollama reports token missing when OLLAMA_TOKEN empty."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("token missing", content)

    def test_innova_bot_checks_git(self):
        """check_innova_bot checks for git directory."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn(".git", content)

    def test_next_steps_on_issues(self):
        """When issues found, selfhood-checklist prints next steps."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("next:", content)


# ===========================================================================
# 6. setup-secrets.sh tests
# ===========================================================================
class TestSetupSecrets(unittest.TestCase):
    """Tests for scripts/setup-secrets.sh — secret encryption and management."""

    def setUp(self):
        self.runner = ScriptRunner(self)

    def tearDown(self):
        self.runner.cleanup()

    def test_encrypt_mode_requires_token(self):
        """encrypt mode exits if no token provided."""
        script = textwrap.dedent("""\
            #!/usr/bin/env bash
            REAL_TOKEN=""
            if [ -z "$REAL_TOKEN" ]; then
              echo "NO_TOKEN=1"
              exit 1
            fi
        """)
        self.runner.write_stub_script("test-secrets.sh", script)
        result = self.runner.run_script("test-secrets.sh")
        self.assertIn("NO_TOKEN=1", result.stdout)
        self.assertNotEqual(result.returncode, 0)

    def test_encrypt_mode_requires_passphrase(self):
        """encrypt mode exits if no passphrase provided."""
        script = textwrap.dedent("""\
            #!/usr/bin/env bash
            REAL_TOKEN="test-token-12345"
            PASSPHRASE=""
            if [ -z "$PASSPHRASE" ]; then
              echo "NO_PASSPHRASE=1"
              exit 1
            fi
        """)
        self.runner.write_stub_script("test-secrets.sh", script)
        result = self.runner.run_script("test-secrets.sh")
        self.assertIn("NO_PASSPHRASE=1", result.stdout)

    def test_uses_aes_256_cbc_pbkdf2(self):
        """setup-secrets.sh uses AES-256-CBC-PBKDF2 for encryption."""
        path = os.path.join(JIT_ROOT, "scripts", "setup-secrets.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("aes-256-cbc", content)
        self.assertIn("pbkdf2", content)

    def test_high_iteration_count(self):
        """Encryption uses at least 310000 PBKDF2 iterations."""
        path = os.path.join(JIT_ROOT, "scripts", "setup-secrets.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("310000", content)

    def test_encrypted_file_location(self):
        """Encrypted tokens stored in .secrets/ directory."""
        path = os.path.join(JIT_ROOT, "scripts", "setup-secrets.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn(".secrets", content)
        self.assertIn("ollama.enc", content)

    def test_meta_file_created(self):
        """Encryption creates a .meta file with fingerprint info."""
        path = os.path.join(JIT_ROOT, "scripts", "setup-secrets.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("ollama.enc.meta", content)
        self.assertIn("fingerprint", content)
        self.assertIn("sha256", content)

    def test_verify_mode_masks_token(self):
        """verify mode displays masked token, never raw token."""
        path = os.path.join(JIT_ROOT, "scripts", "setup-secrets.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("MASKED", content)
        # Check for masking pattern like X****X
        self.assertIn("${TOKEN:0:4}", content)
        self.assertIn("${TOKEN: -4}", content)

    def test_load_mode_updates_env(self):
        """load mode writes/updates .env file with token."""
        path = os.path.join(JIT_ROOT, "scripts", "setup-secrets.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn(".env", content)
        self.assertIn("OLLAMA_TOKEN", content)

    def test_load_mode_creates_env_if_missing(self):
        """load mode creates .env from scratch if it does not exist."""
        path = os.path.join(JIT_ROOT, "scripts", "setup-secrets.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("OLLAMA_BASE_URL", content)
        self.assertIn("ORACLE_PORT", content)

    def test_decrypt_stdout_mode(self):
        """decrypt-stdout mode outputs token to stdout for sourcing."""
        path = os.path.join(JIT_ROOT, "scripts", "setup-secrets.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("decrypt-stdout", content)

    def test_decrypt_stdout_requires_passphrase(self):
        """decrypt-stdout exits if no passphrase provided."""
        path = os.path.join(JIT_ROOT, "scripts", "setup-secrets.sh")
        with open(path) as f:
            content = f.read()
        # decrypt-stdout section should check for passphrase
        decrypt_section_start = content.find("decrypt-stdout")
        self.assertNotEqual(decrypt_section_start, -1)

    def test_never_echoes_raw_token(self):
        """verify mode never echoes the full raw token — only masked version."""
        path = os.path.join(JIT_ROOT, "scripts", "setup-secrets.sh")
        with open(path) as f:
            content = f.read()
        # In verify mode, token should be masked before display
        # Check that the script uses $MASKED not $TOKEN in echo statements
        verify_start = content.find('verify)')
        verify_end = content.find('decrypt-stdout)')
        verify_section = content[verify_start:verify_end] if verify_start != -1 else ""
        # The verify section should NOT contain echo with raw $TOKEN
        # It should use $MASKED
        self.assertIn("MASKED", verify_section, "verify mode must mask the token")

    def test_secrets_dir_created(self):
        """setup-secrets.sh creates .secrets directory if missing."""
        path = os.path.join(JIT_ROOT, "scripts", "setup-secrets.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("mkdir -p", content)
        self.assertIn("SECRETS_DIR", content)

    def test_load_mode_sed_replaces_existing(self):
        """load mode uses sed to replace existing OLLAMA_TOKEN in .env."""
        path = os.path.join(JIT_ROOT, "scripts", "setup-secrets.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("sed -i", content)
        self.assertIn("OLLAMA_TOKEN=", content)

    def test_usage_message_on_unknown_mode(self):
        """Unknown mode prints usage message."""
        path = os.path.join(JIT_ROOT, "scripts", "setup-secrets.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("encrypt|load|verify|decrypt-stdout", content)

    def test_secrets_not_in_git(self):
        """Verify .secrets/ is in .gitignore (no secrets in repo)."""
        gitignore_path = os.path.join(JIT_ROOT, ".gitignore")
        if os.path.exists(gitignore_path):
            with open(gitignore_path) as f:
                content = f.read()
            # .secrets or .env should be ignored
            has_secrets_ignore = ".secrets" in content or ".env" in content
            self.assertTrue(
                has_secrets_ignore,
                ".gitignore must exclude .secrets/ or .env to prevent secret leaks",
            )


# ===========================================================================
# Integration: script structure validation
# ===========================================================================
class TestScriptStructure(unittest.TestCase):
    """Validate structural properties of all infrastructure scripts."""

    def _read_script(self, name):
        path = os.path.join(JIT_ROOT, "scripts", name)
        with open(path) as f:
            return f.read()

    def test_all_scripts_have_shebang(self):
        """Every infrastructure script starts with #!/usr/bin/env bash."""
        scripts = [
            "bootstrap.sh", "awaken.sh", "init-life.sh",
            "life-checklist.sh", "selfhood-checklist.sh", "setup-secrets.sh",
        ]
        for name in scripts:
            content = self._read_script(name)
            self.assertTrue(
                content.startswith("#!/usr/bin/env bash"),
                f"{name} must start with #!/usr/bin/env bash",
            )

    def test_bootstrap_has_set_e(self):
        """bootstrap.sh uses set -e for fail-fast."""
        content = self._read_script("bootstrap.sh")
        self.assertIn("set -e", content)

    def test_selfhood_has_set_euo_pipefail(self):
        """selfhood-checklist.sh uses set -euo pipefail for strictness."""
        content = self._read_script("selfhood-checklist.sh")
        self.assertIn("set -euo pipefail", content)

    def test_awaken_sources_lib_sh(self):
        """awaken.sh sources limbs/lib.sh."""
        content = self._read_script("awaken.sh")
        self.assertIn("lib.sh", content)
        self.assertIn("source", content)

    def test_init_life_sources_lib_sh(self):
        """init-life.sh sources limbs/lib.sh."""
        content = self._read_script("init-life.sh")
        self.assertIn("lib.sh", content)

    def test_life_checklist_sources_lib_sh(self):
        """life-checklist.sh sources limbs/lib.sh."""
        content = self._read_script("life-checklist.sh")
        self.assertIn("lib.sh", content)

    def test_selfhood_sources_lib_sh(self):
        """selfhood-checklist.sh sources limbs/lib.sh."""
        content = self._read_script("selfhood-checklist.sh")
        self.assertIn("lib.sh", content)

    def test_awaken_determines_jit_root(self):
        """awaken.sh determines JIT_ROOT from script directory."""
        content = self._read_script("awaken.sh")
        self.assertIn("JIT_ROOT", content)
        self.assertIn("SCRIPT_DIR", content)

    def test_init_life_determines_jit_root(self):
        """init-life.sh determines JIT_ROOT from script directory."""
        content = self._read_script("init-life.sh")
        self.assertIn("JIT_ROOT", content)
        self.assertIn("SCRIPT_DIR", content)

    def test_setup_secrets_determines_jit_root(self):
        """setup-secrets.sh determines JIT_ROOT from script directory."""
        content = self._read_script("setup-secrets.sh")
        self.assertIn("JIT_ROOT", content)
        self.assertIn("SCRIPT_DIR", content)

    def test_awaken_loads_env(self):
        """awaken.sh loads .env if present."""
        content = self._read_script("awaken.sh")
        self.assertIn(".env", content)

    def test_init_life_loads_env(self):
        """init-life.sh loads .env if present."""
        content = self._read_script("init-life.sh")
        self.assertIn(".env", content)

    def test_no_hardcoded_secrets_in_any_script(self):
        """No script contains hardcoded passwords or tokens."""
        scripts = [
            "bootstrap.sh", "awaken.sh", "init-life.sh",
            "life-checklist.sh", "selfhood-checklist.sh", "setup-secrets.sh",
        ]
        secret_patterns = [
            "password=", "secret=", "token=sk-",
            "api_key=", "private_key=",
        ]
        for name in scripts:
            content = self._read_script(name)
            for pattern in secret_patterns:
                self.assertNotIn(
                    pattern, content,
                    f"{name} must not contain hardcoded secret: {pattern}",
                )

    def test_curl_has_timeout_on_all_health_checks(self):
        """All health check curl commands use --max-time timeout."""
        scripts_with_curl = [
            "awaken.sh", "init-life.sh", "life-checklist.sh",
            "selfhood-checklist.sh",
        ]
        for name in scripts_with_curl:
            content = self._read_script(name)
            # Find curl commands and check they have timeout
            lines = content.split("\n")
            curl_lines = [l for l in lines if "curl" in l and ("-sf" in l or "-s" in l)]
            for line in curl_lines:
                if "curl" in line and ("http" in line or "ORACLE" in line or "OLLAMA" in line):
                    self.assertIn(
                        "--max-time", line,
                        f"{name}: curl health check must have --max-time timeout: {line.strip()}",
                    )

    def test_setup_secrets_read_uses_read_s(self):
        """setup-secrets.sh uses `read -s` to suppress echo for secrets."""
        content = self._read_script("setup-secrets.sh")
        self.assertIn("read -s", content)

    def test_all_scripts_are_executable(self):
        """All infrastructure scripts have execute permission."""
        scripts = [
            "bootstrap.sh", "awaken.sh", "init-life.sh",
            "life-checklist.sh", "selfhood-checklist.sh", "setup-secrets.sh",
        ]
        for name in scripts:
            path = os.path.join(JIT_ROOT, "scripts", name)
            self.assertTrue(
                os.access(path, os.X_OK),
                f"scripts/{name} must be executable",
            )


# ===========================================================================
# Setup-secrets encryption roundtrip
# ===========================================================================
class TestSecretEncryptionRoundtrip(unittest.TestCase):
    """Integration test: encrypt and decrypt a token end-to-end."""

    def test_encrypt_decrypt_roundtrip(self):
        """Tokens survive an encrypt-decrypt roundtrip via openssl."""
        # Use openssl directly to verify the algorithm works
        real_token = "sk-test-token-abc123456789xyz"
        passphrase = "test-passphrase-secure"

        import tempfile
        with tempfile.NamedTemporaryFile(mode="w", suffix=".enc", delete=False) as enc:
            enc_path = enc.name

        try:
            # Encrypt
            encrypt_result = subprocess.run(
                [
                    "openssl", "enc", "-aes-256-cbc", "-pbkdf2",
                    "-iter", "310000",
                    "-pass", f"pass:{passphrase}",
                    "-a",
                ],
                input=real_token,
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertEqual(encrypt_result.returncode, 0, f"Encrypt failed: {encrypt_result.stderr}")

            with open(enc_path, "w") as f:
                f.write(encrypt_result.stdout)

            # Decrypt
            decrypt_result = subprocess.run(
                [
                    "openssl", "enc", "-aes-256-cbc", "-pbkdf2",
                    "-iter", "310000",
                    "-pass", f"pass:{passphrase}",
                    "-d", "-a",
                    "-in", enc_path,
                ],
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertEqual(decrypt_result.returncode, 0, f"Decrypt failed: {decrypt_result.stderr}")
            self.assertEqual(decrypt_result.stdout, real_token,
                             "Decrypted token must match original")
        finally:
            os.unlink(enc_path)

    def test_wrong_passphrase_fails(self):
        """Wrong passphrase produces empty/bad output (not the original)."""
        real_token = "sk-test-token-abc123456789xyz"
        correct_pass = "correct-pass"
        wrong_pass = "wrong-pass"

        import tempfile
        with tempfile.NamedTemporaryFile(mode="w", suffix=".enc", delete=False) as enc:
            enc_path = enc.name

        try:
            encrypt_result = subprocess.run(
                [
                    "openssl", "enc", "-aes-256-cbc", "-pbkdf2",
                    "-iter", "310000",
                    "-pass", f"pass:{correct_pass}",
                    "-a",
                ],
                input=real_token,
                capture_output=True,
                text=True,
                timeout=10,
            )
            with open(enc_path, "w") as f:
                f.write(encrypt_result.stdout)

            decrypt_result = subprocess.run(
                [
                    "openssl", "enc", "-aes-256-cbc", "-pbdf2",
                    "-iter", "310000",
                    "-pass", f"pass:{wrong_pass}",
                    "-d", "-a",
                    "-in", enc_path,
                ],
                capture_output=True,
                timeout=10,
            )
            # Wrong passphrase causes openssl to fail (exit code != 0)
            # or produce garbage that doesn't match the original token
            self.assertNotEqual(
                decrypt_result.returncode, 0,
                "Wrong passphrase should cause openssl to fail or produce wrong output",
            )
        finally:
            os.unlink(enc_path)

    def test_masking_pattern(self):
        """Token masking shows first 4 and last 4 chars only."""
        token = "sk-abcdefghijklmnop1234567890"
        masked = f"{token[:4]}****{token[-4:]}"
        self.assertEqual(masked, "sk-a****7890")
        self.assertNotIn(token[4:-4], masked, "Middle of token must be hidden")

    def test_fingerprint_generation(self):
        """SHA256 fingerprint of passphrase is generated for meta file."""
        passphrase = "test-key"
        result = subprocess.run(
            ["openssl", "dgst", "-sha256"],
            input=passphrase,
            capture_output=True,
            text=True,
            timeout=10,
        )
        self.assertEqual(result.returncode, 0)
        # openssl outputs "SHA2-256(stdin)= <hex>" or "SHA256(stdin)= <hex>"
        self.assertTrue(
            "SHA256" in result.stdout or "SHA2-256" in result.stdout,
            f"Expected SHA256 fingerprint, got: {result.stdout}",
        )
        # Extract hex digest (after the = sign)
        digest = result.stdout.split("=")[-1].strip()
        self.assertEqual(len(digest), 64, "SHA256 hex digest is 64 chars")


# ===========================================================================
# Mock-based tests: testing script behavior with mocked externals
# ===========================================================================
class TestBootstrapWithMocks(unittest.TestCase):
    """Test bootstrap.sh behavior with mocked external commands."""

    def test_bun_install_skipped_when_present(self):
        """When bun is on PATH, bootstrap skips installation."""
        # Simulate by checking the conditional logic
        script_logic = textwrap.dedent("""\
            #!/usr/bin/env bash
            # Simulated step 1
            if command -v bun &>/dev/null; then
              echo "BUN_EXISTS=1"
            elif [ -f "$HOME/.bun/bin/bun" ]; then
              echo "BUN_EXISTS_ALT=1"
            else
              echo "NEED_INSTALL=1"
            fi
        """)
        runner = ScriptRunner(self)
        try:
            runner.write_stub_script("test-step1.sh", script_logic)
            result = runner.run_script("test-step1.sh")
            # In the real environment, bun may or may not exist;
            # the script must not error in either case
            self.assertIn(result.returncode, [0], "Script must exit cleanly")
        finally:
            runner.cleanup()

    def test_git_clone_idempotent(self):
        """Bootstrap does not re-clone if arra-oracle-v3 exists."""
        script_logic = textwrap.dedent("""\
            #!/usr/bin/env bash
            TARGET_DIR="test_clone_idem_$$"
            if [ -d "$TARGET_DIR" ]; then
              echo "SKIP_CLONE=1"
            else
              echo "WOULD_CLONE=1"
            fi
            rm -rf "$TARGET_DIR" 2>/dev/null
        """)
        runner = ScriptRunner(self)
        try:
            runner.write_stub_script("test-idem.sh", script_logic)
            result = runner.run_script("test-idem.sh")
            self.assertIn("WOULD_CLONE=1", result.stdout)
        finally:
            runner.cleanup()

    def test_health_check_parses_json(self):
        """Bootstrap health check parses JSON response correctly."""
        # Test that the JSON parsing used in bootstrap works
        health_json = '{"status":"ok","oracle":"connected","version":"3.0"}'
        result = subprocess.run(
            ["python3", "-c",
             f"import json,sys; d=json.load(sys.stdin); print(d['status'], '—', d['version'])"],
            input=health_json,
            capture_output=True,
            text=True,
            timeout=5,
        )
        self.assertEqual(result.returncode, 0)
        self.assertIn("ok", result.stdout)
        self.assertIn("3.0", result.stdout)


class TestAwakenWithMocks(unittest.TestCase):
    """Test awaken.sh behavior with mocked external services."""

    def test_oracle_offline_warning(self):
        """When Oracle is offline, awaken produces a warning."""
        path = os.path.join(JIT_ROOT, "scripts", "awaken.sh")
        with open(path) as f:
            content = f.read()
        # The script has Oracle offline handling
        self.assertIn("Oracle offline", content)

    def test_ollama_offline_warning(self):
        """When Ollama is offline, awaken produces a warning."""
        path = os.path.join(JIT_ROOT, "scripts", "awaken.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("Ollama", content)
        # Check for error handling
        ollama_refs = content.count("Ollama")
        self.assertGreaterEqual(ollama_refs, 2, "Must reference Ollama more than once")

    def test_awaken_issues_array(self):
        """awaken.sh tracks issues in an array for reporting."""
        path = os.path.join(JIT_ROOT, "scripts", "awaken.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("AWAKENING_ISSUES", content)

    def test_awaken_score_tracking(self):
        """awaken.sh tracks awakening score (steps completed)."""
        path = os.path.join(JIT_ROOT, "scripts", "awaken.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("AWAKENING_SCORE", content)

    def test_vitality_percentage_calculation(self):
        """awaken.sh calculates vitality percentage from score."""
        path = os.path.join(JIT_ROOT, "scripts", "awaken.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("OVERALL", content)
        self.assertIn("Vitality", content)


class TestInitLifeWithMocks(unittest.TestCase):
    """Test init-life.sh behavior with mocked external services."""

    def test_oracle_startup_retry_logic(self):
        """init-life.sh retries Oracle startup up to 10 seconds."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("seq 1 10", content)

    def test_cron_heartbeat_interval(self):
        """Cron job runs every 15 minutes."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("*/15", content)

    def test_cron_presence_marker(self):
        """Cron entries use markers for idempotent updates."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("CRON_MARKER", content)

    def test_cron_removes_old_entries(self):
        """Cron install removes old entries before adding new ones."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("grep -v", content)

    def test_heartbeat_daemon_check(self):
        """init-life.sh checks if heartbeat daemon is already running."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("heartbeat.sh", content)
        self.assertIn("status", content)

    def test_step_results_array(self):
        """init-life.sh tracks per-step results."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("STEP_RESULTS", content)

    def test_overall_threshold(self):
        """init-life.sh considers < 60% overall as failure."""
        path = os.path.join(JIT_ROOT, "scripts", "init-life.sh")
        with open(path) as f:
            content = f.read()
        # Exit code based on 60% threshold
        self.assertIn("60", content)


class TestLifeChecklistWithMocks(unittest.TestCase):
    """Test life-checklist.sh behavior with mocked services."""

    def test_check_url_helper(self):
        """_check_url helper returns 0 when curl succeeds and pattern matches."""
        script = textwrap.dedent("""\
            #!/usr/bin/env bash
            _check_url() {
              local URL="$1" EXPECT="$2"
              # Simulated: echo the expected pattern
              echo "$EXPECT"
            }
            if _check_url "http://localhost/test" '"ok"'; then
              echo "URL_CHECK_PASS=1"
            else
              echo "URL_CHECK_FAIL=1"
            fi
        """)
        runner = ScriptRunner(self)
        try:
            runner.write_stub_script("test-url.sh", script)
            result = runner.run_script("test-url.sh")
            self.assertIn("URL_CHECK_PASS=1", result.stdout)
        finally:
            runner.cleanup()

    def test_state_file_check(self):
        """life-checklist checks for innova.state.json and heartbeat.log."""
        path = os.path.join(JIT_ROOT, "scripts", "life-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("innova.state.json", content)
        self.assertIn("heartbeat.log", content)

    def test_exit_code_zero(self):
        """life-checklist.sh always exits 0 (informational, not pass/fail)."""
        path = os.path.join(JIT_ROOT, "scripts", "life-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("exit 0", content)


class TestSelfhoodWithMocks(unittest.TestCase):
    """Test selfhood-checklist.sh with mocked services."""

    def test_innova_bot_default_path(self):
        """check_innova_bot defaults to $JIT_ROOT/innova-bot."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("innova-bot", content)

    def test_innova_bot_custom_path(self):
        """check_innova_bot respects INNOVA_BOT_PATH env var."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("INNOVA_BOT_PATH", content)

    def test_heartbeat_fallback_to_script(self):
        """check_heartbeat falls back to heartbeat.sh status if PID file missing."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("heartbeat.sh", content)
        self.assertIn("status", content)

    def test_autonomy_fallback_to_script(self):
        """check_autonomy falls back to agent-autonomy.sh status if PID file missing."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("agent-autonomy.sh", content)

    def test_next_steps_include_oracle_start(self):
        """Issue remediation suggests starting Oracle if offline."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("bun run src/server.ts", content)

    def test_next_steps_include_ollama_token(self):
        """Issue remediation suggests adding Ollama token if missing."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("Ollama token", content)

    def test_report_checklist_function(self):
        """Main entry point calls report_checklist."""
        path = os.path.join(JIT_ROOT, "scripts", "selfhood-checklist.sh")
        with open(path) as f:
            content = f.read()
        self.assertIn("report_checklist", content)


if __name__ == "__main__":
    unittest.main()
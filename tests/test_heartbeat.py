import os
import shutil
import subprocess
import tempfile
import textwrap
import unittest

class HeartbeatScriptTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.runtime_dir = tempfile.TemporaryDirectory()
        self.root = self.tmpdir.name
        os.makedirs(os.path.join(self.root, 'scripts'), exist_ok=True)
        os.makedirs(os.path.join(self.root, 'limbs'), exist_ok=True)
        os.makedirs(os.path.join(self.root, 'organs'), exist_ok=True)
        os.makedirs(os.path.join(self.root, 'network'), exist_ok=True)
        os.makedirs(os.path.join(self.root, 'memory', 'state'), exist_ok=True)

        shutil.copy(
            os.path.join(os.getcwd(), 'scripts', 'heartbeat.sh'),
            os.path.join(self.root, 'scripts', 'heartbeat.sh'),
        )

        with open(os.path.join(self.root, 'limbs', 'lib.sh'), 'w') as f:
            f.write(textwrap.dedent('''\
                #!/usr/bin/env bash
                GREEN=''
                CYAN=''
                RESET=''
                log_action() { :; }
                oracle_ready() { return 1; }
            '''))
        with open(os.path.join(self.root, 'scripts', 'sync-cross-machine.sh'), 'w') as f:
            f.write('#!/usr/bin/env bash\necho "skip sync"\n')
        with open(os.path.join(self.root, 'scripts', 'multi-remote.sh'), 'w') as f:
            f.write('#!/usr/bin/env bash\necho "skip"\n')
        with open(os.path.join(self.root, 'organs', 'heart.sh'), 'w') as f:
            f.write('#!/usr/bin/env bash\nexit 0\n')
        with open(os.path.join(self.root, 'network', 'bus.sh'), 'w') as f:
            f.write(textwrap.dedent('''\
                #!/usr/bin/env bash
                case "$1" in
                  broadcast) exit 0 ;; 
                  send) exit 0 ;; 
                  *) exit 0 ;; 
                esac
            '''))
        with open(os.path.join(self.root, '.gitignore'), 'w') as f:
            f.write('memory/state/innova.state.json\nmemory/state/heartbeat.log\n')

        # Make all scripts executable
        for path in [
            os.path.join(self.root, 'scripts', 'heartbeat.sh'),
            os.path.join(self.root, 'scripts', 'sync-cross-machine.sh'),
            os.path.join(self.root, 'scripts', 'multi-remote.sh'),
            os.path.join(self.root, 'organs', 'heart.sh'),
            os.path.join(self.root, 'network', 'bus.sh'),
            os.path.join(self.root, 'limbs', 'lib.sh'),
        ]:
            os.chmod(path, 0o755)

        # Initialize git repository
        subprocess.run(['git', 'init'], cwd=self.root, check=True, stdout=subprocess.DEVNULL)
        subprocess.run(['git', 'config', 'user.email', 'test@example.com'], cwd=self.root, check=True)
        subprocess.run(['git', 'config', 'user.name', 'test'], cwd=self.root, check=True)

        with open(os.path.join(self.root, 'dummy.txt'), 'w') as f:
            f.write('hello\n')
        subprocess.run(['git', 'add', '.'], cwd=self.root, check=True)
        subprocess.run(['git', 'commit', '-m', 'initial'], cwd=self.root, check=True, stdout=subprocess.DEVNULL)

        host = subprocess.run(['hostname'], cwd=self.root, stdout=subprocess.PIPE, text=True).stdout.strip()
        with open(os.path.join(self.root, 'memory', 'state', 'innova.state.json'), 'w') as f:
            f.write(f'{{"vitality": {{"host": "{host}", "pulse_count": 0}}}}')

    def tearDown(self):
        self.tmpdir.cleanup()
        self.runtime_dir.cleanup()

    def run_heartbeat(self, args=None):
        args = args or ['once']
        env = {
            **os.environ,
            'PATH': os.environ.get('PATH', ''),
            'BUS_ROOT': os.path.join(self.runtime_dir.name, 'manusat-bus'),
            'PID_FILE': os.path.join(self.runtime_dir.name, 'heartbeat.pid'),
            'LOG_FILE': os.path.join(self.runtime_dir.name, 'heartbeat.log'),
            'LAST_ACTIVITY_FILE': os.path.join(self.runtime_dir.name, 'heartbeat.lastactive'),
        }
        os.makedirs(env['BUS_ROOT'], exist_ok=True)
        result = subprocess.run(
            ['bash', 'scripts/heartbeat.sh'] + args,
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            env=env,
        )
        return result

    def test_local_only_on_no_changes(self):
        # Heartbeat writes local state only — no git commit, even when nothing changed.
        result = self.run_heartbeat(['once'])
        self.assertIn('local-only', result.stdout)
        self.assertIn('no git commit', result.stdout)
        status = subprocess.run(['git', 'status', '--porcelain'], cwd=self.root, stdout=subprocess.PIPE, text=True)
        self.assertEqual(status.stdout.strip(), '')  # git tree stays clean

    def test_no_commit_when_code_changed(self):
        # Architecture rule: heartbeat never commits to git.
        # Source commits require explicit milestone commands.
        with open(os.path.join(self.root, 'dummy.txt'), 'a') as f:
            f.write('change\n')
        result = self.run_heartbeat(['once'])
        self.assertIn('local-only', result.stdout)
        # git log must still show only the initial commit (no heartbeat commit added)
        log = subprocess.run(['git', 'log', '--oneline'], cwd=self.root, stdout=subprocess.PIPE, text=True)
        self.assertEqual(len(log.stdout.strip().splitlines()), 1, 'heartbeat must not add git commits')
        # the change must still be pending (not staged or committed)
        status = subprocess.run(['git', 'status', '--porcelain'], cwd=self.root, stdout=subprocess.PIPE, text=True)
        self.assertIn('dummy.txt', status.stdout)

    def test_status_shows_stopped_when_no_daemon(self):
        result = self.run_heartbeat(['status'])
        self.assertIn('Heartbeat ไม่ได้รัน', result.stdout)

if __name__ == '__main__':
    unittest.main()

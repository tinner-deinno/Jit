import os
import shutil
import subprocess
import tempfile
import textwrap
import unittest

class HeartLungIntegrationTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.root = self.tmpdir.name
        os.makedirs(os.path.join(self.root, 'organs'), exist_ok=True)
        os.makedirs(os.path.join(self.root, 'network'), exist_ok=True)
        os.makedirs(os.path.join(self.root, 'limbs'), exist_ok=True)

        shutil.copy(
            os.path.join(os.getcwd(), 'organs', 'heart.sh'),
            os.path.join(self.root, 'organs', 'heart.sh'),
        )
        shutil.copy(
            os.path.join(os.getcwd(), 'organs', 'lung.sh'),
            os.path.join(self.root, 'organs', 'lung.sh'),
        )
        with open(os.path.join(self.root, 'network', 'bus.sh'), 'w') as f:
            f.write('#!/usr/bin/env bash\ncase "$1" in broadcast) exit 0 ;; send) exit 0 ;; *) exit 0 ;; esac\n')
        with open(os.path.join(self.root, 'limbs', 'lib.sh'), 'w') as f:
            f.write(textwrap.dedent('''\
                #!/usr/bin/env bash
                GREEN=''
                RED=''
                RESET=''
                BOLD=''
                ok() { :; }
                warn() { :; }
                log_action() { :; }
                oracle_ready() { return 1; }
            '''))

        for path in [
            os.path.join(self.root, 'organs', 'heart.sh'),
            os.path.join(self.root, 'organs', 'lung.sh'),
            os.path.join(self.root, 'network', 'bus.sh'),
            os.path.join(self.root, 'limbs', 'lib.sh'),
        ]:
            os.chmod(path, 0o755)

    def tearDown(self):
        self.tmpdir.cleanup()

    def test_heart_pulse_triggers_lung_filter(self):
        result = subprocess.run(
            ['bash', 'organs/heart.sh', 'beat', 'cycle'],
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        self.assertIn('->💓', result.stdout)
        self.assertIn('❤️‍🔥->', result.stdout)

    def test_lung_filter_output(self):
        result = subprocess.run(
            ['bash', 'organs/lung.sh', 'filter', '{"total_pending": 1, "note": "test"}'],
            cwd=self.root,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
        )
        self.assertIn('"clean_status": "high"', result.stdout)

if __name__ == '__main__':
    unittest.main()

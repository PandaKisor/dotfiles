#!/usr/bin/env python3
"""Exercise compositor selection and lifecycle without contacting a display."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'home/.config/i3/start-picom.sh'


class CompositorTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='compositor-test-')
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bin = self.root / 'bin'
        self.config = self.root / 'config'
        for directory in (self.bin, self.config / 'i3', self.config / 'picom',
                          self.root / 'runtime'):
            directory.mkdir(parents=True)
        for name in ('bash', 'mkdir', 'flock', 'sleep'):
            (self.bin / name).symlink_to(shutil.which(name))
        self.env = dict(os.environ, PATH=str(self.bin), TEST_ROOT=str(self.root),
                        XDG_CONFIG_HOME=str(self.config), DISPLAY=':test',
                        XDG_STATE_HOME=str(self.root / 'state'),
                        XDG_RUNTIME_DIR=str(self.root / 'runtime'))
        for name in ('BASH_ENV', 'COMPOSITOR_MODE'):
            self.env.pop(name, None)
        self.stub('pgrep', 'exit 1')
        self.stub('systemd-detect-virt', 'exit "${TEST_VM:-1}"')
        self.stub('picom', 'printf "picom %s\\n" "$*" >> "$TEST_ROOT/calls"\nexit "${TEST_PICOM_EXIT:-0}"')
        self.stub('xcompmgr', 'printf "xcompmgr %s\\n" "$*" >> "$TEST_ROOT/calls"')

    def stub(self, name, body):
        path = self.bin / name
        path.write_text('#!/usr/bin/env bash\n' + body + '\n')
        path.chmod(0o755)

    def run_script(self):
        return subprocess.run([str(SCRIPT)], env=self.env, capture_output=True,
                              text=True, timeout=5)

    def calls(self):
        path = self.root / 'calls'
        return path.read_text().splitlines() if path.exists() else []

    def test_physical_and_container_keep_primary_profile(self):
        self.stub('systemd-detect-virt', '[[ "$*" != "--vm --quiet" ]]')
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.calls(), [f'picom --config {self.config}/picom/picom.conf'])

    def test_vm_uses_xrender_profile(self):
        self.env['TEST_VM'] = '0'
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.calls(), [f'picom --config {self.config}/picom/vm.conf'])

    def test_legacy_opt_in_keeps_primary_profile(self):
        self.env['TEST_VM'] = '0'
        (self.config / 'picom/enable-in-vm').touch()
        self.assertEqual(self.run_script().returncode, 0)
        self.assertIn('/picom/picom.conf', self.calls()[0])

    def test_vm_falls_back_once_after_error(self):
        self.env.update(TEST_VM='0', TEST_PICOM_EXIT='1')
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(len(self.calls()), 2)
        self.assertTrue(self.calls()[1].startswith('xcompmgr -c -C'))
        log = (self.root / 'state/i3/picom.log').read_text()
        self.assertIn('rounded corners and Picom opacity rules are unavailable', log)

    def test_vm_with_only_backup_installed(self):
        self.env['TEST_VM'] = '0'
        (self.bin / 'picom').unlink()
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(len(self.calls()), 1)
        self.assertTrue(self.calls()[0].startswith('xcompmgr'))

    def test_explicit_backup_and_off(self):
        profile = self.config / 'i3/desktop.env'
        profile.write_text('COMPOSITOR_MODE=xcompmgr\n')
        self.assertEqual(self.run_script().returncode, 0)
        self.assertTrue(self.calls()[0].startswith('xcompmgr'))
        profile.write_text('COMPOSITOR_MODE=off\n')
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(len(self.calls()), 1)

    def test_disable_marker_overrides_vm_and_explicit_selection(self):
        self.env.update(TEST_VM='0', COMPOSITOR_MODE='xcompmgr')
        (self.config / 'picom/disable').touch()
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_existing_compositor_is_not_replaced(self):
        for name in ('picom', 'xcompmgr'):
            self.stub('pgrep', f'[[ "${{@: -1}}" == {name} ]]')
            self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_missing_backup_reports_failure(self):
        self.env.update(TEST_VM='0', TEST_PICOM_EXIT='1')
        (self.bin / 'xcompmgr').unlink()
        self.assertNotEqual(self.run_script().returncode, 0)
        self.assertIn('install xcompmgr', (self.root / 'state/i3/picom.log').read_text())

    def test_stop_does_not_trigger_backup(self):
        self.env.update(TEST_VM='0', TEST_PICOM_EXIT='143')
        self.assertEqual(self.run_script().returncode, 143)
        self.assertEqual(len(self.calls()), 1)

    def test_restart_lock_and_launcher_stop(self):
        self.env['TEST_VM'] = '0'
        self.stub('picom', '''
printf 'picom\n' >> "$TEST_ROOT/calls"
trap 'printf stopped > "$TEST_ROOT/stopped"; exit 0' TERM
while :; do sleep 0.05; done
''')
        process = subprocess.Popen([str(SCRIPT)], env=self.env)
        try:
            deadline = time.monotonic() + 3
            while not self.calls() and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertEqual(self.calls(), ['picom'])
            self.assertEqual(self.run_script().returncode, 0)
            self.assertEqual(self.calls(), ['picom'])
            process.terminate()
            self.assertEqual(process.wait(timeout=3), 0)
            self.assertTrue((self.root / 'stopped').exists())
            self.assertEqual(self.calls(), ['picom'])
            # Stopping the launcher releases its lock for the next session.
            self.stub('picom', 'printf restarted >> "$TEST_ROOT/calls"')
            self.assertEqual(self.run_script().returncode, 0)
            self.assertEqual(self.calls(), ['picom', 'restarted'])
        finally:
            if process.poll() is None:
                process.terminate()
                process.wait(timeout=3)


if __name__ == '__main__':
    unittest.main(verbosity=2)

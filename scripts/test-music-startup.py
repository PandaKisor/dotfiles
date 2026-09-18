#!/usr/bin/env python3
"""Exercise login audio races without starting applications or using live IPC."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'home/.config/i3/music-player.sh'


class MusicStartupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='music-startup-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'bin').mkdir()
        self.env = dict(os.environ, TEST_ROOT=str(self.root),
                        PATH=f"{self.root / 'bin'}:{os.environ['PATH']}",
                        XDG_CONFIG_HOME=str(self.root / 'config'),
                        XDG_RUNTIME_DIR=str(self.root), XDG_STATE_HOME=str(self.root / 'state'))
        hook = self.root / 'clock.sh'
        hook.write_text('sleep() { printf "%s\\n" "$1" >> "$TEST_ROOT/sleeps"; SECONDS=$((SECONDS + $1)); }\n')
        self.env['BASH_ENV'] = str(hook)
        (self.root / 'tree').write_text('{"type":"root","nodes":[]}')
        self.stub('i3-msg', '''
if [[ "$*" == '-t get_tree' ]]; then cat "$TEST_ROOT/tree";
else printf '%s\n' "$*" >> "$TEST_ROOT/workspace-commands"; fi
''')
        self.stub('pear-desktop', 'touch "$TEST_ROOT/player-started"\n')
        self.stub('pactl', '''
if [[ "$1" == get-default-sink ]]; then
    count=0
    [[ ! -e "$TEST_ROOT/attempts" ]] || read -r count < "$TEST_ROOT/attempts"
    count=$((count + 1))
    printf '%s\n' "$count" > "$TEST_ROOT/attempts"
    (( count >= 3 )) || exit 1
    printf 'test-output\n'
else
    printf '1\ttest-output\tPipeWire\tfloat32le\tSUSPENDED\n'
fi
''')

    def stub(self, name, body):
        path = self.root / 'bin' / name
        path.write_text('#!/usr/bin/env bash\n' + body)
        path.chmod(0o755)

    def run_startup(self):
        result = subprocess.run([str(SCRIPT), '--autostart'], env=self.env,
                                capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_waits_for_audio_and_accepts_idle_output(self):
        self.run_startup()
        self.assertEqual((self.root / 'sleeps').read_text(), '5\n1\n1\n')
        self.assertTrue((self.root / 'player-started').exists())
        self.assertFalse((self.root / 'workspace-commands').exists())

    def test_disabled_music_skips_all_entry_points(self):
        config = self.root / 'config/i3'
        config.mkdir(parents=True)
        (config / 'desktop.env').write_text('MUSIC_ENABLED=0\n')
        self.stub('playerctld', 'touch "$TEST_ROOT/daemon-started"\n')
        self.stub('firefox', 'touch "$TEST_ROOT/browser-started"\n')
        for args in ([], ['--autostart'], ['--daemon']):
            result = subprocess.run([str(SCRIPT), *args], env=self.env,
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0, result.stderr)
        for name in ('player-started', 'daemon-started', 'browser-started',
                     'sleeps', 'workspace-commands', 'attempts'):
            self.assertFalse((self.root / name).exists(), name)

    def test_enabled_daemon_starts(self):
        self.stub('playerctld', 'touch "$TEST_ROOT/daemon-started"\n')
        subprocess.run([str(SCRIPT), '--daemon'], env=self.env, check=True, timeout=5)
        self.assertTrue((self.root / 'daemon-started').exists())

    def test_existing_player_skips_startup(self):
        (self.root / 'tree').write_text(json.dumps({'nodes': [
            {'window_properties': {'class': 'com.github.th-ch.youtube-music'}}]}))
        self.run_startup()
        self.assertFalse((self.root / 'player-started').exists())
        self.assertFalse((self.root / 'sleeps').exists())

    def test_audio_timeout_is_bounded(self):
        self.stub('pactl', "printf 'auto_null\\n'\n")
        self.run_startup()
        self.assertEqual(len((self.root / 'sleeps').read_text().splitlines()), 31)
        self.assertTrue((self.root / 'player-started').exists())
        self.assertIn('No audio output became ready',
                      (self.root / 'state/i3/music-player.log').read_text())

    def test_player_opened_during_wait_is_not_relaunched(self):
        self.stub('pactl', '''
printf '{"nodes":[{"window_properties":{"class":"com.github.th-ch.youtube-music"}}]}\n' > "$TEST_ROOT/tree"
if [[ "$1" == get-default-sink ]]; then printf 'test-output\n';
else printf '1\ttest-output\tPipeWire\tfloat32le\tSUSPENDED\n'; fi
''')
        self.run_startup()
        self.assertFalse((self.root / 'player-started').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)

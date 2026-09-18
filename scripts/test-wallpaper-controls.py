#!/usr/bin/env python3
"""Isolated regression tests; never contact or alter the live desktop."""
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1] / "home/.config/i3"


class WallpaperTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="wallpaper-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.config = self.root / "config/i3"
        self.state = self.root / "state/i3"
        self.bin = self.root / "bin"
        for directory in (self.config, self.state, self.bin, self.root / "runtime"):
            directory.mkdir(parents=True)
        for name in ("wallpaper-controls.sh", "live-wallpaper.sh",
                     "video-theme.sh", "wallpaper-rotation.sh"):
            shutil.copy2(SOURCE / name, self.config / name)
        self.env = dict(os.environ, XDG_CONFIG_HOME=str(self.root / "config"),
                        XDG_STATE_HOME=str(self.root / "state"),
                        XDG_CACHE_HOME=str(self.root / "cache"),
                        XDG_RUNTIME_DIR=str(self.root / "runtime"),
                        PATH=f"{self.bin}:{os.environ['PATH']}",
                        TEST_ROOT=str(self.root), WALLPAPER_INTERVAL="60")
        self.env.pop("BASH_ENV", None)
        self.env.pop("WALLPAPER_SCHEDULED", None)
        self.tree()
        self.stub("i3-msg", '''
if [[ "$*" == '-t get_tree' ]]; then
    cat "$TEST_ROOT/tree"
else
    printf '%s\n' "$*" >> "$TEST_ROOT/reloads"
fi
''')

    def stub(self, name, body, path=None):
        target = path or self.bin / name
        target.write_text("#!/usr/bin/env bash\n" + body)
        target.chmod(0o755)

    def tree(self, fullscreen=0, container="con"):
        tree = {"type": "root", "nodes": [{"type": "workspace",
                "fullscreen_mode": 1, "nodes": [{"type": container,
                "fullscreen_mode": fullscreen, "nodes": []}]}]}
        (self.root / "tree").write_text(json.dumps(tree))

    def run_script(self, name, *args):
        return subprocess.run([str(self.config / name), *args], env=self.env,
                              capture_output=True, text=True, timeout=10)

    def ready(self):
        return subprocess.run(["bash", "-c", 'source "$XDG_CONFIG_HOME/i3/wallpaper-controls.sh"; '
                               'wallpaper_rotation_ready'], env=self.env,
                              capture_output=True, timeout=3).returncode == 0

    def test_fullscreen_containers_and_ipc_failure(self):
        self.assertTrue(self.ready(), "workspace fullscreen flag is not a game")
        for container in ("con", "floating_con"):
            for fullscreen in (1, 2):
                self.tree(fullscreen, container)
                self.assertFalse(self.ready())
        (self.root / "tree").write_text("invalid IPC response")
        self.assertFalse(self.ready())
        (self.root / "tree").write_text('{}')
        self.assertFalse(self.ready())
        self.stub("i3-msg", "exit 1\n")
        self.assertFalse(self.ready())

    def test_missing_desktop_tools_fail_without_holding_selection_lock(self):
        image = self.root / 'wallpaper.png'
        image.touch()
        # A minimal PATH reproduces a fresh VM without jq, independently of
        # which packages are installed on the test host.
        for name in ('bash', 'mkdir', 'find', 'sort', 'flock', 'cat'):
            (self.bin / name).symlink_to(shutil.which(name))
        self.stub('feh', 'printf rendered > "$TEST_ROOT/rendered"\n')
        self.stub('wal', 'exit 0\n')
        self.env['PATH'] = str(self.bin)
        self.env['WALLPAPER_MODE'] = 'image'
        for missing in ('jq', 'i3-msg'):
            if missing == 'i3-msg':
                (self.bin / 'i3-msg').unlink()
                (self.bin / 'jq').symlink_to(shutil.which('jq'))
            for script in ('live-wallpaper.sh', 'video-theme.sh'):
                with self.subTest(missing=missing, script=script):
                    result = self.run_script(script, str(image))
                    self.assertNotEqual(result.returncode, 0)
                    self.assertIn(f'Required command not found: {missing}', result.stderr)
            lock = self.root / f'runtime/i3-live-wallpaper-{os.getuid()}.lock'
            with lock.open('a') as handle:
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertFalse((self.root / 'rendered').exists())

    def test_competing_selection_preserves_active_log(self):
        log = self.state / 'live-wallpaper.log'
        log.write_text('Selected image wallpaper: diagnostic.png\n')
        lock = self.root / f'runtime/i3-live-wallpaper-{os.getuid()}.lock'
        with lock.open('a') as handle:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.run_script('live-wallpaper.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Another wallpaper selection', result.stderr)
        self.assertIn('Selected image wallpaper: diagnostic.png', log.read_text())

    def test_static_work_profile_has_no_polling_or_video(self):
        (self.config / 'wallpaper.env').write_text('WALLPAPER_MODE=image\nWALLPAPER_INTERVAL=0\n')
        self.stub('i3-msg', 'touch "$TEST_ROOT/ipc-called"\nexit 1\n')
        result = self.run_script('wallpaper-rotation.sh')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / 'ipc-called').exists())
        video = self.root / 'old wallpaper.mp4'
        video.touch()
        self.stub('xwinwrap', 'touch "$TEST_ROOT/renderer-called"\n')
        for args in ([str(video)], ['--current']):
            (self.state / 'current-wallpaper').write_text(str(video))
            result = self.run_script('live-wallpaper.sh', *args)
            self.assertEqual(result.returncode, 1, result.stderr)
            self.assertIn('Video wallpaper is disabled', (self.state / 'live-wallpaper.log').read_text())
        self.assertFalse((self.root / 'renderer-called').exists())

    def test_timer_toggle_and_scheduled_selection_guard(self):
        result = self.run_script("wallpaper-controls.sh", "toggle-timer")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.ready())
        result = self.run_script("live-wallpaper.sh", "--scheduled")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.state / "wallpaper-history").exists())
        self.run_script("wallpaper-controls.sh", "toggle-timer")
        self.assertTrue(self.ready())
        self.tree(1)
        result = self.run_script("live-wallpaper.sh", "--scheduled")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.state / "wallpaper-history").exists())

    def test_renderer_upgrade_preserves_palette_and_history(self):
        video = self.root / "current animation.mp4"
        video.touch()
        history = self.state / "wallpaper-history"
        history.write_text(str(video) + "\n")
        (self.state / "wallpaper-animation-paused").touch()
        self.stub("xwinwrap", 'printf "%s\\n" "$@" > "$TEST_ROOT/renderer"\n')
        self.stub("mpv", "exit 0\n")
        self.stub("xsetroot", "exit 0\n")
        self.stub("video-theme.sh", 'touch "$TEST_ROOT/theme-called"\n',
                  self.config / "video-theme.sh")
        result = self.run_script("live-wallpaper.sh", "--current")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "theme-called").exists())
        self.assertFalse((self.root / "reloads").exists())
        self.assertEqual(history.read_text(), str(video) + "\n")
        self.assertIn("--pause=yes", (self.root / "renderer").read_text())
        self.assertIn("--input-ipc-server=", (self.root / "renderer").read_text())

    def test_timer_preserves_remaining_time_through_both_pauses(self):
        # Accelerate only the daemon's clock; exercise the production loop.
        hook = self.root / "clock.sh"
        hook.write_text('''
sleep() {
    tick=$(( ${tick:-0} + 1 ))
    SECONDS=$((SECONDS + $1))
    printf '%s' "$tick" > "$TEST_ROOT/tick"
    case "$tick" in
        5) touch "$XDG_STATE_HOME/i3/wallpaper-rotation-paused" ;;
        10) rm "$XDG_STATE_HOME/i3/wallpaper-rotation-paused" ;;
        15) cp "$TEST_ROOT/fullscreen" "$TEST_ROOT/tree" ;;
        20) cp "$TEST_ROOT/normal" "$TEST_ROOT/tree" ;;
        45) exit 0 ;;
    esac
    command sleep 0.01
}
''')
        shutil.copy(self.root / "tree", self.root / "normal")
        self.tree(1)
        shutil.copy(self.root / "tree", self.root / "fullscreen")
        self.tree()
        self.env["BASH_ENV"] = str(hook)
        self.stub("setsid", 'shift; "$@"\n')
        self.stub("live-wallpaper.sh", '''
printf '%s %s\n' "$(cat "$TEST_ROOT/tick")" "$*" >> "$TEST_ROOT/selections"
''', self.config / "live-wallpaper.sh")
        result = self.run_script("wallpaper-rotation.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        selections = (self.root / "selections").read_text().splitlines()
        self.assertEqual(len(selections), 1)
        tick, action = selections[0].split()
        self.assertGreaterEqual(int(tick), 40)
        self.assertEqual(action, "--scheduled")

    def test_fullscreen_during_palette_generation_defers_restart(self):
        image = self.root / "wallpaper.png"
        image.touch()
        shutil.copy(self.root / "tree", self.root / "normal")
        self.tree(1)
        shutil.copy(self.root / "tree", self.root / "fullscreen")
        self.tree()
        self.stub("wal", '''
mkdir -p "$PYWAL_CACHE_DIR"
for template in colors-i3.conf colors-polybar.ini colors-rofi.rasi dunstrc; do
    printf 'client.focused test\n' > "$PYWAL_CACHE_DIR/$template"
done
printf '%s\n' "${@: -1}" > "$PYWAL_CACHE_DIR/wal"
cp "$TEST_ROOT/fullscreen" "$TEST_ROOT/tree"
''')
        self.stub("sleep", '''
[[ ! -e "$TEST_ROOT/reloads" ]] || exit 1
touch "$TEST_ROOT/deferred"
cp "$TEST_ROOT/normal" "$TEST_ROOT/tree"
''')
        self.stub("dunstctl", "exit 0\n")
        result = self.run_script("video-theme.sh", str(image))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / "deferred").exists())
        self.assertEqual((self.root / "reloads").read_text(), "restart\n")

    def test_timer_does_not_pass_its_lock_to_sleep(self):
        self.env["WALLPAPER_INTERVAL"] = "0"
        self.stub("sleep", '''
for fd in /proc/$$/fd/*; do
    target="$(readlink "$fd" || true)"
    if [[ "$target" == *i3-wallpaper-rotation-*.lock ]]; then
        touch "$TEST_ROOT/leaked-lock"
    fi
done
touch "$TEST_ROOT/sleep-checked"
exit 1
''')
        result = self.run_script("wallpaper-rotation.sh")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / "sleep-checked").exists())
        self.assertFalse((self.root / "leaked-lock").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)

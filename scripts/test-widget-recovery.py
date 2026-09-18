#!/usr/bin/env python3
"""Check widget recovery, lock isolation, and stable Cava configuration."""
import fcntl
import os
from pathlib import Path
import subprocess
import tempfile
import time

script = Path(__file__).resolve().parents[1] / 'home/.config/i3/widget-workspace.sh'
with tempfile.TemporaryDirectory(prefix='widget-recovery-test-') as temp:
    root = Path(temp)
    (root / 'bin').mkdir()
    (root / 'config/conky').mkdir(parents=True)
    (root / 'config/conky/widget.conf').touch()
    env = dict(os.environ, XDG_RUNTIME_DIR=temp, XDG_CONFIG_HOME=str(root / 'config'),
               XDG_STATE_HOME=str(root / 'state'), XDG_CACHE_HOME=str(root / 'cache'),
               PATH=f"{root / 'bin'}:{os.environ['PATH']}", TEST_ROOT=temp)

    def stub(name, text):
        path = root / 'bin' / name
        path.write_text('#!/usr/bin/env bash\n' + text)
        path.chmod(0o755)

    stub('i3-msg', '''cat <<'JSON'
{"nodes":[{"window_properties":{"class":"i3-widget-calendar"}},
          {"window_properties":{"class":"i3-widget-system"}}]}
JSON
''')
    stub('cava', 'exit 0\n')
    stub('conky', 'exit 0\n')
    stub('calcurse', 'exit 0\n')
    stub('alacritty', '''
printf 'launch\n' >> "$TEST_ROOT/launches"
for fd in /proc/$$/fd/*; do
    target="$(readlink "$fd" || true)"
    [[ "$target" != *i3-widget*.lock ]] || touch "$TEST_ROOT/leaked-lock"
done
touch "$TEST_ROOT/checked"
sleep 2
''')
    with (root / f'i3-widgets-{os.getuid()}.lock').open('w') as legacy:
        fcntl.flock(legacy, fcntl.LOCK_EX | fcntl.LOCK_NB)
        subprocess.run([str(script), 'ensure'], env=env, check=True, timeout=4)
        for _ in range(100):
            if (root / 'checked').exists():
                break
            time.sleep(.01)
        assert (root / 'checked').exists(), 'recovery was blocked by the old lock'
        assert not (root / 'leaked-lock').exists(), 'terminal inherited the new lock'
        with (root / f'i3-widget-launch-{os.getuid()}.lock').open('r') as current:
            fcntl.flock(current, fcntl.LOCK_EX | fcntl.LOCK_NB)
        cava_config = root / 'cache/i3-widgets/cava.conf'
        original_config = cava_config.stat()
        subprocess.run([str(script), 'ensure'], env=env, check=True, timeout=4)
        assert (root / 'launches').read_text() == 'launch\n', 'duplicate visualizer launched'
        checked_config = cava_config.stat()
        assert (checked_config.st_ino, checked_config.st_mtime_ns) == (
            original_config.st_ino, original_config.st_mtime_ns
        ), 'unchanged recovery check rewrote Cava config and triggered live reload'

        palette = root / 'cache/wal/colors.sh'
        palette.parent.mkdir()
        palette.write_text("color4='#123456'\n")
        subprocess.run([str(script), 'refresh-theme'], env=env, check=True, timeout=4)
        assert "gradient_color_1 = '#123456'" in cava_config.read_text(), 'new palette was not applied'
        themed_config = cava_config.stat()
        subprocess.run([str(script), 'ensure'], env=env, check=True, timeout=4)
        checked_config = cava_config.stat()
        assert (checked_config.st_ino, checked_config.st_mtime_ns) == (
            themed_config.st_ino, themed_config.st_mtime_ns
        ), 'recovery check rewrote the updated palette'
        time.sleep(2)

        monitor = subprocess.Popen([str(script), 'monitor'], env=env)
        try:
            for _ in range(100):
                if (root / f'i3-widget-monitor-{os.getuid()}.lock').exists():
                    break
                time.sleep(.01)
            second = subprocess.run([str(script), 'monitor'], env=env, timeout=2)
            assert second.returncode == 0, 'second monitor did not exit cleanly'
        finally:
            monitor.terminate()
            monitor.wait(timeout=2)
        # A launcher may still be alive here; it must not retain the monitor lock.
        with (root / f'i3-widget-monitor-{os.getuid()}.lock').open('r') as monitor_file:
            fcntl.flock(monitor_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        time.sleep(2)
    (root / 'config/i3').mkdir()
    (root / 'config/i3/desktop.env').write_text('CAVA_ENABLED=0\n')
    launches_before = (root / 'launches').read_text()
    config_before = cava_config.stat()
    palette.write_text("color4='#654321'\n")
    stub('cava', 'touch "$TEST_ROOT/cava-started"\n')
    for action in ('ensure', 'open', 'refresh-theme', 'run-cava'):
        subprocess.run([str(script), action], env=env, check=True, timeout=4)
    assert (root / 'launches').read_text() == launches_before, 'disabled Cava was recovered'
    assert not (root / 'cava-started').exists(), 'direct Cava launch ignored the profile'
    assert cava_config.stat().st_mtime_ns == config_before.st_mtime_ns, 'disabled Cava was recolored'

    stub('i3-msg', 'printf \'{"nodes":[]}\\n\'\n')
    stub('alacritty', 'printf "%s\\n" "$*" >> "$TEST_ROOT/work-widgets"\n')
    stub('conky', 'touch "$TEST_ROOT/work-conky"\n')
    subprocess.run([str(script), 'ensure'], env=env, check=True, timeout=4)
    for _ in range(100):
        if (root / 'work-widgets').exists() and (root / 'work-conky').exists():
            break
        time.sleep(.01)
    assert 'i3-widget-calendar' in (root / 'work-widgets').read_text(), 'calendar did not launch'
    assert 'i3-widget-cava' not in (root / 'work-widgets').read_text(), 'Cava launched with calendar'
    assert (root / 'work-conky').exists(), 'system widget did not launch'

print('PASS: legacy recovery, lock isolation, duplicate prevention, stable Cava config, palette updates, singleton monitor')

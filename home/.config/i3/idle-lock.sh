#!/usr/bin/env bash
# Locker for xss-lock: locks after the X screensaver timeout and before
# suspend. Based on xss-lock's transfer-sleep-lock example: with
# --transfer-sleep-lock, sleep is held off until i3lock has grabbed the
# screen, then the inherited fd is closed so suspend can proceed.

set -u

lock_screen="$HOME/.config/i3/lock-screen.sh"

i3lock_running() {
    pgrep -xu "$EUID" i3lock >/dev/null 2>&1
}

# Already locked (e.g. Mod+l, then idle): nothing to do.
i3lock_running && exit 0

if [[ -n "${XSS_SLEEP_LOCK_FD:-}" && -e "/dev/fd/$XSS_SLEEP_LOCK_FD" ]]; then
    trap 'pkill -xu "$EUID" i3lock' TERM INT
    # lock-screen.sh execs i3lock, which forks once the screen is grabbed.
    "$lock_screen" {XSS_SLEEP_LOCK_FD}<&-
    exec {XSS_SLEEP_LOCK_FD}<&-
else
    trap 'pkill -xu "$EUID" i3lock' TERM INT
    "$lock_screen"
fi

# Stay alive while locked so xss-lock doesn't start a second locker.
while i3lock_running; do
    sleep 0.5
done

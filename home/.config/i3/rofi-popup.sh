#!/usr/bin/env bash

set -u

popup_mode='popup-menu'
mode_active=0

cleanup() {
    if (( mode_active == 1 )) && command -v i3-msg >/dev/null 2>&1; then
        i3-msg 'mode "default"' >/dev/null 2>&1 || true
    fi
}

trap cleanup EXIT
trap 'exit 0' HUP INT TERM

for command_name in flock rofi; do
    command -v "$command_name" >/dev/null 2>&1 || exit 1
done

# Keep a second launcher from racing the first wrapper's mode cleanup.
exec 9<"$0" || exit 1
flock -n 9 || exit 0

# A managed window avoids Rofi's exclusive keyboard grab. i3 owns Escape while
# this process is alive, so even a broken menu can always be dismissed.
if command -v i3-msg >/dev/null 2>&1 \
    && i3-msg "mode \"$popup_mode\"" >/dev/null 2>&1; then
    mode_active=1
fi

rofi \
    -normal-window \
    -replace \
    -kb-cancel 'Escape,Control+g,Control+bracketleft' \
    "$@"

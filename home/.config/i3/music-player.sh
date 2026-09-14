#!/usr/bin/env bash

set -u

# Move to the shared background-app workspace before focusing or launching the
# player. Pear is single-instance, so invoking it again raises its existing
# window instead of creating duplicates.
if command -v i3-msg >/dev/null 2>&1; then
    i3-msg 'workspace number 10:widgets' >/dev/null
fi

# CachyOS has used both names for this application across packaging changes.
for application in pear-desktop youtube-music; do
    if command -v "$application" >/dev/null 2>&1; then
        exec "$application"
    fi
done

if command -v notify-send >/dev/null 2>&1; then
    notify-send \
        "YouTube Music" \
        "Pear Desktop is not installed; opening a dedicated Firefox window."
fi

if command -v firefox >/dev/null 2>&1; then
    exec firefox --new-window https://music.youtube.com/
fi

printf 'Install pear-desktop or Firefox to open YouTube Music.\n' >&2
exit 1

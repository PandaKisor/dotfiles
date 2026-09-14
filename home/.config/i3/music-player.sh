#!/usr/bin/env bash

set -u

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

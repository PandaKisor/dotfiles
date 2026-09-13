#!/usr/bin/env bash

set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
video="${1:-$config_home/i3/wallpapers/videos/nebula.mp4}"
seek="${2:-${PYWAL_VIDEO_SEEK:-00:00:12}}"
wal_cache="$cache_home/wal"
frame="$wal_cache/video-frame.png"

for command_name in ffmpeg wal; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'Required command not found: %s\n' "$command_name" >&2
        exit 1
    }
done

[[ -r "$video" ]] || {
    printf 'Video not found: %s\n' "$video" >&2
    exit 1
}

mkdir -p -- "$wal_cache"
temporary_frame="$(mktemp --tmpdir="$wal_cache" .video-frame.XXXXXX.png)"
trap 'rm -f -- "$temporary_frame"' EXIT

# A 1920px frame is enough for palette extraction and much faster than feeding
# Pywal the original 4K image.
ffmpeg -nostdin -hide_banner -loglevel error \
    -ss "$seek" -i "$video" \
    -frames:v 1 \
    -vf "scale=1920:-2:force_original_aspect_ratio=decrease" \
    -y "$temporary_frame"
mv -- "$temporary_frame" "$frame"
trap - EXIT

# -n preserves the animated wallpaper; -e lets this script reload only the
# components used by this desktop.
wal -n -q -e --cols16 darken -i "$frame"

if command -v xrdb >/dev/null 2>&1 && [[ -r "$wal_cache/colors.Xresources" ]]; then
    xrdb -merge "$wal_cache/colors.Xresources"
fi

if command -v dunstctl >/dev/null 2>&1 && [[ -r "$wal_cache/dunstrc" ]]; then
    dunstctl reload "$wal_cache/dunstrc" >/dev/null 2>&1 || true
fi

# Reloading i3 applies its generated color include and restarts Polybar through
# the existing exec_always line. This script itself is started with exec once.
if command -v i3-msg >/dev/null 2>&1 \
    && i3-msg -t get_version >/dev/null 2>&1; then
    i3-msg reload >/dev/null 2>&1 || true
elif [[ -x "$config_home/polybar/launch.sh" ]]; then
    "$config_home/polybar/launch.sh"
fi

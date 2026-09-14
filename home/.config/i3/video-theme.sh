#!/usr/bin/env bash

set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
video="${1:-$config_home/i3/wallpapers/videos/nebula.mp4}"
requested_seek="${2:-${PYWAL_VIDEO_SEEK:-auto}}"
wal_cache="$cache_home/wal"
frame="$wal_cache/video-frame.png"

for command_name in ffmpeg ffprobe wal; do
    command -v "$command_name" >/dev/null 2>&1 || {
        printf 'Required command not found: %s\n' "$command_name" >&2
        exit 1
    }
done

[[ -r "$video" ]] || {
    printf 'Video not found: %s\n' "$video" >&2
    exit 1
}

if [[ "$requested_seek" == "auto" ]]; then
    duration="$(ffprobe -v error \
        -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 \
        "$video")"
    [[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
        printf 'Could not determine video duration: %s\n' "$video" >&2
        exit 1
    }
    # Thirty-five percent avoids common title and end-card frames while keeping
    # the result stable across restarts.
    seek="$(awk -v duration="$duration" 'BEGIN { printf "%.3f", duration * 0.35 }')"
else
    seek="$requested_seek"
fi

mkdir -p -- "$wal_cache"
temporary_frame="$(mktemp --tmpdir="$wal_cache" .video-frame.XXXXXX.png)"
trap 'rm -f -- "$temporary_frame"' EXIT

# A 1920px frame is enough for palette extraction and much faster than feeding
# Pywal the original 4K image.
printf 'Extracting theme frame at %ss from %s\n' "$seek" "$video"
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
    xrdb -merge "$wal_cache/colors.Xresources" >/dev/null 2>&1 || true
fi

if command -v dunstctl >/dev/null 2>&1 && [[ -r "$wal_cache/dunstrc" ]]; then
    dunstctl reload "$wal_cache/dunstrc" >/dev/null 2>&1 || true
fi

# Reloading i3 applies its generated color include and restarts Polybar through
# the existing exec_always line. Issue the reload directly: a separate version
# probe can fail even when the command socket is available to this process.
if command -v i3-msg >/dev/null 2>&1; then
    if reload_output="$(i3-msg reload 2>&1)"; then
        printf 'Reloaded i3 with the generated palette: %s\n' "$reload_output"
    else
        printf 'Could not reload i3 automatically: %s\n' "$reload_output" >&2
        [[ -x "$config_home/polybar/launch.sh" ]] && "$config_home/polybar/launch.sh"
    fi
elif [[ -x "$config_home/polybar/launch.sh" ]]; then
    "$config_home/polybar/launch.sh"
fi

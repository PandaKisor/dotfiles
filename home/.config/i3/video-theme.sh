#!/usr/bin/env bash

set -euo pipefail

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
source "$config_home/i3/wallpaper-controls.sh" || exit 1
cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
wallpaper="${1:-$config_home/i3/wallpapers/videos/nebula.mp4}"
requested_seek="${2:-${PYWAL_VIDEO_SEEK:-auto}}"
wal_cache="$cache_home/wal"
frame="$wal_cache/video-frame.png"
required_templates=(
    colors-i3.conf
    colors-polybar.ini
    colors-rofi.rasi
    dunstrc
)

command -v wal >/dev/null 2>&1 || {
    printf 'Required command not found: wal\n' >&2
    exit 1
}

[[ -r "$wallpaper" ]] || {
    printf 'Wallpaper not found: %s\n' "$wallpaper" >&2
    exit 1
}

mkdir -p -- "$wal_cache"
wallpaper_wait_until_ready
case "${wallpaper,,}" in
    *.jpg|*.jpeg|*.png|*.webp)
        palette_source="$wallpaper"
        printf 'Generating theme directly from static image %s\n' "$wallpaper"
        ;;
    *.mp4)
        for command_name in ffmpeg ffprobe; do
            command -v "$command_name" >/dev/null 2>&1 || {
                printf 'Required command not found: %s\n' "$command_name" >&2
                exit 1
            }
        done

        if [[ "$requested_seek" == "auto" ]]; then
            duration="$(ffprobe -v error \
                -show_entries format=duration \
                -of default=noprint_wrappers=1:nokey=1 \
                "$wallpaper")"
            [[ "$duration" =~ ^[0-9]+([.][0-9]+)?$ ]] || {
                printf 'Could not determine video duration: %s\n' "$wallpaper" >&2
                exit 1
            }
            # Thirty-five percent avoids common title and end-card frames.
            seek="$(awk -v duration="$duration" 'BEGIN { printf "%.3f", duration * 0.35 }')"
        else
            seek="$requested_seek"
        fi

        temporary_frame="$(mktemp --tmpdir="$wal_cache" .video-frame.XXXXXX.png)"
        trap 'rm -f -- "$temporary_frame"' EXIT

        # A 1920px frame is enough for palette extraction and much faster than
        # feeding Pywal the original 4K video frame.
        printf 'Extracting theme frame at %ss from %s\n' "$seek" "$wallpaper"
        ffmpeg -nostdin -hide_banner -loglevel error \
            -ss "$seek" -i "$wallpaper" \
            -frames:v 1 \
            -vf "scale=1920:-2:force_original_aspect_ratio=decrease" \
            -y "$temporary_frame"
        mv -- "$temporary_frame" "$frame"
        trap - EXIT
        palette_source="$frame"
        ;;
    *)
        printf 'Unsupported wallpaper type: %s\n' "$wallpaper" >&2
        exit 1
        ;;
esac

# -n preserves the selected wallpaper. -e skips Pywal's broad reload hooks so
# this script can reload only the components used by this desktop. Pin the
# output directory so Pywal and every consumer agree even if PYWAL_CACHE_DIR is
# set elsewhere in the environment.
palette_source="$(readlink -f -- "$palette_source")"
PYWAL_CACHE_DIR="$wal_cache" \
    wal -n -q -e --cols16 darken --saturate 0.2 --contrast 3 -i "$palette_source"

for template in "${required_templates[@]}"; do
    if [[ ! -s "$wal_cache/$template" ]]; then
        printf 'Pywal did not generate required template: %s\n' "$wal_cache/$template" >&2
        exit 1
    fi
done
if ! grep -q '^client[.]focused[[:space:]]' "$wal_cache/colors-i3.conf"; then
    printf 'Generated i3 theme does not contain a focused-client override.\n' >&2
    exit 1
fi
if [[ ! -r "$wal_cache/wal" ]] || [[ "$(< "$wal_cache/wal")" != "$palette_source" ]]; then
    printf 'Pywal cache does not identify the selected palette source: %s\n' "$palette_source" >&2
    exit 1
fi

printf 'Generated palette from %s\n' "$palette_source"
sed -n '/^set \$pywal_/{s/^/  /;p;}' "$wal_cache/colors-i3.conf"

# Never restart i3 over a fullscreen application, even if it entered fullscreen
# while ffmpeg/Pywal was working. Manual timer pause also holds scheduled work.
wallpaper_wait_until_ready

if command -v xrdb >/dev/null 2>&1 && [[ -r "$wal_cache/colors.Xresources" ]]; then
    xrdb -merge "$wal_cache/colors.Xresources" >/dev/null 2>&1 || true
fi

if command -v dunstctl >/dev/null 2>&1 && [[ -r "$wal_cache/dunstrc" ]]; then
    dunstctl reload "$wal_cache/dunstrc" >/dev/null 2>&1 || true
fi

# Cava regenerates its gradient and Conky rereads colors.sh without replacing
# their windows, so the widget workspace changes palette with the wallpaper.
if [[ -x "$config_home/i3/widget-workspace.sh" ]]; then
    "$config_home/i3/widget-workspace.sh" refresh-theme >/dev/null 2>&1 || true
fi

# A full i3 restart is required for this setup to replace the generated color
# variables reliably. It preserves the window tree and restarts Polybar and the
# guarded autotiling helper through their exec_always entries.
if command -v i3-msg >/dev/null 2>&1; then
    wallpaper_wait_until_ready
    if restart_output="$(i3-msg restart 2>&1)"; then
        printf 'Restarted i3 with the generated palette: %s\n' "$restart_output"
    else
        printf 'Could not restart i3 automatically: %s\n' "$restart_output" >&2
        [[ -x "$config_home/polybar/launch.sh" ]] && "$config_home/polybar/launch.sh"
    fi
elif [[ -x "$config_home/polybar/launch.sh" ]]; then
    "$config_home/polybar/launch.sh"
fi

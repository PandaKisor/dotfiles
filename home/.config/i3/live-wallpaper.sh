#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
video="${1:-$config_home/i3/wallpapers/videos/nebula.mp4}"
theme_script="$config_home/i3/video-theme.sh"
log_dir="$state_home/i3"
log_file="$log_dir/live-wallpaper.log"
if [[ ! -d "$runtime_dir" || ! -w "$runtime_dir" ]]; then
    runtime_dir=/tmp
fi
pid_file="$runtime_dir/i3-live-wallpaper-$UID.pid"

mkdir -p -- "$log_dir"
: > "$log_file"

if [[ ! -r "$video" ]]; then
    printf 'Video not found: %s\n' "$video" > "$log_file"
    exit 1
fi

for command_name in xwinwrap mpv; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command_name" > "$log_file"
        exit 1
    fi
done

# Stop only the wallpaper process recorded by an earlier run of this script.
if [[ -r "$pid_file" ]]; then
    read -r old_pid < "$pid_file"
    if [[ "$old_pid" =~ ^[0-9]+$ ]] \
        && kill -0 "$old_pid" 2>/dev/null \
        && [[ "$(tr '\0' ' ' 2>/dev/null < "/proc/$old_pid/cmdline")" == *xwinwrap* ]]; then
        pkill -TERM -P "$old_pid" 2>/dev/null || true
        kill "$old_pid" 2>/dev/null || true
        for _ in {1..20}; do
            kill -0 "$old_pid" 2>/dev/null || break
            sleep 0.1
        done
    fi
fi

# Palette generation is useful but non-fatal: the wallpaper still starts when
# Pywal is not installed or a frame cannot be extracted.
if [[ -x "$theme_script" ]]; then
    "$theme_script" "$video" "${PYWAL_VIDEO_SEEK:-00:00:12}" >> "$log_file" 2>&1 \
        || printf 'Pywal theme generation failed; continuing with the wallpaper.\n' >> "$log_file"
fi

printf 'Starting live wallpaper with: %s\n' "$video" >> "$log_file"
printf '%s\n' "$$" > "$pid_file"

exec xwinwrap -fs -fdt -ni -b -nf -ov -- \
    mpv -wid %WID \
        --no-config \
        --vo=gpu \
        --gpu-context="${VIDEO_WALLPAPER_GPU_CONTEXT:-auto}" \
        --hwdec=auto-safe \
        --loop-file=inf \
        --no-audio \
        --no-osc \
        --no-osd-bar \
        --panscan=1.0 \
        --really-quiet \
        "$video" >> "$log_file" 2>&1

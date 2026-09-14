#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
wallpaper_settings="$config_home/i3/wallpaper.env"
if [[ -r "$wallpaper_settings" ]]; then
    # shellcheck source=/dev/null
    source "$wallpaper_settings"
fi
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
interval="${WALLPAPER_INTERVAL:-${VIDEO_WALLPAPER_INTERVAL:-1800}}"
wallpaper_script="$config_home/i3/live-wallpaper.sh"
log_dir="$state_home/i3"
log_file="$log_dir/wallpaper-rotation.log"

if [[ ! -d "$runtime_dir" || ! -w "$runtime_dir" ]]; then
    runtime_dir=/tmp
fi
lock_file="$runtime_dir/i3-wallpaper-rotation-$UID.lock"

mkdir -p -- "$log_dir"

if [[ ! "$interval" =~ ^[0-9]+$ ]]; then
    printf 'WALLPAPER_INTERVAL must be a whole number of seconds: %s\n' "$interval" > "$log_file"
    exit 1
fi
if (( interval == 0 )); then
    printf 'Automatic wallpaper rotation is disabled.\n' > "$log_file"
    exit 0
fi
if (( interval < 60 )); then
    printf 'Wallpaper rotation interval must be at least 60 seconds.\n' > "$log_file"
    exit 1
fi
if [[ ! -x "$wallpaper_script" ]]; then
    printf 'Wallpaper script is not executable: %s\n' "$wallpaper_script" > "$log_file"
    exit 1
fi
for command_name in flock setsid; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command_name" > "$log_file"
        exit 1
    fi
done

exec {rotation_lock_fd}>"$lock_file"
if ! flock -n "$rotation_lock_fd"; then
    exit 0
fi

printf 'Rotating wallpapers every %s seconds.\n' "$interval" > "$log_file"
while sleep "$interval"; do
    printf 'Starting scheduled rotation at %(%Y-%m-%d %H:%M:%S)T.\n' -1 >> "$log_file"
    setsid -f "$wallpaper_script" --next
done

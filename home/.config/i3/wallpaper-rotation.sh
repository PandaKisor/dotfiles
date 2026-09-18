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
source "$config_home/i3/wallpaper-controls.sh" || exit 1
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
if (( interval > 0 && interval < 60 )); then
    printf 'Wallpaper rotation interval must be at least 60 seconds.\n' > "$log_file"
    exit 1
fi
# Static wallpaper with no rotation needs neither a timer nor MPV polling.
if (( interval == 0 )); then
    case "${WALLPAPER_MODE:-auto}" in
        image|images|static) exit 0 ;;
    esac
fi
if [[ ! -x "$wallpaper_script" ]]; then
    printf 'Wallpaper script is not executable: %s\n' "$wallpaper_script" > "$log_file"
    exit 1
fi
for command_name in flock setsid i3-msg jq python3; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command_name" > "$log_file"
        exit 1
    fi
done

exec {rotation_lock_fd}>"$lock_file"
if ! flock -n "$rotation_lock_fd"; then
    exit 0
fi

printf 'Rotation interval: %s seconds; fullscreen protection active.\n' "$interval" > "$log_file"
remaining="$interval"
last_tick=$SECONDS
previous_ready=0
applied_pause=''
applied_socket=''
while :; do
    now=$SECONDS
    elapsed=$((now - last_tick))
    last_tick=$now
    desktop_ready=0
    wallpaper_desktop_ready && desktop_ready=1
    pause=no
    if (( desktop_ready == 0 )) || [[ -e "$animation_pause_file" ]]; then
        pause=yes
    fi
    socket_id="$(stat -Lc '%i' "$wallpaper_ipc" 2>/dev/null || true)"
    if [[ "$pause:$socket_id" != "$applied_pause:$applied_socket" ]]; then
        if wallpaper_set_animation_pause "$pause"; then
            applied_pause="$pause"
            applied_socket="$socket_id"
        fi
    fi

    ready=0
    if (( desktop_ready == 1 )) && [[ ! -e "$rotation_pause_file" ]]; then
        ready=1
    fi
    # Count only intervals whose endpoints were both unpaused. Resuming never
    # spends the time accumulated while a game or a manual pause was active.
    if (( interval > 0 && ready == 1 && previous_ready == 1 )); then
        remaining=$((remaining - elapsed))
        if (( remaining <= 0 )); then
            printf 'Starting scheduled rotation at %(%Y-%m-%d %H:%M:%S)T.\n' -1 >> "$log_file"
            # Do not let a detached renderer inherit the daemon's lifetime lock.
            (exec {rotation_lock_fd}>&-; setsid -f "$wallpaper_script" --scheduled)
            remaining="$interval"
        fi
    fi
    previous_ready=$ready
    # A sleeping child must not retain this lock after the daemon exits.
    sleep 2 {rotation_lock_fd}>&- || break
done

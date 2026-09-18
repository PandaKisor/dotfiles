#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
if [[ -r "$config_home/i3/desktop.env" ]]; then
    # shellcheck source=/dev/null
    source "$config_home/i3/desktop.env"
fi

autostart=0
case "${1:-}" in
    --autostart) autostart=1 ;;
    --daemon)
        [[ "${MUSIC_ENABLED:-1}" != 0 ]] || exit 0
        exec playerctld daemon
        ;;
    '') ;;
    *) printf 'Usage: %s [--autostart|--daemon]\n' "$0" >&2; exit 2 ;;
esac
[[ "${MUSIC_ENABLED:-1}" != 0 ]] || exit 0

player=''
# CachyOS has used both names for this application across packaging changes.
for application in pear-desktop youtube-music; do
    if command -v "$application" >/dev/null 2>&1; then
        player="$application"
        break
    fi
done

player_window_exists() {
    i3-msg -t get_tree 2>/dev/null | jq -e '
        [.. | objects | select(.window_properties?.class? ==
            "com.github.th-ch.youtube-music")] | length > 0
    ' >/dev/null 2>&1
}

audio_output_ready() {
    local sink sinks
    sink="$(timeout 2 pactl get-default-sink 2>/dev/null)" || return 1
    [[ -n "$sink" && "$sink" != auto_null ]] || return 1
    sinks="$(timeout 2 pactl list short sinks 2>/dev/null)" || return 1
    # A suspended sink is healthy when idle. Require the selected output to
    # exist rather than waiting for it to become RUNNING before music starts.
    awk -v sink="$sink" '$2 == sink { found=1 } END { exit !found }' <<< "$sinks"
}

if (( autostart == 1 )); then
    # Do not open the browser fallback or switch workspaces during login.
    [[ -n "$player" ]] || exit 0
    runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
    [[ -d "$runtime_dir" && -w "$runtime_dir" ]] || runtime_dir=/tmp
    exec 9>"$runtime_dir/i3-music-startup-$UID.lock"
    flock -n 9 || exit 0
    player_window_exists && exit 0
    log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/i3"
    mkdir -p -- "$log_dir"
    exec >>"$log_dir/music-player.log" 2>&1
    printf 'Waiting for login audio initialization.\n'
    sleep 5
    if command -v pactl >/dev/null 2>&1; then
        deadline=$((SECONDS + 30))
        while ! audio_output_ready; do
            if (( SECONDS >= deadline )); then
                printf 'No audio output became ready within 30 seconds; starting the player anyway.\n'
                break
            fi
            sleep 1
        done
    fi
    # Mod+M or a restored session may have opened the player during the wait.
    player_window_exists && exit 0
    printf 'Starting %s after the audio startup wait.\n' "$player"
    exec "$player" 9>&-
fi

# Move to the shared background-app workspace before focusing or launching the
# player. Pear is single-instance, so invoking it again raises its existing
# window instead of creating duplicates.
if command -v i3-msg >/dev/null 2>&1; then
    i3-msg 'workspace "10:widgets"' >/dev/null
fi

[[ -n "$player" ]] && exec "$player"

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

#!/usr/bin/env bash

# Shared by the selector, palette loader, timer, and control center.
wallpaper_state="${XDG_STATE_HOME:-$HOME/.local/state}/i3"
wallpaper_runtime="${XDG_RUNTIME_DIR:-/tmp}"
[[ -d "$wallpaper_runtime" && -w "$wallpaper_runtime" ]] || wallpaper_runtime=/tmp
wallpaper_ipc_dir="$wallpaper_runtime/i3-wallpaper-$UID"
wallpaper_ipc="$wallpaper_ipc_dir/mpv.sock"
rotation_pause_file="$wallpaper_state/wallpaper-rotation-paused"
animation_pause_file="$wallpaper_state/wallpaper-animation-paused"

wallpaper_desktop_ready() {
    local tree
    # Workspaces themselves can have fullscreen_mode=1 even with no fullscreen
    # application. Check containers only, including nested/floating containers.
    # Retain protection for games on another workspace or output as well.
    tree="$(i3-msg -t get_tree 2>/dev/null)" || return 1
    jq -e 'type == "object" and .type == "root" and
        ([.. | objects | select(
            (.type == "con" or .type == "floating_con") and
            ((.fullscreen_mode // 0) > 0))] | length == 0)' \
        <<< "$tree" >/dev/null 2>&1
}

wallpaper_rotation_ready() {
    [[ ! -e "$rotation_pause_file" ]] && wallpaper_desktop_ready
}

wallpaper_wait_until_ready() {
    while ! wallpaper_desktop_ready \
        || { [[ "${WALLPAPER_SCHEDULED:-0}" == 1 ]] && [[ -e "$rotation_pause_file" ]]; }; do
        sleep 2
    done
}

wallpaper_set_animation_pause() {
    [[ -S "$wallpaper_ipc" ]] || return 1
    python3 - "$wallpaper_ipc" "$1" <<'PY'
import json
import socket
import sys

try:
    with socket.socket(socket.AF_UNIX) as client:
        client.settimeout(1)
        client.connect(sys.argv[1])
        request = {"command": ["set_property", "pause", sys.argv[2] == "yes"],
                   "request_id": 1}
        client.sendall((json.dumps(request) + "\n").encode())
        with client.makefile("rb") as stream:
            for line in stream:
                response = json.loads(line)
                if response.get("request_id") == 1:
                    sys.exit(0 if response.get("error") == "success" else 1)
        sys.exit(1)
except (OSError, ValueError):
    sys.exit(1)
PY
}

wallpaper_animation_pause() {
    if [[ -e "$animation_pause_file" ]] || ! wallpaper_desktop_ready; then
        printf 'yes\n'
    else
        printf 'no\n'
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    set -eu
    mkdir -p -- "$wallpaper_state"
    case "${1:-}" in
        toggle-timer)
            if [[ -e "$rotation_pause_file" ]]; then
                rm -- "$rotation_pause_file"
            else
                touch -- "$rotation_pause_file"
            fi
            ;;
        toggle-animation)
            if [[ -e "$animation_pause_file" ]]; then
                rm -- "$animation_pause_file"
            else
                touch -- "$animation_pause_file"
            fi
            if ! wallpaper_set_animation_pause "$(wallpaper_animation_pause)"; then
                # Upgrade a renderer started before IPC support without changing
                # its wallpaper, history, or palette. Static images stay static.
                setsid -f "${XDG_CONFIG_HOME:-$HOME/.config}/i3/live-wallpaper.sh" \
                    --current </dev/null >/dev/null 2>&1
            fi
            ;;
        *) printf 'Usage: %s {toggle-timer|toggle-animation}\n' "$0" >&2; exit 2 ;;
    esac
fi

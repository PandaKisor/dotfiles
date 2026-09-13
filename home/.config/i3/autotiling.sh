#!/usr/bin/env bash

set -u

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
lock_file="$runtime_dir/i3-autotiling-${UID}.lock"

# i3 runs exec_always again on reload. Keep only one tiling helper active.
exec 9>"$lock_file"
flock -n 9 || exit 0

mode_file="${XDG_CONFIG_HOME:-$HOME/.config}/i3/autotiling-mode"
mode="alternating"
if [[ -r "$mode_file" ]]; then
    read -r mode < "$mode_file"
fi

case "$mode" in
    alternating)
        if command -v autotiling >/dev/null 2>&1; then
            exec autotiling
        elif command -v autotiling-rs >/dev/null 2>&1; then
            exec autotiling-rs
        fi
        logger -t i3-autotiling "mode is alternating, but neither autotiling nor autotiling-rs is installed"
        ;;
    quadrant)
        exec python3 "${XDG_CONFIG_HOME:-$HOME/.config}/i3/quadrant-tiling.py"
        ;;
    off)
        ;;
    *)
        logger -t i3-autotiling "unknown mode '$mode'; expected alternating, quadrant, or off"
        exit 2
        ;;
esac

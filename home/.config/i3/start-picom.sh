#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
if [[ -r "$config_home/i3/desktop.env" ]]; then
    # shellcheck source=/dev/null
    source "$config_home/i3/desktop.env"
fi
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
log_dir="$state_home/i3"
log_file="$log_dir/picom.log"
mkdir -p -- "$log_dir"

picom_config_home="$config_home/picom"

# A machine-local marker is an unconditional escape hatch for graphics stacks
# that do not behave well with a compositor.
if [[ -e "$picom_config_home/disable" ]]; then
    printf 'Local disable marker found; skipping compositing.\n' >> "$log_file"
    exit 0
fi

mode="${COMPOSITOR_MODE:-auto}"
if [[ "$mode" == auto ]]; then
    mode=picom
    # Containers do not change the physical desktop's rendering profile.
    if command -v systemd-detect-virt >/dev/null 2>&1 \
        && systemd-detect-virt --vm --quiet \
        && [[ ! -e "$picom_config_home/enable-in-vm" ]]; then
        mode=vm
    fi
fi
case "$mode" in
    off) exit 0 ;;
    picom|vm|xcompmgr) ;;
    *) printf 'Invalid COMPOSITOR_MODE=%s; expected auto, picom, vm, xcompmgr, or off.\n' "$mode" >> "$log_file"; exit 1 ;;
esac

# Retain the historical entry point and log path for existing i3 installs.
# One launcher owns the lock throughout startup and a possible fallback.
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
[[ -d "$runtime_dir" && -w "$runtime_dir" ]] || runtime_dir=/tmp
display_key="${DISPLAY:-default}"
display_key="${display_key//[^a-zA-Z0-9_-]/_}"
exec {compositor_lock}>"$runtime_dir/i3-compositor-$UID-$display_key.lock"
flock -n "$compositor_lock" || exit 0

# Leave manually started compositors alone, including older launcher versions.
if pgrep -u "$UID" -x picom >/dev/null 2>&1 \
    || pgrep -u "$UID" -x xcompmgr >/dev/null 2>&1; then
    printf 'A compositor is already running for this user; leaving it in place.\n' >> "$log_file"
    exit 0
fi

exec >> "$log_file" 2>&1
printf 'Starting compositor mode: %s\n' "$mode"
child_pid=''
stopping=0
stop_child() {
    stopping=1
    [[ -z "$child_pid" ]] || kill -TERM "$child_pid" 2>/dev/null || true
}
trap stop_child TERM INT HUP

run_compositor() {
    local result
    "$@" {compositor_lock}>&- &
    child_pid=$!
    wait "$child_pid"
    result=$?
    if (( stopping )); then
        wait "$child_pid" 2>/dev/null || true
    fi
    child_pid=''
    return "$result"
}

if [[ "$mode" == picom ]]; then
    command -v picom >/dev/null 2>&1 || { printf 'Required command not found: picom\n'; exit 1; }
    run_compositor picom --config "$picom_config_home/picom.conf"
    exit $?
fi

if [[ "$mode" == vm ]]; then
    if command -v picom >/dev/null 2>&1; then
        printf 'Trying Picom XRender: rounded corners, shadows, and opacity; no OpenGL or blur.\n'
        run_compositor picom --config "$picom_config_home/vm.conf"
        result=$?
        # Normal exit or an intentional stop must not launch a replacement.
        (( stopping )) && exit 0
        case "$result" in 0|129|130|143) exit "$result" ;; esac
        printf 'Picom XRender exited with status %s; trying xcompmgr once.\n' "$result"
    else
        printf 'Picom is unavailable; trying xcompmgr.\n'
    fi
fi

command -v xcompmgr >/dev/null 2>&1 || {
    printf 'Fallback unavailable: install xcompmgr. Desktop continues without compositing.\n'
    exit 1
}
printf 'Starting xcompmgr: shadows and application transparency; rounded corners and Picom opacity rules are unavailable.\n'
run_compositor xcompmgr -c -C -r 12 -o 0.42 -l -6 -t -6
exit $?

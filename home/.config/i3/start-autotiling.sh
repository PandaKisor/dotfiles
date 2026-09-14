#!/usr/bin/env bash

set -u

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
log_dir="$state_home/i3"
log_file="$log_dir/autotiling.log"
if [[ ! -d "$runtime_dir" || ! -w "$runtime_dir" ]]; then
    runtime_dir=/tmp
fi
pid_file="$runtime_dir/i3-autotiling-$UID.pid"

mkdir -p -- "$log_dir"

if ! command -v autotiling >/dev/null 2>&1; then
    printf 'Required command not found: autotiling\n' > "$log_file"
    exit 1
fi

# An i3 restart can leave the previous IPC client alive briefly. Stop only the
# process recorded by this wrapper before starting exactly one replacement.
if [[ -r "$pid_file" ]]; then
    read -r old_pid < "$pid_file"
    if [[ "$old_pid" =~ ^[0-9]+$ ]] \
        && kill -0 "$old_pid" 2>/dev/null \
        && [[ "$(tr '\0' ' ' 2>/dev/null < "/proc/$old_pid/cmdline")" == *autotiling* ]]; then
        kill "$old_pid" 2>/dev/null || true
        for _ in {1..20}; do
            kill -0 "$old_pid" 2>/dev/null || break
            sleep 0.1
        done
    fi
fi

printf '%s\n' "$$" > "$pid_file"
printf 'Starting autotiling.\n' > "$log_file"
exec autotiling >> "$log_file" 2>&1

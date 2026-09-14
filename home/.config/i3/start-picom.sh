#!/usr/bin/env bash

set -u

command -v picom >/dev/null 2>&1 || exit 0
pgrep -x picom >/dev/null 2>&1 && exit 0

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
log_dir="$state_home/i3"
log_file="$log_dir/picom.log"
mkdir -p -- "$log_dir"

picom_config_home="${XDG_CONFIG_HOME:-$HOME/.config}/picom"

# A machine-local marker is an unconditional escape hatch for graphics stacks
# that do not behave well with a compositor.
if [[ -e "$picom_config_home/disable" ]]; then
    printf 'Local disable marker found; skipping Picom.\n' > "$log_file"
    exit 0
fi

# Skip full virtual machines, but not containers used by development tools on
# this physical desktop. A local marker can opt in on a capable work VM.
if command -v systemd-detect-virt >/dev/null 2>&1 \
    && systemd-detect-virt --vm --quiet \
    && [[ ! -e "$picom_config_home/enable-in-vm" ]]; then
    printf 'Virtual machine detected; skipping Picom.\n' > "$log_file"
    exit 0
fi

printf 'Starting Picom.\n' > "$log_file"
exec picom --config "$picom_config_home/picom.conf" \
    >> "$log_file" 2>&1

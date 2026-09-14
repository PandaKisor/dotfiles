#!/usr/bin/env bash

set -u

command -v picom >/dev/null 2>&1 || exit 0
pgrep -x picom >/dev/null 2>&1 && exit 0

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
log_dir="$state_home/i3"
log_file="$log_dir/picom.log"
mkdir -p -- "$log_dir"

# Skip full virtual machines, but not containers used by development tools on
# this physical desktop. A local marker can opt in on a capable work VM.
if command -v systemd-detect-virt >/dev/null 2>&1 \
    && systemd-detect-virt --vm --quiet \
    && [[ ! -e "${XDG_CONFIG_HOME:-$HOME/.config}/picom/enable-in-vm" ]]; then
    printf 'Virtual machine detected; skipping Picom.\n' > "$log_file"
    exit 0
fi

printf 'Starting Picom.\n' > "$log_file"
exec picom --config "${XDG_CONFIG_HOME:-$HOME/.config}/picom/picom.conf" \
    >> "$log_file" 2>&1

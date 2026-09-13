#!/usr/bin/env bash

set -u

command -v picom >/dev/null 2>&1 || exit 0
pgrep -x picom >/dev/null 2>&1 && exit 0

# Compositors often perform poorly or fail under virtual graphics. A local,
# untracked marker allows opting back in for a VM where Picom works well.
if command -v systemd-detect-virt >/dev/null 2>&1 \
    && systemd-detect-virt --quiet \
    && [[ ! -e "${XDG_CONFIG_HOME:-$HOME/.config}/picom/enable-in-vm" ]]; then
    logger -t i3-picom "virtual machine detected; skipping Picom"
    exit 0
fi

exec picom --config "${XDG_CONFIG_HOME:-$HOME/.config}/picom/picom.conf"

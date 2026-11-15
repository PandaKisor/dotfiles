#!/usr/bin/env bash
# Clipboard history with greenclip, shown in Rofi. Kept in a script because i3
# splits exec lines at ";".
#   clipboard.sh menu    open the history menu (Mod+Shift+v)
#   clipboard.sh daemon  start the history recorder (login)

set -u

if ! command -v greenclip >/dev/null 2>&1; then
    command -v notify-send >/dev/null 2>&1 \
        && notify-send 'Clipboard history unavailable' 'Install rofi-greenclip (AUR).'
    exit 1
fi

case "${1:-menu}" in
    menu)
        exec "$HOME/.config/i3/rofi-popup.sh" \
            -modi 'clipboard:greenclip print' \
            -show clipboard \
            -run-command '{cmd}'
        ;;
    daemon)
        pgrep -xu "$UID" greenclip >/dev/null 2>&1 && exit 0
        exec greenclip daemon
        ;;
    *)
        printf 'Usage: %s {menu|daemon}\n' "${0##*/}" >&2
        exit 2
        ;;
esac

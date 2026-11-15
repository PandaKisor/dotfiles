#!/usr/bin/env bash
# Clipboard history: greenclip in Rofi, falling back to CopyQ if greenclip is
# not installed. Kept in a script because i3 splits exec lines at ";".
#   clipboard.sh menu    open the history menu (Mod+Shift+v)
#   clipboard.sh daemon  start the history recorder (login)

set -u

case "${1:-menu}" in
    menu)
        if command -v greenclip >/dev/null 2>&1; then
            exec "$HOME/.config/i3/rofi-popup.sh" \
                -modi 'clipboard:greenclip print' \
                -show clipboard \
                -run-command '{cmd}'
        fi
        exec copyq show
        ;;
    daemon)
        if command -v greenclip >/dev/null 2>&1; then
            pgrep -xu "$UID" greenclip >/dev/null 2>&1 && exit 0
            exec greenclip daemon
        fi
        exec copyq --start-server
        ;;
    *)
        printf 'Usage: %s {menu|daemon}\n' "${0##*/}" >&2
        exit 2
        ;;
esac

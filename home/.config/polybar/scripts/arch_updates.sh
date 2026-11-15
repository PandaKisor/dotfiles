#!/usr/bin/env bash
# Polybar: number of pending package updates (repositories + AUR).
# Prints nothing when the system is up to date, so the module disappears.
# Results are cached for an hour, and recomputed as soon as the local package
# database changes (i.e. right after you update).
#   arch_updates.sh          print the count (Polybar exec)
#   arch_updates.sh upgrade  open a terminal running the full upgrade

set -u

cache="${XDG_CACHE_HOME:-$HOME/.cache}/polybar-updates"
max_age=3600
pacman_db=/var/lib/pacman/local

if [[ "${1:-}" == upgrade ]]; then
    exec alacritty --class Alacritty,system-upgrade --title 'System upgrade' \
        -e bash -c 'if command -v paru >/dev/null; then paru -Syu; else sudo pacman -Syu; fi
            rm -f -- "'"$cache"'"
            printf "\nDone. Press Enter to close."; read -r _'
fi

command -v checkupdates >/dev/null 2>&1 || exit 0

now="$(date +%s)"
cache_time="$(stat -c %Y -- "$cache" 2>/dev/null || echo 0)"
db_time="$(stat -c %Y -- "$pacman_db" 2>/dev/null || echo 0)"

if (( now - cache_time >= max_age || db_time > cache_time )); then
    # checkupdates: 0 = updates listed, 2 = none, anything else = offline/error.
    repo="$(checkupdates 2>/dev/null)"
    status=$?
    if (( status != 0 && status != 2 )); then
        # Keep showing the last known count while offline.
        [[ -r "$cache" ]] && cat -- "$cache"
        exit 0
    fi
    repo_count="$(grep -c . <<<"$repo")"
    aur_count=0
    if command -v paru >/dev/null 2>&1; then
        aur_count="$(paru -Qua 2>/dev/null | grep -c .)"
    fi
    total=$(( repo_count + aur_count ))
    mkdir -p -- "${cache%/*}"
    if (( total > 0 )); then
        printf '󰏕 %s\n' "$total" > "$cache"
    else
        printf '\n' > "$cache"
    fi
fi

cat -- "$cache"

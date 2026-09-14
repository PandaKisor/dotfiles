#!/usr/bin/env bash

set -euo pipefail

cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
wal_colors="$cache_home/wal/colors.sh"

read_color() {
    local name="$1"
    local fallback="$2"
    local value=""

    if [[ -r "$wal_colors" ]]; then
        value="$(
            sed -n "s/^${name}='\(#[[:xdigit:]]\{6\}\)'$/\1/p" "$wal_colors" |
                head -n 1
        )"
    fi
    [[ "$value" =~ ^#[[:xdigit:]]{6}$ ]] || value="$fallback"
    printf '%s' "$value"
}

rgba() {
    printf '%s%s' "${1#\#}" "$2"
}

background="$(read_color background '#0B1118')"
foreground="$(read_color foreground '#D8DEE9')"
muted="$(read_color color8 '#4C566A')"
accent="$(read_color color4 '#88C0D0')"
accent_alt="$(read_color color12 '#00D1FF')"
alert="$(read_color color1 '#BF616A')"

arguments=(
    --blur="${I3LOCK_BLUR_RADIUS:-10}"
    --force-clock
    --indicator
    --radius=112
    --ring-width=8
    --inside-color="$(rgba "$background" d9)"
    --ring-color="$(rgba "$accent" ff)"
    --insidever-color="$(rgba "$background" ee)"
    --ringver-color="$(rgba "$foreground" ff)"
    --insidewrong-color="$(rgba "$background" ee)"
    --ringwrong-color="$(rgba "$alert" ff)"
    --line-uses-inside
    --keyhl-color="$(rgba "$accent_alt" ff)"
    --bshl-color="$(rgba "$alert" ff)"
    --separator-color=00000000
    --time-color="$(rgba "$foreground" ff)"
    --date-color="$(rgba "$muted" ff)"
    --greeter-color="$(rgba "$accent" ff)"
    --verif-color="$(rgba "$foreground" ff)"
    --wrong-color="$(rgba "$alert" ff)"
    --modif-color="$(rgba "$muted" ff)"
    --time-str='%I:%M %p'
    --date-str='%A  •  %B %d'
    --greeter-text='  session locked'
    --verif-text='checking…'
    --wrong-text='authentication failed'
    --noinput-text=''
    --lockfailed-text='lock failed'
    --time-font='MesloLGS Nerd Font Mono'
    --date-font='Fira Sans'
    --greeter-font='MesloLGS Nerd Font Mono'
    --verif-font='Fira Sans'
    --wrong-font='Fira Sans'
    --time-size=34
    --date-size=15
    --greeter-size=13
    --verif-size=13
    --wrong-size=13
    --ind-pos='x+w/2:y+h/2'
    --time-pos='x+w/2:y+h/2-28'
    --date-pos='x+w/2:y+h/2+28'
    --greeter-pos='x+w/2:y+h/2+150'
    --no-modkey-text
    --ignore-empty-password
    --show-failed-attempts
    --pass-media-keys
    --pass-screen-keys
)

if [[ "${I3LOCK_TEST_MODE:-0}" == "1" ]]; then
    arguments+=(--no-verify --nofork)
fi

exec i3lock "${arguments[@]}"

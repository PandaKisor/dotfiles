#!/usr/bin/env bash

set -euo pipefail

action="${1:-status}"
step="${BRIGHTNESS_STEP:-5}"
minimum="${BRIGHTNESS_MINIMUM:-0.30}"

[[ "$action" == "up" || "$action" == "down" || "$action" == "status" ]] || {
    printf 'Usage: %s {up|down|status}\n' "${0##*/}" >&2
    exit 2
}
[[ "$step" =~ ^[1-9][0-9]*$ ]] || step=5
[[ "$minimum" =~ ^0[.][0-9]+$ ]] || minimum=0.30

percentage=""

if command -v brightnessctl >/dev/null 2>&1 \
    && brightnessctl --class=backlight --machine-readable info >/dev/null 2>&1; then
    case "$action" in
        up)   brightnessctl --class=backlight --quiet set "${step}%+" ;;
        down) brightnessctl --class=backlight --quiet set "${step}%-" ;;
    esac
    percentage="$(
        brightnessctl --class=backlight --machine-readable info |
            awk -F, 'NR == 1 { gsub(/%/, "", $4); print $4 }'
    )"
elif command -v xbacklight >/dev/null 2>&1 \
    && xbacklight_value="$(xbacklight -get 2>/dev/null)" \
    && [[ "$xbacklight_value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
    case "$action" in
        up)   xbacklight -inc "$step" ;;
        down) xbacklight -dec "$step" ;;
    esac
    percentage="$(xbacklight -get | awk '{ printf "%d", $1 + 0.5 }')"
else
    # Desktop monitors often expose neither a kernel backlight nor XBacklight.
    # XRandR brightness is a software dimmer, clamped above black for safety.
    output="${BRIGHTNESS_OUTPUT:-$(
        xrandr --query | awk '
            / connected primary / { primary = $1 }
            / connected / && !candidate { candidate = $1 }
            END { if (primary) print primary; else if (candidate) print candidate }
        '
    )}"
    [[ -n "$output" ]] || {
        dunstify --app-name="System OSD" --expire-time=1600 \
            --stack-tag=brightness "Brightness unavailable" \
            "No controllable display was found."
        exit 1
    }

    current="$(
        xrandr --verbose | awk -v output="$output" '
            $1 == output && $2 == "connected" { active = 1; next }
            active && !found && $1 == "Brightness:" { print $2; found = 1 }
            active && /^[^[:space:]]/ { active = 0 }
        '
    )"
    [[ "$current" =~ ^[0-9]+([.][0-9]+)?$ ]] || current=1.0

    case "$action" in
        up)
            target="$(awk -v value="$current" -v step="$step" \
                'BEGIN { value += step / 100; if (value > 1) value = 1; printf "%.2f", value }')"
            ;;
        down)
            target="$(awk -v value="$current" -v step="$step" -v minimum="$minimum" \
                'BEGIN { value -= step / 100; if (value < minimum) value = minimum; printf "%.2f", value }')"
            ;;
        *) target="$current" ;;
    esac

    if [[ "$action" != "status" ]]; then
        xrandr --output "$output" --brightness "$target"
    fi
    percentage="$(awk -v value="$target" 'BEGIN { printf "%d", value * 100 + 0.5 }')"
fi

[[ "$percentage" =~ ^[0-9]+$ ]] || percentage=0
progress="$percentage"
(( progress > 100 )) && progress=100

dunstify \
    --app-name="System OSD" \
    --urgency=low \
    --expire-time=1200 \
    --stack-tag=brightness \
    --icon="display-brightness-symbolic" \
    --hint="int:value:${progress}" \
    "  Brightness" "${percentage}%"

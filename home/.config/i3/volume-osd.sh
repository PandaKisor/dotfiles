#!/usr/bin/env bash

set -euo pipefail

action="${1:-status}"
sink="${PULSE_SINK:-@DEFAULT_SINK@}"
step="${VOLUME_STEP:-5}"

[[ "$step" =~ ^[1-9][0-9]*$ ]] || step=5

case "$action" in
    up)   pactl set-sink-volume "$sink" "+${step}%" ;;
    down) pactl set-sink-volume "$sink" "-${step}%" ;;
    mute) pactl set-sink-mute "$sink" toggle ;;
    status) ;;
    *)
        printf 'Usage: %s {up|down|mute|status}\n' "${0##*/}" >&2
        exit 2
        ;;
esac

volume="$(
    pactl get-sink-volume "$sink" |
        awk '!found && match($0, /[0-9]+%/) {
            print substr($0, RSTART, RLENGTH - 1)
            found = 1
        }'
)"
muted="$(pactl get-sink-mute "$sink" | awk 'NR == 1 { print $2 }')"

[[ "$volume" =~ ^[0-9]+$ ]] || volume=0
progress="$volume"
(( progress > 100 )) && progress=100

if [[ "$muted" == "yes" ]]; then
    icon="audio-volume-muted-symbolic"
    summary="  Volume muted"
    body="Muted"
    progress=0
elif (( volume < 34 )); then
    icon="audio-volume-low-symbolic"
    summary="  Volume"
    body="${volume}%"
elif (( volume < 67 )); then
    icon="audio-volume-medium-symbolic"
    summary="  Volume"
    body="${volume}%"
else
    icon="audio-volume-high-symbolic"
    summary="  Volume"
    body="${volume}%"
fi

dunstify \
    --app-name="System OSD" \
    --urgency=low \
    --expire-time=1200 \
    --stack-tag=volume \
    --icon="$icon" \
    --hint="int:value:${progress}" \
    "$summary" "$body"

#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
rofi_config="$config_home/rofi/config.rasi"
rofi_popup="$config_home/i3/rofi-popup.sh"
volume_script="$config_home/i3/volume-osd.sh"
menu_theme='window { width: 30%; } listview { lines: 4; }'
sink='@DEFAULT_SINK@'

for command_name in pactl setsid; do
    command -v "$command_name" >/dev/null 2>&1 || exit 1
done
[[ -x "$rofi_popup" && -x "$volume_script" ]] || exit 1

volume="$(pactl get-sink-volume "$sink" 2>/dev/null \
    | awk '!found && match($0, /[0-9]+%/) {
        print substr($0, RSTART, RLENGTH - 1)
        found = 1
    }')"
muted="$(pactl get-sink-mute "$sink" 2>/dev/null | awk 'NR == 1 {print $2}')"
default_sink="$(pactl get-default-sink 2>/dev/null || true)"
[[ "$volume" =~ ^[0-9]+$ ]] || volume=0

if [[ "$muted" == yes ]]; then
    mute_row='  Unmute audio'
    status_message="Muted  ·  ${volume}%"
else
    mute_row='  Mute audio'
    status_message="Volume ${volume}%"
fi
[[ -n "$default_sink" ]] && status_message+="  ·  $default_sink"

rows=(
    "$mute_row"
    '  Volume down 5%'
    '  Volume up 5%'
    '  Advanced audio mixer'
)

selection="$(printf '%s\n' "${rows[@]}" | "$rofi_popup" \
    -dmenu -only-match -no-sort -format i \
    -p 'Audio' -mesg "$status_message" \
    -config "$rofi_config" -theme-str "$menu_theme")" || exit 0
[[ "$selection" =~ ^[0-9]+$ ]] || exit 0

case "$selection" in
    0) "$volume_script" mute ;;
    1) "$volume_script" down ;;
    2) "$volume_script" up ;;
    3)
        if command -v pavucontrol >/dev/null 2>&1; then
            setsid -f pavucontrol </dev/null >/dev/null 2>&1
        fi
        ;;
esac

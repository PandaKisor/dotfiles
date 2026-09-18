#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
if [[ -r "$config_home/i3/wallpaper.env" ]]; then
    # shellcheck source=/dev/null
    source "$config_home/i3/wallpaper.env"
fi
rofi_config="$config_home/rofi/config.rasi"
rofi_popup="$config_home/i3/rofi-popup.sh"
wallpaper_script="$config_home/i3/live-wallpaper.sh"
lock_script="$config_home/i3/lock-screen.sh"
notification_script="$config_home/i3/notification-center.sh"
network_script="$config_home/i3/network-menu.sh"
bluetooth_script="$config_home/i3/bluetooth-menu.sh"
audio_script="$config_home/i3/audio-menu.sh"
wallpaper_controls="$config_home/i3/wallpaper-controls.sh"
source "$wallpaper_controls"

menu_theme='window { width: 32%; } listview { lines: 13; } entry { placeholder: "Search controls..."; }'
confirm_theme='window { width: 28%; } inputbar { children: [ prompt ]; } listview { lines: 2; }'

notify_error() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Control Center" -u normal "Control Center" "$1"
    fi
}

launch_detached() {
    setsid -f "$@" </dev/null >/dev/null 2>&1
}

confirm_action() {
    local verb="$1"
    local message="$2"
    local confirmation="Yes, $verb"
    local answer

    answer="$(printf 'Cancel\n%s\n' "$confirmation" | "$rofi_popup" \
        -dmenu -only-match -no-sort -selected-row 0 \
        -p "Confirm" -mesg "$message" \
        -config "$rofi_config" -theme-str "$confirm_theme")" || exit 0
    [[ "$answer" == "$confirmation" ]]
}

[[ -x "$rofi_popup" ]] || exit 1

network_action="  Network"
if command -v nmcli >/dev/null 2>&1; then
    active_connection="$(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null |
        awk -F: '$1 != "loopback" {print $2; exit}')"
    [[ -n "$active_connection" ]] && network_action+="  ·  $active_connection"
fi

bluetooth_action="  Bluetooth"
if command -v bluetoothctl >/dev/null 2>&1; then
    bluetooth_power="$(bluetoothctl show 2>/dev/null |
        awk -F': ' '/Powered:/ {print $2; exit}')"
    [[ "$bluetooth_power" == "yes" ]] && bluetooth_power="on"
    [[ "$bluetooth_power" == "no" ]] && bluetooth_power="off"
    [[ -n "$bluetooth_power" ]] && bluetooth_action+="  ·  $bluetooth_power"
fi

notifications_action="  Notifications  ·  on"
if command -v dunstctl >/dev/null 2>&1 \
    && [[ "$(dunstctl is-paused 2>/dev/null)" == "true" ]]; then
    notifications_action="  Notifications  ·  paused"
fi

lock_action="  Lock screen"
audio_action="  Audio controls"
wallpaper_action="  Next wallpaper"
timer_action="  Pause wallpaper timer"
[[ -e "$rotation_pause_file" ]] && timer_action="  Resume wallpaper timer"
animation_action="  Pause animation (still frame)"
[[ -e "$animation_pause_file" ]] && animation_action="  Resume wallpaper animation"
refresh_action="  Refresh desktop"
suspend_action="  Suspend"
logout_action="  Log out"
reboot_action="  Reboot"
poweroff_action="  Shut down"

actions=(
    "$lock_action"
    "$audio_action"
    "$network_action"
    "$bluetooth_action"
    "$notifications_action"
    "$wallpaper_action"
)
[[ "${WALLPAPER_INTERVAL:-${VIDEO_WALLPAPER_INTERVAL:-1800}}" == 0 ]] || actions+=("$timer_action")
case "${WALLPAPER_MODE:-auto}" in
    image|images|static) ;;
    *) actions+=("$animation_action") ;;
esac
actions+=(
    "$refresh_action"
    "$suspend_action"
    "$logout_action"
    "$reboot_action"
    "$poweroff_action"
)

selection="$(printf '%s\n' "${actions[@]}" | "$rofi_popup" \
    -dmenu -i -only-match -no-sort \
    -p "Control" -mesg "System and session controls" \
    -config "$rofi_config" -theme-str "$menu_theme")" || exit 0

case "$selection" in
    "$lock_action")
        [[ -x "$lock_script" ]] && exec "$lock_script"
        notify_error "Lock-screen script is unavailable."
        ;;
    "$audio_action")
        if [[ -x "$audio_script" ]]; then
            exec "$audio_script"
        else
            notify_error "Audio controls are unavailable."
        fi
        ;;
    "$network_action")
        if [[ -x "$network_script" ]]; then
            exec "$network_script"
        elif command -v nm-connection-editor >/dev/null 2>&1; then
            launch_detached nm-connection-editor
        elif command -v nmtui >/dev/null 2>&1 && command -v alacritty >/dev/null 2>&1; then
            launch_detached alacritty --title "Network controls" -e nmtui
        else
            notify_error "No supported network editor is installed."
        fi
        ;;
    "$bluetooth_action")
        if [[ -x "$bluetooth_script" ]]; then
            exec "$bluetooth_script"
        elif command -v blueman-manager >/dev/null 2>&1; then
            launch_detached blueman-manager
        elif command -v bluetoothctl >/dev/null 2>&1 && command -v alacritty >/dev/null 2>&1; then
            launch_detached alacritty --title "Bluetooth controls" -e bluetoothctl
        else
            notify_error "No supported Bluetooth manager is installed."
        fi
        ;;
    "$notifications_action")
        if [[ -x "$notification_script" ]]; then
            exec "$notification_script"
        else
            notify_error "Notification center is unavailable."
        fi
        ;;
    "$wallpaper_action")
        if [[ -x "$wallpaper_script" ]]; then
            launch_detached "$wallpaper_script" --next
        else
            notify_error "Wallpaper selector is unavailable."
        fi
        ;;
    "$refresh_action")
        i3-msg restart >/dev/null
        ;;
    "$timer_action")
        exec "$wallpaper_controls" toggle-timer
        ;;
    "$animation_action")
        exec "$wallpaper_controls" toggle-animation
        ;;
    "$suspend_action")
        confirm_action "suspend" "Pause this session and put the computer to sleep?" \
            && systemctl suspend
        ;;
    "$logout_action")
        confirm_action "log out" "Close the current i3 session?" \
            && i3-msg exit >/dev/null
        ;;
    "$reboot_action")
        confirm_action "reboot" "Close applications and restart the computer?" \
            && systemctl reboot
        ;;
    "$poweroff_action")
        confirm_action "shut down" "Close applications and power off the computer?" \
            && systemctl poweroff
        ;;
esac

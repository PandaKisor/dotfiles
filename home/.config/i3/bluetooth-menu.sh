#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
rofi_config="$config_home/rofi/config.rasi"
rofi_popup="$config_home/i3/rofi-popup.sh"
menu_theme='window { width: 36%; } listview { lines: 10; } entry { placeholder: "Filter devices..."; }'
detail_theme='window { width: 32%; } listview { lines: 7; }'
confirm_theme='window { width: 28%; } inputbar { children: [ prompt ]; } listview { lines: 2; }'

for command_name in bluetoothctl; do
    command -v "$command_name" >/dev/null 2>&1 || {
        command -v notify-send >/dev/null 2>&1 \
            && notify-send -a 'Bluetooth' -u normal 'Bluetooth' "Required command not found: $command_name"
        exit 1
    }
done
[[ -x "$rofi_popup" ]] || exit 1

notify_result() {
    local summary="$1"
    local body="$2"
    local urgency="${3:-normal}"

    command -v notify-send >/dev/null 2>&1 \
        && notify-send -a 'Bluetooth' -u "$urgency" "$summary" "$body"
}

controller_available() {
    bluetoothctl show 2>/dev/null | grep -q '^Controller '
}

controller_powered() {
    [[ "$(bluetoothctl show 2>/dev/null | awk -F': ' '/Powered:/ {print $2; exit}')" == yes ]]
}

device_property() {
    local address="$1"
    local property="$2"

    bluetoothctl info "$address" 2>/dev/null \
        | awk -F': ' -v property="$property" '$1 ~ "^[[:space:]]*" property "$" {print $2; exit}'
}

run_device_action() {
    local verb="$1"
    local address="$2"
    local name="$3"

    if bluetoothctl --timeout 30 "$verb" "$address" >/dev/null 2>&1; then
        notify_result 'Bluetooth' "${verb^} succeeded for $name."
        return 0
    fi
    notify_result 'Bluetooth action failed' "Could not $verb $name." critical
    return 1
}

pair_device() {
    local address="$1"
    local name="$2"

    if bluetoothctl --timeout 30 --agent NoInputNoOutput pair "$address" \
        >/dev/null 2>&1; then
        bluetoothctl trust "$address" >/dev/null 2>&1 || true
        notify_result 'Bluetooth paired' "$name"
        return 0
    fi

    notify_result 'Interactive pairing required' \
        "$name needs confirmation or a passkey; opening Bluetooth in a terminal."
    if command -v alacritty >/dev/null 2>&1; then
        setsid -f alacritty \
            --title "Pair $name" \
            --option 'window.dynamic_title=false' \
            --hold --command bluetoothctl --agent KeyboardDisplay pair "$address" \
            </dev/null >/dev/null 2>&1
    fi
}

confirm_remove() {
    local name="$1"
    local answer

    answer="$(printf 'Cancel\nYes, remove device\n' | "$rofi_popup" \
        -dmenu -only-match -no-sort -selected-row 0 \
        -p 'Confirm' -mesg "Forget $name?" \
        -config "$rofi_config" -theme-str "$confirm_theme")" || exit 0
    [[ "$answer" == 'Yes, remove device' ]]
}

device_menu() {
    local address="$1"
    local name="$2"
    local connected paired trusted selection
    local -a rows actions

    connected="$(device_property "$address" Connected)"
    paired="$(device_property "$address" Paired)"
    trusted="$(device_property "$address" Trusted)"
    rows=('  Back')
    actions=(back)

    if [[ "$connected" == yes ]]; then
        rows+=('󰂲  Disconnect')
        actions+=(disconnect)
    else
        rows+=('󰂱  Connect')
        actions+=(connect)
    fi
    if [[ "$paired" != yes ]]; then
        rows+=('  Pair')
        actions+=(pair)
    fi
    if [[ "$trusted" == yes ]]; then
        rows+=('󰌾  Untrust')
        actions+=(untrust)
    else
        rows+=('󰌾  Trust')
        actions+=(trust)
    fi
    rows+=('  Interactive pairing' '  Remove device')
    actions+=(interactive remove)

    selection="$(printf '%s\n' "${rows[@]}" | "$rofi_popup" \
        -dmenu -only-match -no-sort -format i \
        -p 'Bluetooth' \
        -mesg "$name  ·  $address" \
        -config "$rofi_config" -theme-str "$detail_theme")" || exit 0
    [[ "$selection" =~ ^[0-9]+$ ]] || exit 0

    case "${actions[$selection]}" in
        back) return 0 ;;
        connect) run_device_action connect "$address" "$name" ;;
        disconnect) run_device_action disconnect "$address" "$name" ;;
        pair) pair_device "$address" "$name" ;;
        trust) run_device_action trust "$address" "$name" ;;
        untrust) run_device_action untrust "$address" "$name" ;;
        interactive)
            if command -v alacritty >/dev/null 2>&1; then
                setsid -f alacritty \
                    --title "Pair $name" \
                    --option 'window.dynamic_title=false' \
                    --hold --command bluetoothctl --agent KeyboardDisplay pair "$address" \
                    </dev/null >/dev/null 2>&1
            else
                notify_result 'Bluetooth' 'Alacritty is not installed.'
            fi
            ;;
        remove)
            if confirm_remove "$name"; then
                run_device_action remove "$address" "$name"
            fi
            ;;
    esac
}

print_status() {
    local power connected=0 line address name

    controller_available || {
        printf 'controller=none\npowered=no\nconnected=0\n'
        return 0
    }
    controller_powered && power=yes || power=no
    while IFS= read -r line; do
        [[ "$line" == Device\ * ]] || continue
        read -r _ address name <<< "$line"
        [[ "$(device_property "$address" Connected)" == yes ]] && ((connected++))
    done < <(bluetoothctl devices 2>/dev/null)
    printf 'controller=present\npowered=%s\nconnected=%s\n' "$power" "$connected"
}

show_menu() {
    local line address name connected paired marker selection
    local -a rows actions addresses names
    local -A seen_addresses

    controller_available || {
        notify_result 'Bluetooth unavailable' 'No Bluetooth controller is available.' critical
        return 1
    }

    rows=()
    actions=()
    addresses=()
    names=()
    seen_addresses=()

    if controller_powered; then
        rows+=('  Turn Bluetooth off' '  Scan for 8 seconds')
        actions+=(power-off scan)
        addresses+=("" "")
        names+=("" "")
    else
        rows+=('  Turn Bluetooth on')
        actions+=(power-on)
        addresses+=("")
        names+=("")
    fi

    if controller_powered; then
        while IFS= read -r line; do
            [[ "$line" == Device\ * ]] || continue
            address="${line#Device }"
            name="${address#* }"
            address="${address%% *}"
            [[ "$address" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || continue
            [[ -z "${seen_addresses[$address]:-}" ]] || continue
            seen_addresses[$address]=1
            [[ -n "$name" ]] || name="$address"
            connected="$(device_property "$address" Connected)"
            paired="$(device_property "$address" Paired)"
            if [[ "$connected" == yes ]]; then
                marker=''
            elif [[ "$paired" == yes ]]; then
                marker=''
            else
                marker=''
            fi
            rows+=("$marker  $name  ·  $address")
            actions+=(device)
            addresses+=("$address")
            names+=("$name")
        done < <(bluetoothctl devices 2>/dev/null)
    fi

    selection="$(printf '%s\n' "${rows[@]}" | "$rofi_popup" \
        -dmenu -i -only-match -no-sort -format i \
        -p 'Bluetooth' \
        -mesg "$(controller_powered && printf 'Controller powered on' || printf 'Controller powered off')" \
        -config "$rofi_config" -theme-str "$menu_theme")" || exit 0
    [[ "$selection" =~ ^[0-9]+$ ]] || exit 0

    case "${actions[$selection]}" in
        power-on) bluetoothctl power on >/dev/null 2>&1 || notify_result 'Bluetooth' 'Could not enable the controller.' critical ;;
        power-off) bluetoothctl power off >/dev/null 2>&1 || notify_result 'Bluetooth' 'Could not disable the controller.' critical ;;
        scan)
            notify_result 'Bluetooth scan' 'Scanning for nearby devices for 8 seconds.'
            bluetoothctl --timeout 8 scan on >/dev/null 2>&1 \
                || notify_result 'Bluetooth scan' 'The scan did not complete.' critical
            ;;
        device) device_menu "${addresses[$selection]}" "${names[$selection]}" ;;
    esac
}

case "${1:-menu}" in
    menu) show_menu ;;
    status) print_status ;;
    *)
        printf 'Usage: %s {menu|status}\n' "${0##*/}" >&2
        exit 2
        ;;
esac

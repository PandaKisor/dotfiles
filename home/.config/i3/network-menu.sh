#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
rofi_config="$config_home/rofi/config.rasi"
rofi_popup="$config_home/i3/rofi-popup.sh"
menu_theme='window { width: 36%; } listview { lines: 10; } entry { placeholder: "Filter networks..."; }'
prompt_theme='window { width: 30%; } listview { lines: 1; }'

for command_name in nmcli; do
    command -v "$command_name" >/dev/null 2>&1 || {
        command -v notify-send >/dev/null 2>&1 \
            && notify-send -a 'Wi-Fi' -u normal 'Wi-Fi' "Required command not found: $command_name"
        exit 1
    }
done
[[ -x "$rofi_popup" ]] || exit 1

notify_result() {
    local summary="$1"
    local body="$2"
    local urgency="${3:-normal}"

    command -v notify-send >/dev/null 2>&1 \
        && notify-send -a 'Wi-Fi' -u "$urgency" "$summary" "$body"
}

launch_editor() {
    if command -v nm-connection-editor >/dev/null 2>&1; then
        setsid -f nm-connection-editor </dev/null >/dev/null 2>&1
    else
        notify_result 'Wi-Fi' 'NetworkManager connection editor is not installed.'
    fi
}

# nmcli escapes colons and backslashes in terse output. Split a record without
# corrupting SSIDs such as "Lab:Guest" or names containing a literal backslash.
split_nmcli_record() {
    local record="$1"
    local character field='' escaped=0 index

    nmcli_fields=()
    for ((index = 0; index < ${#record}; index++)); do
        character="${record:index:1}"
        if (( escaped == 1 )); then
            field+="$character"
            escaped=0
        elif [[ "$character" == '\' ]]; then
            escaped=1
        elif [[ "$character" == ':' ]]; then
            nmcli_fields+=("$field")
            field=''
        else
            field+="$character"
        fi
    done
    (( escaped == 1 )) && field+='\'
    nmcli_fields+=("$field")
}

wifi_device() {
    local record

    while IFS= read -r record; do
        split_nmcli_record "$record"
        if [[ "${nmcli_fields[1]:-}" == wifi ]]; then
            printf '%s' "${nmcli_fields[0]}"
            return 0
        fi
    done < <(nmcli --terse --fields DEVICE,TYPE device status 2>/dev/null)
    return 1
}

wifi_enabled() {
    [[ "$(nmcli --terse --fields WIFI general 2>/dev/null | head -n 1)" == enabled ]]
}

known_profile_uuid() {
    local requested_ssid="$1"
    local record uuid type profile_ssid

    while IFS= read -r record; do
        split_nmcli_record "$record"
        uuid="${nmcli_fields[0]:-}"
        type="${nmcli_fields[1]:-}"
        [[ "$type" == 802-11-wireless || "$type" == wifi ]] || continue
        profile_ssid="$(nmcli --escape no --get-values 802-11-wireless.ssid \
            connection show uuid "$uuid" 2>/dev/null | head -n 1)"
        if [[ "$profile_ssid" == "$requested_ssid" ]]; then
            printf '%s' "$uuid"
            return 0
        fi
    done < <(nmcli --terse --fields UUID,TYPE connection show 2>/dev/null)
    return 1
}

prompt_value() {
    local prompt="$1"
    local message="$2"
    local password_mode="${3:-0}"
    local arguments=(
        -dmenu -p "$prompt" -mesg "$message"
        -config "$rofi_config" -theme-str "$prompt_theme"
    )

    (( password_mode == 1 )) && arguments+=(-password)
    printf '\n' | "$rofi_popup" "${arguments[@]}"
}

activate_wifi() {
    local ssid="$1"
    local security="$2"
    local profile_uuid='' wifi_password=''

    if [[ "$security" == *802.1X* ]]; then
        notify_result 'Advanced Wi-Fi required' \
            "$ssid uses enterprise authentication; opening the connection editor."
        launch_editor
        return 0
    fi

    if profile_uuid="$(known_profile_uuid "$ssid")"; then
        if nmcli --wait 25 connection up uuid "$profile_uuid" >/dev/null 2>&1; then
            notify_result 'Wi-Fi connected' "$ssid"
            return 0
        fi

        wifi_password="$(prompt_value 'Password' "Update credentials for $ssid" 1)" || return 0
        [[ -n "$wifi_password" ]] || return 0
        if printf 'wifi-sec.psk:%s\n' "$wifi_password" \
            | nmcli --wait 30 connection up uuid "$profile_uuid" \
                passwd-file /dev/stdin >/dev/null 2>&1; then
            unset wifi_password
            notify_result 'Wi-Fi connected' "$ssid"
            return 0
        fi
        unset wifi_password
    elif [[ -z "$security" || "$security" == '--' ]]; then
        if nmcli --wait 25 device wifi connect "$ssid" >/dev/null 2>&1; then
            notify_result 'Wi-Fi connected' "$ssid"
            return 0
        fi
    else
        wifi_password="$(prompt_value 'Password' "Credentials for $ssid" 1)" || return 0
        [[ -n "$wifi_password" ]] || return 0
        # --ask consumes the secret from stdin. It never appears in nmcli's
        # process arguments or in a temporary file.
        if printf '%s\n' "$wifi_password" \
            | nmcli --ask --wait 30 device wifi connect "$ssid" \
                >/dev/null 2>&1; then
            unset wifi_password
            notify_result 'Wi-Fi connected' "$ssid"
            return 0
        fi
        unset wifi_password
    fi

    notify_result 'Wi-Fi connection failed' \
        "NetworkManager could not connect to $ssid." critical
    return 1
}

connect_hidden() {
    local ssid security wifi_password

    ssid="$(prompt_value 'Hidden SSID' 'Enter the exact network name')" || return 0
    [[ -n "$ssid" ]] || return 0
    security="$(printf 'Secured\nOpen\n' | "$rofi_popup" \
        -dmenu -only-match -no-sort -p 'Security' \
        -config "$rofi_config" -theme-str "$prompt_theme")" || return 0

    if [[ "$security" == Open ]]; then
        if nmcli --wait 25 device wifi connect "$ssid" hidden yes >/dev/null 2>&1; then
            notify_result 'Wi-Fi connected' "$ssid"
        else
            notify_result 'Wi-Fi connection failed' \
                "NetworkManager could not connect to $ssid." critical
        fi
        return 0
    fi

    wifi_password="$(prompt_value 'Password' "Credentials for $ssid" 1)" || return 0
    [[ -n "$wifi_password" ]] || return 0
    if printf '%s\n' "$wifi_password" \
        | nmcli --ask --wait 30 device wifi connect "$ssid" hidden yes \
            >/dev/null 2>&1; then
        notify_result 'Wi-Fi connected' "$ssid"
    else
        notify_result 'Wi-Fi connection failed' \
            "NetworkManager could not connect to $ssid." critical
    fi
    unset wifi_password
}

print_status() {
    local device state active

    device="$(wifi_device 2>/dev/null || true)"
    if wifi_enabled; then
        state=enabled
    else
        state=disabled
    fi
    active="$(nmcli --escape no --terse --fields ACTIVE,SSID device wifi list \
        --rescan no 2>/dev/null | sed -n 's/^yes://p' | head -n 1)"
    printf 'wifi=%s\ndevice=%s\nactive=%s\n' "$state" "${device:-none}" "${active:-none}"
}

show_menu() {
    local device active_ssid='' record active ssid security signal marker lock
    local selection selection_kind selection_value selection_security
    local -a menu_rows row_kinds row_values row_security
    local -A seen_ssids=()

    device="$(wifi_device 2>/dev/null || true)"
    [[ -n "$device" ]] || {
        notify_result 'Wi-Fi unavailable' 'NetworkManager reports no Wi-Fi device.' critical
        return 1
    }

    menu_rows=()
    row_kinds=()
    row_values=()
    row_security=()

    if wifi_enabled; then
        menu_rows+=('  Turn Wi-Fi off' '  Rescan networks')
        row_kinds+=(power-off rescan)
        row_values+=('' '')
        row_security+=('' '')

        active_ssid="$(nmcli --escape no --terse --fields ACTIVE,SSID \
            device wifi list --rescan no 2>/dev/null \
            | sed -n 's/^yes://p' | head -n 1)"
        if [[ -n "$active_ssid" ]]; then
            menu_rows+=('󰖪  Disconnect current network')
            row_kinds+=(disconnect)
            row_values+=("")
            row_security+=("")
        fi
        menu_rows+=('󰘊  Connect to hidden network')
        row_kinds+=(hidden)
        row_values+=("")
        row_security+=("")
    else
        active_ssid=''
        menu_rows+=('  Turn Wi-Fi on')
        row_kinds+=(power-on)
        row_values+=("")
        row_security+=("")
    fi

    menu_rows+=('  Advanced connection editor')
    row_kinds+=(editor)
    row_values+=("")
    row_security+=("")

    if wifi_enabled; then
        seen_ssids=()
        while IFS= read -r record; do
            split_nmcli_record "$record"
            active="${nmcli_fields[0]:-no}"
            ssid="${nmcli_fields[1]:-}"
            security="${nmcli_fields[2]:-}"
            signal="${nmcli_fields[3]:-0}"
            [[ -n "$ssid" && -z "${seen_ssids[$ssid]:-}" ]] || continue
            seen_ssids[$ssid]=1
            [[ "$signal" =~ ^[0-9]+$ ]] || signal=0
            [[ "$active" == yes ]] && marker='' || marker=''
            [[ -z "$security" || "$security" == '--' ]] && lock='open' || lock='secured'
            menu_rows+=("$marker  $ssid  ·  $signal%  ·  $lock")
            row_kinds+=(network)
            row_values+=("$ssid")
            row_security+=("$security")
        done < <(nmcli --terse --fields ACTIVE,SSID,SECURITY,SIGNAL \
            device wifi list --rescan no 2>/dev/null)
    fi

    selection="$(printf '%s\n' "${menu_rows[@]}" | "$rofi_popup" \
        -dmenu -i -only-match -no-sort -format i \
        -p 'Wi-Fi' \
        -mesg "${active_ssid:+Connected to $active_ssid}${active_ssid:-Not connected}" \
        -config "$rofi_config" -theme-str "$menu_theme")" || exit 0
    [[ "$selection" =~ ^[0-9]+$ ]] || exit 0

    selection_kind="${row_kinds[$selection]}"
    selection_value="${row_values[$selection]}"
    selection_security="${row_security[$selection]}"
    case "$selection_kind" in
        power-on) nmcli radio wifi on >/dev/null 2>&1 || notify_result 'Wi-Fi' 'Could not enable Wi-Fi.' critical ;;
        power-off) nmcli radio wifi off >/dev/null 2>&1 || notify_result 'Wi-Fi' 'Could not disable Wi-Fi.' critical ;;
        rescan) nmcli device wifi rescan ifname "$device" >/dev/null 2>&1 || notify_result 'Wi-Fi' 'Scan request failed.' critical ;;
        disconnect) nmcli device disconnect "$device" >/dev/null 2>&1 || notify_result 'Wi-Fi' 'Disconnect failed.' critical ;;
        hidden) connect_hidden ;;
        editor) launch_editor ;;
        network)
            if [[ "$selection_value" == "$active_ssid" ]]; then
                notify_result 'Wi-Fi' "Already connected to $active_ssid."
            else
                activate_wifi "$selection_value" "$selection_security"
            fi
            ;;
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

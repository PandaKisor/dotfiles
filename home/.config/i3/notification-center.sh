#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
rofi_config="$config_home/rofi/config.rasi"
rofi_popup="$config_home/i3/rofi-popup.sh"
menu_theme='window { width: 38%; } listview { lines: 10; } entry { placeholder: "Search notifications..."; }'
confirm_theme='window { width: 28%; } inputbar { children: [ prompt ]; } listview { lines: 2; }'

for command_name in dunstctl jq; do
    command -v "$command_name" >/dev/null 2>&1 || exit 1
done
[[ -x "$rofi_popup" ]] || exit 1

confirm_clear() {
    local answer

    answer="$(printf 'Cancel\nYes, clear history\n' | "$rofi_popup" \
        -dmenu -only-match -no-sort -selected-row 0 \
        -p "Confirm" -mesg "Remove every saved notification?" \
        -config "$rofi_config" -theme-str "$confirm_theme")" || exit 0
    [[ "$answer" == "Yes, clear history" ]]
}

paused="$(dunstctl is-paused 2>/dev/null)"
waiting_count="$(dunstctl count waiting 2>/dev/null)"
[[ "$waiting_count" =~ ^[0-9]+$ ]] || waiting_count=0

if [[ "$paused" == "true" ]]; then
    toggle_action="  Resume notifications"
    state_message="Do Not Disturb enabled  ·  $waiting_count waiting"
else
    toggle_action="  Enable Do Not Disturb"
    state_message="Notifications active"
fi

restore_action="  Restore latest"
close_action="  Close visible"
clear_action="  Clear history"

history_ids=()
history_rows=()
while IFS=$'\t' read -r notification_id notification_row; do
    [[ -n "$notification_id" && -n "$notification_row" ]] || continue
    history_ids+=("$notification_id")
    history_rows+=("  $notification_row")
done < <(
    dunstctl history 2>/dev/null | jq -r '
        def clean:
            (. // "")
            | gsub("<[^>]*>"; "")
            | gsub("[\\r\\n\\t]+"; " ")
            | gsub(" {2,}"; " ");
        .data[0]
        | map(select(.appname.data != "System OSD"))
        | .[:12]
        | .[]
        | (.appname.data | clean) as $app
        | (.summary.data | clean) as $summary
        | (.body.data | clean) as $body
        | [
            (.id.data | tostring),
            (((if $app == "" then "Notification" else $app end)
              + "  ·  " + (if $summary == "" then "Untitled" else $summary end)
              + (if $body == "" or $body == $summary then "" else "  —  " + $body end))[:110])
          ]
        | @tsv
    '
)

action_count=4
menu_rows=(
    "$toggle_action"
    "$restore_action"
    "$close_action"
    "$clear_action"
)
if (( ${#history_rows[@]} > 0 )); then
    menu_rows+=("${history_rows[@]}")
    state_message+="  ·  ${#history_rows[@]} saved"
else
    empty_row="—  No saved app notifications  —"
    menu_rows+=("$empty_row")
fi

selection_index="$(printf '%s\n' "${menu_rows[@]}" | "$rofi_popup" \
    -dmenu -i -only-match -no-sort -format i \
    -p "Notifications" -mesg "$state_message" \
    -config "$rofi_config" -theme-str "$menu_theme")" || exit 0

[[ "$selection_index" =~ ^[0-9]+$ ]] || exit 0

case "$selection_index" in
    0)
        dunstctl set-paused toggle
        ;;
    1)
        (( ${#history_ids[@]} > 0 )) && dunstctl history-pop "${history_ids[0]}"
        ;;
    2)
        dunstctl close-all
        ;;
    3)
        confirm_clear && dunstctl history-clear
        ;;
    *)
        history_index=$((selection_index - action_count))
        if (( history_index >= 0 && history_index < ${#history_ids[@]} )); then
            dunstctl history-pop "${history_ids[history_index]}"
        fi
        ;;
esac

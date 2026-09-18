#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
rofi_config="$config_home/rofi/config.rasi"
rofi_popup="$config_home/i3/rofi-popup.sh"
dev_directory="${DEV_WORKSPACE_DIR:-$HOME/dev}"
main_workspace='1:main'
media_workspace='2:media'
dev_workspace='3:dev'

[[ -d "$dev_directory" ]] || dev_directory="$HOME"

notify_error() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a 'Workspace session' -u normal 'Workspace session' "$1"
    fi
}

switch_workspace() {
    local workspace="$1"

    command -v i3-msg >/dev/null 2>&1 || return 1
    i3-msg "workspace \"$workspace\"" >/dev/null 2>&1
}

workspace_has_class() {
    local workspace="$1"
    local class_pattern="$2"

    command -v jq >/dev/null 2>&1 || return 1
    i3-msg -t get_tree 2>/dev/null | jq -e \
        --arg workspace "$workspace" \
        --arg class_pattern "$class_pattern" '
            .. | objects
            | select(.type? == "workspace" and .name == $workspace)
            | [.. | objects
                | (.window_properties?.class? // empty)
                | select(test($class_pattern; "i"))]
            | length > 0
        ' >/dev/null 2>&1
}

window_exists() {
    local class_pattern="$1"

    command -v jq >/dev/null 2>&1 || return 1
    i3-msg -t get_tree 2>/dev/null | jq -e \
        --arg class_pattern "$class_pattern" '
            [.. | objects
                | (.window_properties?.class? // empty)
                | select(test($class_pattern; "i"))]
            | length > 0
        ' >/dev/null 2>&1
}

launch_detached() {
    setsid -f "$@" </dev/null >/dev/null 2>&1
}

rename_workspaces() {
    local number target current

    command -v i3-msg >/dev/null 2>&1 || return 0
    command -v jq >/dev/null 2>&1 || return 0

    while read -r number target; do
        current="$(i3-msg -t get_workspaces 2>/dev/null \
            | jq -r --argjson number "$number" \
                '.[] | select(.num == $number) | .name' \
            | head -n 1)"
        if [[ -n "$current" && "$current" != "$target" ]]; then
            i3-msg "rename workspace \"$current\" to \"$target\"" \
                >/dev/null 2>&1 || true
        fi
    done <<EOF
1 $main_workspace
2 $media_workspace
3 $dev_workspace
EOF
}

game_session() {
    local choices=()
    local selection=''

    switch_workspace "$main_workspace" || exit 1

    command -v steam >/dev/null 2>&1 && choices+=('Steam')
    command -v heroic >/dev/null 2>&1 && choices+=('Heroic')

    if (( ${#choices[@]} == 0 )); then
        notify_error 'Neither Steam nor Heroic is installed.'
        return 1
    elif (( ${#choices[@]} == 1 )); then
        selection="${choices[0]}"
    elif [[ -x "$rofi_popup" ]]; then
        selection="$(printf '%s\n' "${choices[@]}" | "$rofi_popup" \
            -dmenu -i -only-match -no-sort \
            -p 'Play' -mesg 'Open a launcher on 1:main' \
            -config "$rofi_config" \
            -theme-str 'window { width: 24%; } listview { lines: 2; }')" || exit 0
    else
        notify_error 'Rofi is required to choose between Steam and Heroic.'
        return 1
    fi

    case "$selection" in
        Steam) launch_detached steam ;;
        Heroic) launch_detached heroic ;;
    esac
}

media_session() {
    switch_workspace "$media_workspace" || exit 1

    if ! workspace_has_class "$media_workspace" '^(discord|discordcanary|discordptb)$'; then
        if command -v discord >/dev/null 2>&1; then
            # Do not pull an existing Discord window away from another
            # workspace; only start it when it is not already open anywhere.
            window_exists '^(discord|discordcanary|discordptb)$' \
                || launch_detached discord
        else
            notify_error 'Discord is not installed.'
        fi
    fi

    if ! workspace_has_class "$media_workspace" '^(firefox|librewolf)$'; then
        if command -v firefox >/dev/null 2>&1; then
            # A separate browser window belongs to this requested session, but
            # remains freely movable afterward.
            launch_detached firefox --new-window about:home
        else
            notify_error 'Firefox is not installed.'
        fi
    fi
}

dev_session() {
    switch_workspace "$dev_workspace" || exit 1

    if ! workspace_has_class "$dev_workspace" '^Alacritty$'; then
        if command -v alacritty >/dev/null 2>&1; then
            launch_detached alacritty --working-directory "$dev_directory"
        else
            notify_error 'Alacritty is not installed.'
        fi
    fi
}

case "${1:-}" in
    names) rename_workspaces ;;
    game) game_session ;;
    media) media_session ;;
    dev) dev_session ;;
    *)
        printf 'Usage: %s {names|game|media|dev}\n' "${0##*/}" >&2
        exit 2
        ;;
esac

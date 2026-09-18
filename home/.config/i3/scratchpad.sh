#!/usr/bin/env bash

set -u

scratchpad_name="${1:-}"

notify_error() {
    local message="$1"

    printf '%s\n' "$message" >&2
    if command -v dunstify >/dev/null 2>&1; then
        dunstify \
            --appname='Scratchpads' \
            --urgency=critical \
            'Scratchpad could not open' \
            "$message" >/dev/null 2>&1 || true
    fi
}

for command_name in i3-msg jq setsid; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        notify_error "Required command not found: $command_name"
        exit 1
    fi
done

case "$scratchpad_name" in
    terminal)
        mark_name=scratchpad-terminal
        class_pattern='^ScratchpadTerminal$'
        i3_selector='[class="(?i)^ScratchpadTerminal$"]'
        width='72 ppt'
        height='54 ppt'
        required_app=alacritty
        install_hint='Install Alacritty to use the terminal scratchpad.'
        launch_command=(
            alacritty
            --class ScratchpadTerminal,ScratchpadTerminal
            --title 'Scratchpad Terminal'
        )
        ;;
    calculator)
        mark_name=scratchpad-calculator
        class_pattern='^Qalculate-gtk$'
        i3_selector='[class="(?i)^Qalculate-gtk$"]'
        width='420 px'
        height='560 px'
        required_app=qalculate-gtk
        install_hint='Install the qalculate-gtk package to use the calculator scratchpad.'
        launch_command=(qalculate-gtk)
        ;;
    audio)
        mark_name=scratchpad-audio
        class_pattern='^Pavucontrol$'
        i3_selector='[class="(?i)^Pavucontrol$"]'
        width='760 px'
        height='560 px'
        required_app=pavucontrol
        install_hint='Install Pavucontrol to use the audio scratchpad.'
        launch_command=(pavucontrol)
        ;;
    *)
        notify_error 'Usage: scratchpad.sh {terminal|calculator|audio}'
        exit 2
        ;;
esac

if ! command -v "$required_app" >/dev/null 2>&1; then
    notify_error "$install_hint"
    exit 1
fi

tree_contains_mark() {
    i3-msg -t get_tree 2>/dev/null \
        | jq -e --arg mark "$mark_name" \
            '.. | objects | select((.marks? // []) | index($mark))' \
            >/dev/null
}

tree_contains_class() {
    i3-msg -t get_tree 2>/dev/null \
        | jq -e --arg pattern "$class_pattern" '
            .. | objects
            | select(.window? != null)
            | select((.window_properties.class? // "") | test($pattern; "i"))
        ' >/dev/null
}

toggle_scratchpad() {
    i3-msg \
        "$i3_selector scratchpad show" \
        >/dev/null
}

hide_scratchpad() {
    i3-msg \
        "$i3_selector move scratchpad" \
        >/dev/null
}

adopt_window_as_scratchpad() {
    i3-msg \
        "$i3_selector mark --add $mark_name, floating enable, border pixel 2, resize set $width $height, move position center" \
        >/dev/null \
        && hide_scratchpad \
        && toggle_scratchpad
}

if tree_contains_mark; then
    toggle_scratchpad
    exit
fi

if tree_contains_class; then
    adopt_window_as_scratchpad
    exit
fi

setsid -f "${launch_command[@]}"

# Adopt the new client after it publishes its X11 class. This also avoids a
# second key press on first use without relying on an application startup time.
for _ in {1..80}; do
    if tree_contains_class; then
        adopt_window_as_scratchpad
        exit
    fi
    sleep 0.05
done

notify_error "Timed out waiting for the $scratchpad_name scratchpad window."
exit 1

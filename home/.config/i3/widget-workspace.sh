#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
if [[ -r "$config_home/i3/desktop.env" ]]; then
    # shellcheck source=/dev/null
    source "$config_home/i3/desktop.env"
fi
cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
widget_state="$state_home/i3/widgets"
widget_cache="$cache_home/i3-widgets"
log_file="$widget_state/widgets.log"
cava_config="$widget_cache/cava.conf"
conky_config="$config_home/conky/widget.conf"
workspace="10:widgets"

if [[ ! -d "$runtime_dir" || ! -w "$runtime_dir" ]]; then
    runtime_dir=/tmp
fi

mkdir -p -- "$widget_state" "$widget_cache"

# Older launchers passed i3-widgets-$UID.lock to long-lived calendar/terminal
# children. Use a launcher-only lock so recovery works without closing them.
widget_lock="$runtime_dir/i3-widget-launch-$UID.lock"
widget_monitor_lock="$runtime_dir/i3-widget-monitor-$UID.lock"

launch_without_lock() {
    # Called in a background subshell: keep the parent's lock until all cards
    # have been checked, but never let an application inherit it.
    if [[ -n "${widget_lock_fd:-}" ]]; then
        exec {widget_lock_fd}>&-
    fi
    exec "$@"
}

palette_color() {
    local key="$1"
    local fallback="$2"
    local palette="$cache_home/wal/colors.sh"
    local value=""

    if [[ -r "$palette" ]]; then
        value="$(sed -n "s/^${key}='\(#[[:xdigit:]]\{6\}\)'$/\1/p" "$palette" | head -n 1)"
    fi
    if [[ "$value" =~ ^#[[:xdigit:]]{6}$ ]]; then
        printf '%s' "$value"
    else
        printf '%s' "$fallback"
    fi
}

render_cava_config() {
    [[ "${CAVA_ENABLED:-1}" != 0 ]] || return 0
    local background foreground color4 color5 color6 color12 temporary

    background="$(palette_color background '#0B1118')"
    foreground="$(palette_color foreground '#D8DEE9')"
    color4="$(palette_color color4 '#5E81AC')"
    color5="$(palette_color color5 '#B48EAD')"
    color6="$(palette_color color6 '#88C0D0')"
    color12="$(palette_color color12 '#81A1C1')"
    temporary="$(mktemp --tmpdir="$widget_cache" .cava.XXXXXX)"

    {
        printf '%s\n' \
            '[general]' \
            'live-config = 1' \
            'framerate = 60' \
            'autosens = 1' \
            'sensitivity = 100' \
            'bars = 0' \
            'bar_width = 2' \
            'bar_spacing = 1' \
            'center_align = 1' \
            'max_height = 92' \
            '' \
            '[input]' \
            'method = pipewire' \
            'source = auto' \
            '' \
            '[output]' \
            'method = noncurses' \
            'orientation = bottom' \
            'channels = stereo' \
            'synchronized_sync = 1' \
            'show_idle_bar_heads = 0' \
            '' \
            '[color]'
        printf "background = '%s'\n" "$background"
        printf "foreground = '%s'\n" "$foreground"
        printf '%s\n' 'gradient = 1'
        printf "gradient_color_1 = '%s'\n" "$color4"
        printf "gradient_color_2 = '%s'\n" "$color6"
        printf "gradient_color_3 = '%s'\n" "$color12"
        printf "gradient_color_4 = '%s'\n" "$color5"
        printf "gradient_color_5 = '%s'\n" "$foreground"
        printf '%s\n' 'horizontal_gradient = 1'
        printf "horizontal_gradient_color_1 = '%s'\n" "$color4"
        printf "horizontal_gradient_color_2 = '%s'\n" "$color6"
        printf "horizontal_gradient_color_3 = '%s'\n" "$color12"
        printf "horizontal_gradient_color_4 = '%s'\n" "$color5"
        printf "horizontal_gradient_color_5 = '%s'\n" "$foreground"
        printf '%s\n' "blend_direction = 'up'"
        printf '%s\n' '' '[smoothing]' 'monstercat = 1' 'waves = 0' 'noise_reduction = 74'
    } > "$temporary"
    # The monitor calls ensure every five seconds. Replacing an identical
    # config triggers Cava's live reload and resets the running visualizer.
    if cmp -s -- "$temporary" "$cava_config"; then
        rm -f -- "$temporary"
    else
        mv -- "$temporary" "$cava_config"
    fi
}

process_matches() {
    local pid_file="$1"
    local marker="$2"
    local pid command_line

    [[ -r "$pid_file" ]] || return 1
    read -r pid < "$pid_file"
    [[ "$pid" =~ ^[0-9]+$ ]] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    command_line="$(tr '\0' ' ' 2>/dev/null < "/proc/$pid/cmdline")"
    [[ "$command_line" == *"$marker"* ]]
}

window_exists() {
    local class="$1"

    command -v i3-msg >/dev/null 2>&1 || return 1
    command -v jq >/dev/null 2>&1 || return 1
    i3-msg -t get_tree 2>/dev/null \
        | jq -e --arg class "$class" \
            '.. | objects | select(.window_properties?.class? == $class)' \
            >/dev/null 2>&1
}

launch_terminal_widget() {
    local key="$1"
    local class="$2"
    local title="$3"
    shift 3

    window_exists "$class" && return 0
    process_matches "$widget_state/$key-window.pid" "--class $class,$class" && return 0

    launch_without_lock alacritty \
        --class "$class,$class" \
        --title "$title" \
        --option 'window.dynamic_title=false' \
        "$@" >> "$log_file" 2>&1 &
    printf '%s\n' "$!" > "$widget_state/$key-window.pid"
}

launch_conky() {
    window_exists i3-widget-system && return 0
    process_matches "$widget_state/conky.pid" "$conky_config" && return 0

    launch_without_lock conky --quiet --config="$conky_config" >> "$log_file" 2>&1 &
    printf '%s\n' "$!" > "$widget_state/conky.pid"
}

place_conky() {
    local _

    command -v i3-msg >/dev/null 2>&1 || return 0
    for _ in {1..30}; do
        if window_exists i3-widget-system; then
            # Conky changes its size once after the first 1.5-second update.
            # Apply the i3 card geometry after that placeholder transition.
            sleep 2
            break
        fi
        sleep 0.1
    done
    window_exists i3-widget-system || return 0
    i3-msg \
        '[class="^i3-widget-system$"] floating enable, resize set 31 ppt 43 ppt, move position 67 ppt 4 ppt, border pixel 2' \
        >/dev/null 2>&1 || true
}

report_missing() {
    local application="$1"
    local interactive="$2"

    printf 'Optional widget command not found: %s\n' "$application" >> "$log_file"
    if [[ "$interactive" == 1 ]] && command -v notify-send >/dev/null 2>&1; then
        notify-send 'Widget unavailable' "Install $application to restore its workspace card."
    fi
}

ensure_widgets() {
    local interactive="$1"
    local self

    self="$(readlink -f -- "${BASH_SOURCE[0]}")"
    : > "$log_file"
    render_cava_config

    if [[ "${CAVA_ENABLED:-1}" == 0 ]]; then
        : # Disabled cards are also excluded from automatic recovery.
    elif command -v cava >/dev/null 2>&1 && command -v alacritty >/dev/null 2>&1; then
        launch_terminal_widget \
            cava i3-widget-cava 'Cava • Audio' \
            --command "$self" run-cava
    else
        report_missing cava "$interactive"
    fi

    if command -v calcurse >/dev/null 2>&1 && command -v alacritty >/dev/null 2>&1; then
        launch_terminal_widget \
            calendar i3-widget-calendar 'Calendar • Agenda' \
            --command calcurse
    else
        report_missing calcurse "$interactive"
    fi

    if command -v conky >/dev/null 2>&1 && [[ -r "$conky_config" ]]; then
        launch_conky
    else
        report_missing conky "$interactive"
    fi
}

refresh_theme() {
    local pid

    render_cava_config
    if [[ "${CAVA_ENABLED:-1}" != 0 ]] && process_matches "$widget_state/cava.pid" "$cava_config"; then
        read -r pid < "$widget_state/cava.pid"
        kill -USR2 "$pid" 2>/dev/null || true
    fi
    if process_matches "$widget_state/conky.pid" "$conky_config"; then
        read -r pid < "$widget_state/conky.pid"
        # Conky 1.24 can destroy an i3-managed X11 window during SIGUSR1
        # reload without mapping its replacement. Restart this one recorded
        # process so the card reliably returns with its new palette.
        kill -TERM "$pid" 2>/dev/null || true
        for _ in {1..20}; do
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.1
        done
        rm -f -- "$widget_state/conky.pid"
        for _ in {1..20}; do
            window_exists i3-widget-system || break
            sleep 0.1
        done
        launch_conky
        place_conky
    fi
}

monitor_widgets() {
    exec {monitor_lock_fd}>"$widget_monitor_lock"
    flock -n "$monitor_lock_fd" || exit 0

    # Keep persistent cards present even after an application exits. Close the
    # monitor lock in children so an old sleep or launcher cannot block a new
    # monitor after logout or an i3 session restart.
    while :; do
        "$0" ensure {monitor_lock_fd}>&- || true
        sleep 5 {monitor_lock_fd}>&- || exit 0
    done
}

case "${1:-open}" in
    open)
        if command -v i3-msg >/dev/null 2>&1; then
            i3-msg "workspace \"$workspace\"" >/dev/null 2>&1 || true
        fi
        exec {widget_lock_fd}>"$widget_lock"
        flock -w 2 "$widget_lock_fd" || exit 0
        ensure_widgets 1
        ;;
    ensure)
        exec {widget_lock_fd}>"$widget_lock"
        flock -w 2 "$widget_lock_fd" || exit 0
        ensure_widgets 0
        ;;
    refresh-theme)
        refresh_theme
        ;;
    monitor)
        monitor_widgets
        ;;
    run-cava)
        [[ "${CAVA_ENABLED:-1}" != 0 ]] || exit 0
        printf '%s\n' "$$" > "$widget_state/cava.pid"
        exec cava --config "$cava_config" 2>>"$widget_state/cava.log"
        ;;
    *)
        printf 'Usage: %s {open|ensure|refresh-theme|monitor|run-cava}\n' "${0##*/}" >&2
        exit 2
        ;;
esac

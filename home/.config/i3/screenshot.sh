#!/usr/bin/env bash
# Instant screenshots: copy to the clipboard, save a PNG, and notify with a
# thumbnail. Clicking the notification opens the image.
#   region  drag a box (default; the everyday "snip")
#   window  the focused window
#   full    the whole screen
# Flameshot stays available separately for annotating.

set -u

mode="${1:-region}"
pictures="$(xdg-user-dir PICTURES 2>/dev/null || true)"
[[ -n "$pictures" && "$pictures" != "$HOME" ]] || pictures="$HOME/Pictures"
dir="${SCREENSHOT_DIR:-$pictures/Screenshots}"

notify() {
    if command -v dunstify >/dev/null 2>&1; then
        dunstify --appname=Screenshot "$@"
    elif command -v notify-send >/dev/null 2>&1; then
        notify-send --app-name=Screenshot "$@"
    fi
}

for command_name in maim xclip; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        notify --urgency=critical 'Screenshot unavailable' "Install $command_name (sudo pacman -S maim slop xclip)."
        exit 1
    fi
done

read_color() {
    local value=''
    local wal_colors="${XDG_CACHE_HOME:-$HOME/.cache}/wal/colors.sh"
    [[ -r "$wal_colors" ]] && value="$(sed -n "s/^$1='\(#[[:xdigit:]]\{6\}\)'$/\1/p" "$wal_colors" | head -n 1)"
    [[ "$value" =~ ^#[[:xdigit:]]{6}$ ]] || value="$2"
    printf '%s' "$value"
}

# slop takes the selection colour as "r,g,b,a" in 0-1 floats.
slop_color() {
    local hex="${1#\#}"
    awk -v r="$(( 16#${hex:0:2} ))" -v g="$(( 16#${hex:2:2} ))" -v b="$(( 16#${hex:4:2} ))" -v a="$2" \
        'BEGIN { printf "%.3f,%.3f,%.3f,%s", r/255, g/255, b/255, a }'
}

log="${XDG_STATE_HOME:-$HOME/.local/state}/i3/screenshot.log"
mkdir -p -- "${log%/*}"

fail() {
    printf '[%s] %s: %s\n' "$(date '+%F %T')" "$mode" "$1" >> "$log"
    notify --urgency=critical 'Screenshot failed' "$1"
    exit 1
}

mkdir -p -- "$dir"
stamp="$(date +%Y-%m-%d_%H-%M-%S)"
file="$dir/$stamp.png"
# Two shots in the same second get -2, -3, ... instead of overwriting.
n=2
while [[ -e "$file" ]]; do
    file="$dir/$stamp-$n.png"
    (( n++ ))
done

case "$mode" in
    region)
        accent="$(read_color color4 '#88C0D0')"
        # Highlight mode tints the selected area; Escape or right-click cancels.
        if ! error="$(maim --hidecursor --select --highlight --bordersize=2 \
                --color="$(slop_color "$accent" 0.18)" -- "$file" 2>&1 >/dev/null)"; then
            # Escape/right-click is a normal cancel; anything else is a fault.
            [[ "$error" == *cancel* ]] && exit 0
            fail "$error"
        fi
        ;;
    window)
        window_id="$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '{print $NF}')"
        [[ "$window_id" =~ ^0x[[:xdigit:]]+$ && "$window_id" != 0x0 ]] || fail 'No focused window.'
        error="$(maim --hidecursor --window="$window_id" -- "$file" 2>&1 >/dev/null)" || fail "$error"
        ;;
    full)
        error="$(maim --hidecursor -- "$file" 2>&1 >/dev/null)" || fail "$error"
        ;;
    *)
        printf 'Usage: %s {region|window|full}\n' "${0##*/}" >&2
        exit 2
        ;;
esac

[[ -s "$file" ]] || fail "maim wrote no image to $file"
xclip -selection clipboard -t image/png -i "$file" || fail 'Could not copy the image to the clipboard.'

# Run the notification in the background so the click action doesn't hold the
# keybinding's process open.
(
    action="$(notify --icon="$file" --action=default,Open \
        'Screenshot copied' "Saved to ${file/#$HOME/\~}")"
    if [[ "$action" == default ]]; then
        xdg-open "$file" >/dev/null 2>&1
    fi
) >/dev/null 2>&1 &
disown

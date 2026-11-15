#!/usr/bin/env bash
# Starts KeePassXC (locked) at login and hides its main window in the i3
# scratchpad; Mod+Shift+k toggles it. The system keychain is gnome-keyring
# (unlocked by LightDM's PAM), not KeePassXC.

set -u

cache_ini="${XDG_CACHE_HOME:-$HOME/.cache}/keepassxc/keepassxc.ini"
log="${XDG_STATE_HOME:-$HOME/.local/state}/i3/keepassxc-start.log"
mkdir -p -- "${log%/*}"

# Already running (ignore the browser native-messaging proxy).
pgrep -x keepassxc >/dev/null && exit 0

db="${KEEPASSXC_DB:-}"
if [[ -z "$db" && -r "$cache_ini" ]]; then
    db="$(sed -n 's/^LastActiveDatabase=//p' "$cache_ini" | head -n 1)"
fi

if [[ -n "$db" && -r "$db" ]]; then
    keepassxc "$db" >>"$log" 2>&1 &
else
    keepassxc >>"$log" 2>&1 &
fi

# Place the # Hide the main window in the scratchpad with the same mark and geometry that
# scratchpad.sh uses, so Mod+Shift+k toggles it. Unlock/access prompts are
# separate windows ("KeePassXC - ...") and are left where you are.
selector='[class="^KeePassXC$" title="(^KeePassXC$| - KeePassXC$)"]'
for _ in $(seq 1 150); do
    if i3-msg -t get_tree 2>/dev/null | jq -e '
        .. | objects | select(.window_properties?.class? == "KeePassXC")
        | select((.window_properties.title // "") | test("(^KeePassXC$| - KeePassXC$)"))' >/dev/null; then
        sleep 1  # let Qt finish restoring its saved geometry first
        i3-msg "$selector mark --add scratchpad-passwords, floating enable, border pixel 2, resize set 60 ppt 60 ppt, move position center, move scratchpad" >/dev/null 2>&1
        exit 0
    fi
    sleep 0.1
done

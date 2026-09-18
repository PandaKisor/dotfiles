#!/usr/bin/env bash

# Starts one bar per connected output and selects Pywal colors when available.
# The launcher restarts bars after a palette change, so config watching is not
# used while Pywal replaces the included theme file.

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
if [[ -r "$config_home/i3/desktop.env" ]]; then
  # shellcheck source=/dev/null
  source "$config_home/i3/desktop.env"
fi
export POLYBAR_MODULES_RIGHT='cpu memory network volume date notifications control'
if [[ "${MUSIC_ENABLED:-1}" != 0 ]]; then
  POLYBAR_MODULES_RIGHT="media $POLYBAR_MODULES_RIGHT"
fi
cache_home="${XDG_CACHE_HOME:-$HOME/.cache}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
config="$config_home/polybar/config.ini"
default_theme="$config_home/polybar/colors-default.ini"
wal_theme="$cache_home/wal/colors-polybar.ini"
log_dir="$state_home/polybar"
interface="$(ip route | awk '/default/ {print $5; exit}')"

if [[ -r "$wal_theme" ]]; then
  theme="$wal_theme"
else
  theme="$default_theme"
fi

mkdir -p -- "$log_dir"

pkill -x polybar 2>/dev/null

# Wait at most five seconds instead of hanging forever on a stuck process.
for _ in {1..25}; do
  pgrep -x polybar >/dev/null || break
  sleep 0.2
done

if pgrep -x polybar >/dev/null; then
  logger -t polybar-launch "old Polybar process did not exit"
  exit 1
fi

if command -v xrandr >/dev/null && xrandr --query | grep -q " connected"; then
  while IFS= read -r monitor; do
    MONITOR="$monitor" \
      POLYBAR_NETWORK_INTERFACE="$interface" \
      POLYBAR_THEME_FILE="$theme" \
      polybar example -c "$config" \
      >"$log_dir/${monitor}.log" 2>&1 &
  done < <(xrandr --query | awk '/ connected/ {print $1}')
else
  POLYBAR_NETWORK_INTERFACE="$interface" \
    POLYBAR_THEME_FILE="$theme" \
    polybar example -c "$config" \
    >"$log_dir/default.log" 2>&1 &
fi

#!/usr/bin/env bash

# Clean Polybar launch script for i3.
# Passes the active network interface into the Polybar config.

CONFIG="$HOME/.config/polybar/config.ini"
IFACE="$(ip route | awk '/default/ {print $5; exit}')"

pkill -x polybar 2>/dev/null

# Wait for old bars to exit cleanly.
while pgrep -x polybar >/dev/null; do
  sleep 0.2
done

if command -v xrandr >/dev/null && xrandr --query | grep -q " connected"; then
  while IFS= read -r monitor; do
    MONITOR="$monitor" POLYBAR_NETWORK_INTERFACE="$IFACE" polybar --reload example -c "$CONFIG" \
      >"/tmp/polybar-${monitor}.log" 2>&1 &
  done < <(xrandr --query | awk '/ connected/ {print $1}')
else
  POLYBAR_NETWORK_INTERFACE="$IFACE" polybar --reload example -c "$CONFIG" \
    >"/tmp/polybar.log" 2>&1 &
fi

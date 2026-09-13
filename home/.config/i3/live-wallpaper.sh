#!/usr/bin/env bash

pkill -f "xwinwrap.*mpv" 2>/dev/null

VIDEO="$HOME/.config/i3/wallpapers/videos/nebula.mp4"
LOG="/tmp/live-wallpaper.log"

if [ ! -f "$VIDEO" ]; then
  echo "Video not found: $VIDEO" > "$LOG"
  exit 1
fi

echo "Starting live wallpaper with: $VIDEO" > "$LOG"

sleep 1

xwinwrap -fs -fdt -ni -b -nf -ov -- \
  mpv -wid %WID \
    --vo=gpu \
    --gpu-context=x11egl \
    --loop-file=inf \
    --no-audio \
    --no-osc \
    --no-osd-bar \
    --panscan=1.0 \
    --really-quiet \
    "$VIDEO" >> "$LOG" 2>&1

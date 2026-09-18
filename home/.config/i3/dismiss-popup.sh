#!/usr/bin/env bash

# Rofi normally exits on Escape itself. This i3-level fallback guarantees that
# a managed popup releases focus even if Rofi's own key handler gets wedged.
pkill -x rofi >/dev/null 2>&1 || true
i3-msg 'mode "default"' >/dev/null 2>&1 || true

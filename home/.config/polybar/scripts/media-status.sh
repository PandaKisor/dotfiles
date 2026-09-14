#!/usr/bin/env bash

set -uo pipefail

player="${POLYBAR_MEDIA_PLAYER:-playerctld}"
metadata="$(
    playerctl --player="$player" metadata \
        --format '{{status}}|||{{artist}}|||{{title}}' 2>/dev/null
)" || exit 0

status="${metadata%%|||*}"
remainder="${metadata#*|||}"
artist="${remainder%%|||*}"
title="${remainder#*|||}"

[[ -n "$title" ]] || exit 0

case "$status" in
    Playing) icon='' ;;
    Paused)  icon='' ;;
    *)       icon='' ;;
esac

if [[ -n "$artist" ]]; then
    description="$artist — $title"
else
    description="$title"
fi

# Prevent track metadata containing Polybar formatting openers from being
# interpreted as markup.
description="$(printf '%s' "$description" | sed 's/%{/% {/g')"
printf '%s  %s\n' "$icon" "$description"

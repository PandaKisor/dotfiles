#!/usr/bin/env bash

set -u

if ! command -v dunstctl >/dev/null 2>&1; then
    printf '\n'
    exit 0
fi

if [[ "$(dunstctl is-paused 2>/dev/null)" == "true" ]]; then
    waiting_count="$(dunstctl count waiting 2>/dev/null)"
    if [[ "$waiting_count" =~ ^[1-9][0-9]*$ ]]; then
        printf ' %s\n' "$waiting_count"
    else
        printf '\n'
    fi
else
    printf '\n'
fi

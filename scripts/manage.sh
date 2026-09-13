#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_root="$repo_root/home"
state_root="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"

usage() {
    printf 'Usage: %s {status|install}\n' "$0"
}

tracked_files() {
    if git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
        while IFS= read -r -d '' relative; do
            printf '%s\0' "$repo_root/$relative"
        done < <(git -C "$repo_root" ls-files -co --exclude-standard -z -- home)
    else
        find "$source_root" -type f \
            ! -path '*/__pycache__/*' \
            ! -name '*.pyc' \
            -print0
    fi | sort -z
}

status_files() {
    local source_file relative target resolved result=0
    while IFS= read -r -d '' source_file; do
        relative="${source_file#"$source_root/"}"
        target="$HOME/$relative"

        if [[ -L "$target" ]]; then
            resolved="$(readlink -f -- "$target" || true)"
            if [[ "$resolved" == "$source_file" ]]; then
                printf 'linked     %s\n' "$relative"
            else
                printf 'other-link %s -> %s\n' "$relative" "$(readlink -- "$target")"
                result=1
            fi
        elif [[ -f "$target" ]] && cmp -s -- "$source_file" "$target"; then
            printf 'same       %s\n' "$relative"
        elif [[ -e "$target" ]]; then
            printf 'different  %s\n' "$relative"
            result=1
        else
            printf 'missing    %s\n' "$relative"
            result=1
        fi
    done < <(tracked_files)
    return "$result"
}

install_files() {
    local source_file relative target backup_root backup
    backup_root="$state_root/backups/$(date +%Y%m%d-%H%M%S)"

    while IFS= read -r -d '' source_file; do
        relative="${source_file#"$source_root/"}"
        target="$HOME/$relative"

        if [[ -L "$target" ]] && [[ "$(readlink -f -- "$target" || true)" == "$source_file" ]]; then
            continue
        fi

        if [[ -e "$target" || -L "$target" ]]; then
            backup="$backup_root/$relative"
            mkdir -p -- "$(dirname -- "$backup")"
            mv -- "$target" "$backup"
            printf 'backed up  %s\n' "$target"
        fi

        mkdir -p -- "$(dirname -- "$target")"
        ln -s -- "$source_file" "$target"
        printf 'linked     %s -> %s\n' "$target" "$source_file"
    done < <(tracked_files)

    if [[ -d "$backup_root" ]]; then
        printf 'Backups: %s\n' "$backup_root"
    fi
}

case "${1:-}" in
    status) status_files ;;
    install) install_files ;;
    *) usage; exit 2 ;;
esac

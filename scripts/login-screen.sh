#!/usr/bin/env bash
# System-wide Slick Greeter appearance; never restarts the display manager.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
config=/etc/lightdm/slick-greeter.conf
background=/usr/local/share/backgrounds/dotfiles/login.svg
backup_root=/var/lib/dotfiles/login-screen-backups

check() {
    command -v slick-greeter >/dev/null
    [[ -r /usr/share/themes/cachyos-nord/gtk-3.0/gtk.css ]]
    [[ -r /usr/share/icons/Pop/index.theme ]]
    [[ -r /usr/share/icons/capitaine-cursors/index.theme ]]
    lightdm --show-config 2>&1 | grep -Eq '^[[:space:][:alpha:]]*greeter-session=lightdm-slick-greeter$' || {
        printf 'The active LightDM greeter must already be lightdm-slick-greeter.\n' >&2
        return 1
    }
    python3 "$repo_root/scripts/login-screen-preview.py" --check
}

require_root() {
    if (( EUID != 0 )); then
        printf 'Run this action with sudo; it writes system login-screen files.\n' >&2
        exit 1
    fi
}

case "${1:-check}" in
    check) check ;;
    install)
        require_root
        check
        # Each installation has its own complete rollback point, including absence.
        install -d -m 0700 "$backup_root"
        backup="$(mktemp -d "$backup_root/install-$(date +%Y%m%d-%H%M%S)-XXXXXX")"
        for item in config background; do
            target="${!item}"
            if [[ -e "$target" || -L "$target" ]]; then
                cp -a -- "$target" "$backup/$item"
            else
                touch "$backup/$item.absent"
            fi
        done
        printf 'Rollback: sudo %q restore %q\n' "$0" "$backup"
        install -d -m 0755 /usr/local/share/backgrounds/dotfiles
        # Replace directory entries atomically without following existing symlinks.
        staged_background="$(mktemp /usr/local/share/backgrounds/dotfiles/.login-XXXXXX)"
        staged_config="$(mktemp /etc/lightdm/.slick-greeter-XXXXXX)"
        install -m 0644 "$repo_root/system/lightdm/login.svg" "$staged_background"
        install -m 0644 "$repo_root/system/lightdm/slick-greeter.conf" "$staged_config"
        mv -T -- "$staged_background" "$background"
        mv -T -- "$staged_config" "$config"
        printf 'Installed. Appearance takes effect when the next greeter starts.\n'
        ;;
    restore)
        require_root
        backup="$(realpath -e -- "${2:?Supply the installation backup directory}")"
        [[ "$backup" == "$backup_root"/install-* && "${backup%/*}" == "$backup_root" ]] || exit 2
        for item in config background; do
            [[ -e "$backup/$item" || -L "$backup/$item" || -f "$backup/$item.absent" ]] || exit 2
        done
        archive="$(mktemp -d "$backup_root/replaced-$(date +%Y%m%d-%H%M%S)-XXXXXX")"
        for item in config background; do
            target="${!item}"
            if [[ -e "$target" || -L "$target" ]]; then
                mv -- "$target" "$archive/$item"
            fi
            if [[ ! -f "$backup/$item.absent" ]]; then
                cp -a -- "$backup/$item" "$target"
            fi
        done
        printf 'Restored. Replaced files preserved in %s\n' "$archive"
        ;;
    *) printf 'Usage: %s {check|install|restore BACKUP}\n' "$0" >&2; exit 2 ;;
esac

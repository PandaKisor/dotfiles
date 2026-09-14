#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

if git -C "$repo_root" rev-parse --git-dir >/dev/null 2>&1; then
    git -C "$repo_root" diff --check || failed=1
    git -C "$repo_root" diff --cached --check || failed=1
fi

secret_pattern='(api[_-]?key|access[_-]?token|auth[_-]?token|client[_-]?secret|password|passwd)[[:space:]]*=[[:space:]]*"?[A-Za-z0-9][A-Za-z0-9_./+=-]{7,}"?|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}'
if rg -n -i --hidden \
    --glob '!.git/**' \
    --glob '!scripts/check.sh' \
    --glob '!profiles/*.example' \
    "$secret_pattern" "$repo_root"; then
    printf 'Possible committed secret found; review the lines above.\n' >&2
    failed=1
fi

for script in \
    "$repo_root"/scripts/*.sh \
    "$repo_root"/home/.config/i3/*.sh \
    "$repo_root"/home/.config/polybar/*.sh \
    "$repo_root"/home/.config/polybar/scripts/*.sh; do
    bash -n "$script" || failed=1
done

python3 -c '
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
compile(path.read_bytes(), str(path), "exec")
' "$repo_root/home/.config/i3/quadrant-tiling.py" || failed=1

if command -v luac >/dev/null 2>&1; then
    while IFS= read -r -d '' lua_file; do
        luac -p "$lua_file" || failed=1
    done < <(find "$repo_root/home/.config/nvim" -type f -name '*.lua' -print0)
fi

if command -v jq >/dev/null 2>&1; then
    jq empty "$repo_root/home/.config/nvim/lazy-lock.json" || failed=1
fi

if command -v i3 >/dev/null 2>&1; then
    runtime_dir="$(mktemp -d)"
    if ! HOME="$repo_root/home" \
        XDG_CONFIG_HOME="$repo_root/home/.config" \
        XDG_RUNTIME_DIR="$runtime_dir" \
        i3 -C -c "$repo_root/home/.config/i3/config"; then
        failed=1
    fi
    rm -rf -- "$runtime_dir"
fi

exit "$failed"

#!/usr/bin/env bash
set -euo pipefail

if ! updates_arch=$(checkupdates 2> /dev/null | wc -l ); then
    updates_arch=0
fi

if ! updates_aur=$(paru -Qum | wc -l); then
# if ! updates_aur=$(cower -u 2> /dev/null | wc -l); then
# if ! updates_aur=$(trizen -Su --aur --quiet | wc -l); then
    updates_aur=0
fi

re='^[0-9]+$'
if ! [[ $updates_aur =~ $re ]] ; then
    printf 'Invalid AUR update count: %s\n' "$updates_aur" >&2
    exit 1
fi

if ! [[ $updates_arch =~ $re ]] ; then
    printf 'Invalid repository update count: %s\n' "$updates_arch" >&2
    exit 1
fi

echo "P:$updates_arch Y:$updates_aur"

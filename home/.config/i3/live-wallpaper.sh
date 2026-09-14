#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
video_dir="${VIDEO_WALLPAPER_DIR:-$config_home/i3/wallpapers/videos}"
requested_video="${1:-}"
theme_script="$config_home/i3/video-theme.sh"
log_dir="$state_home/i3"
log_file="$log_dir/live-wallpaper.log"
history_file="$log_dir/video-history"
legacy_last_video_file="$log_dir/last-video"
history_size="${VIDEO_WALLPAPER_HISTORY_SIZE:-3}"
if [[ ! -d "$runtime_dir" || ! -w "$runtime_dir" ]]; then
    runtime_dir=/tmp
fi
pid_file="$runtime_dir/i3-live-wallpaper-$UID.pid"
selection_lock="$runtime_dir/i3-live-wallpaper-$UID.lock"

mkdir -p -- "$log_dir" "$video_dir"
: > "$log_file"

if [[ ! "$history_size" =~ ^[1-9][0-9]*$ ]]; then
    printf 'Invalid VIDEO_WALLPAPER_HISTORY_SIZE=%s; using 3.\n' "$history_size" >> "$log_file"
    history_size=3
fi
if ! command -v flock >/dev/null 2>&1; then
    printf 'Required command not found: flock\n' >> "$log_file"
    exit 1
fi

# Prevent a timer event and a manual key press from selecting at the same time.
exec {selection_lock_fd}>"$selection_lock"
if ! flock -n "$selection_lock_fd"; then
    printf 'Another wallpaper selection is already in progress.\n' >> "$log_file"
    exit 0
fi

history=()
if [[ -r "$history_file" ]]; then
    mapfile -t history < "$history_file"
elif [[ -r "$legacy_last_video_file" ]]; then
    read -r legacy_last_video < "$legacy_last_video_file"
    [[ -n "$legacy_last_video" ]] && history+=("$legacy_last_video")
fi

# An explicit path is useful for testing. With no path (or --next), choose from
# every MP4 and avoid the three most recent choices when enough files exist.
if [[ -n "$requested_video" && "$requested_video" != "--next" ]]; then
    if [[ "$requested_video" != */* && -r "$video_dir/$requested_video" ]]; then
        video="$video_dir/$requested_video"
    else
        video="$requested_video"
    fi
else
    mapfile -d '' -t videos < <(
        find -L "$video_dir" -maxdepth 1 -type f -iname '*.mp4' -print0 2>/dev/null |
            sort -z
    )

    if (( ${#videos[@]} == 0 )); then
        printf 'No MP4 files found in: %s\n' "$video_dir" > "$log_file"
        exit 1
    fi

    avoid_count="$history_size"
    max_avoid=$((${#videos[@]} - 1))
    (( avoid_count > max_avoid )) && avoid_count="$max_avoid"
    recent=()
    if (( avoid_count > 0 && ${#history[@]} > 0 )); then
        history_start=$((${#history[@]} - avoid_count))
        (( history_start < 0 )) && history_start=0
        recent=("${history[@]:history_start}")
    fi

    candidates=()
    for candidate in "${videos[@]}"; do
        recently_used=0
        for previous in "${recent[@]}"; do
            if [[ "$candidate" == "$previous" ]]; then
                recently_used=1
                break
            fi
        done
        (( recently_used == 0 )) && candidates+=("$candidate")
    done
    # Defensive fallback for stale or manually edited history state.
    (( ${#candidates[@]} > 0 )) || candidates=("${videos[@]}")
    video="${candidates[RANDOM % ${#candidates[@]}]}"
fi

if [[ ! -r "$video" ]]; then
    printf 'Video not found: %s\n' "$video" > "$log_file"
    exit 1
fi

# Keep unique entries, oldest first, and update the history file atomically.
updated_history=()
for previous in "${history[@]}"; do
    [[ -n "$previous" && "$previous" != "$video" ]] && updated_history+=("$previous")
done
updated_history+=("$video")
if (( ${#updated_history[@]} > history_size )); then
    updated_history=("${updated_history[@]: -history_size}")
fi
temporary_history="$(mktemp --tmpdir="$log_dir" .video-history.XXXXXX)"
printf '%s\n' "${updated_history[@]}" > "$temporary_history"
mv -- "$temporary_history" "$history_file"
printf 'Selected video: %s\n' "$video" >> "$log_file"

for command_name in xwinwrap mpv; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$command_name" > "$log_file"
        exit 1
    fi
done

# Stop only the wallpaper process recorded by an earlier run of this script.
if [[ -r "$pid_file" ]]; then
    read -r old_pid < "$pid_file"
    if [[ "$old_pid" =~ ^[0-9]+$ ]] \
        && kill -0 "$old_pid" 2>/dev/null \
        && [[ "$(tr '\0' ' ' 2>/dev/null < "/proc/$old_pid/cmdline")" == *xwinwrap* ]]; then
        pkill -TERM -P "$old_pid" 2>/dev/null || true
        kill "$old_pid" 2>/dev/null || true
        for _ in {1..20}; do
            kill -0 "$old_pid" 2>/dev/null || break
            sleep 0.1
        done
    fi
fi

# Palette generation is useful but non-fatal: the wallpaper still starts when
# Pywal is not installed or a frame cannot be extracted.
if [[ -x "$theme_script" ]]; then
    "$theme_script" "$video" "${PYWAL_VIDEO_SEEK:-auto}" >> "$log_file" 2>&1 \
        || printf 'Pywal theme generation failed; continuing with the wallpaper.\n' >> "$log_file"
fi

printf 'Starting live wallpaper with: %s\n' "$video" >> "$log_file"
printf '%s\n' "$$" > "$pid_file"
flock -u "$selection_lock_fd"
exec {selection_lock_fd}>&-

exec xwinwrap -fs -fdt -ni -b -nf -ov -- \
    mpv -wid %WID \
        --no-config \
        --vo=gpu \
        --gpu-context="${VIDEO_WALLPAPER_GPU_CONTEXT:-auto}" \
        --hwdec=auto-safe \
        --loop-file=inf \
        --no-audio \
        --no-osc \
        --no-osd-bar \
        --panscan=1.0 \
        --really-quiet \
        "$video" >> "$log_file" 2>&1

#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
wallpaper_settings="$config_home/i3/wallpaper.env"
if [[ -r "$wallpaper_settings" ]]; then
    # shellcheck source=/dev/null
    source "$wallpaper_settings"
fi
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
wallpaper_root="${WALLPAPER_DIR:-$config_home/i3/wallpapers}"
video_dir="${VIDEO_WALLPAPER_DIR:-$wallpaper_root/videos}"
image_dir="${IMAGE_WALLPAPER_DIR:-$wallpaper_root/images}"
requested_wallpaper="${1:-}"
wallpaper_mode="${WALLPAPER_MODE:-auto}"
theme_script="$config_home/i3/video-theme.sh"
log_dir="$state_home/i3"
log_file="$log_dir/live-wallpaper.log"
history_file="$log_dir/wallpaper-history"
legacy_history_file="$log_dir/video-history"
legacy_last_video_file="$log_dir/last-video"
history_size="${WALLPAPER_HISTORY_SIZE:-${VIDEO_WALLPAPER_HISTORY_SIZE:-3}}"
fallback_color="${WALLPAPER_FALLBACK_COLOR:-${VIDEO_WALLPAPER_FALLBACK_COLOR:-#000000}}"
if [[ ! -d "$runtime_dir" || ! -w "$runtime_dir" ]]; then
    runtime_dir=/tmp
fi
pid_file="$runtime_dir/i3-live-wallpaper-$UID.pid"
selection_lock="$runtime_dir/i3-live-wallpaper-$UID.lock"

mkdir -p -- "$log_dir" "$video_dir" "$image_dir"
: > "$log_file"

case "${wallpaper_mode,,}" in
    auto) wallpaper_mode=auto ;;
    image|images|static) wallpaper_mode=image ;;
    video|videos|animated) wallpaper_mode=video ;;
    *)
        printf 'Invalid WALLPAPER_MODE=%s; expected auto, image, or video.\n' "$wallpaper_mode" >> "$log_file"
        exit 1
        ;;
esac

if [[ ! "$history_size" =~ ^[1-9][0-9]*$ ]]; then
    printf 'Invalid WALLPAPER_HISTORY_SIZE=%s; using 3.\n' "$history_size" >> "$log_file"
    history_size=3
fi
if [[ ! "$fallback_color" =~ ^#[[:xdigit:]]{6}$ ]]; then
    printf 'Invalid WALLPAPER_FALLBACK_COLOR=%s; using #000000.\n' "$fallback_color" >> "$log_file"
    fallback_color="#000000"
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
elif [[ -r "$legacy_history_file" ]]; then
    mapfile -t history < "$legacy_history_file"
elif [[ -r "$legacy_last_video_file" ]]; then
    read -r legacy_last_video < "$legacy_last_video_file"
    [[ -n "$legacy_last_video" ]] && history+=("$legacy_last_video")
fi

images=()
videos=()
mapfile -d '' -t images < <(
    find -L "$image_dir" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
        -print0 2>/dev/null | sort -z
)
mapfile -d '' -t videos < <(
    find -L "$video_dir" -maxdepth 1 -type f -iname '*.mp4' -print0 2>/dev/null | sort -z
)

if [[ -n "$requested_wallpaper" && "$requested_wallpaper" != "--next" ]]; then
    if [[ "$requested_wallpaper" != */* && -r "$image_dir/$requested_wallpaper" ]]; then
        wallpaper="$image_dir/$requested_wallpaper"
    elif [[ "$requested_wallpaper" != */* && -r "$video_dir/$requested_wallpaper" ]]; then
        wallpaper="$video_dir/$requested_wallpaper"
    else
        wallpaper="$requested_wallpaper"
    fi
else
    selected_mode="$wallpaper_mode"
    if [[ "$selected_mode" == auto ]]; then
        is_vm=0
        if command -v systemd-detect-virt >/dev/null 2>&1 \
            && systemd-detect-virt --vm --quiet; then
            is_vm=1
        fi

        if (( is_vm == 1 && ${#images[@]} > 0 )); then
            selected_mode=image
        elif (( ${#videos[@]} > 0 )); then
            selected_mode=video
        else
            selected_mode=image
        fi
    fi

    if [[ "$selected_mode" == image ]]; then
        wallpapers=("${images[@]}")
        expected_description="JPG, PNG, or WebP images"
        selected_directory="$image_dir"
    else
        wallpapers=("${videos[@]}")
        expected_description="MP4 videos"
        selected_directory="$video_dir"
    fi

    if (( ${#wallpapers[@]} == 0 )); then
        printf 'No %s found in: %s\n' "$expected_description" "$selected_directory" > "$log_file"
        exit 1
    fi

    avoid_count="$history_size"
    max_avoid=$((${#wallpapers[@]} - 1))
    (( avoid_count > max_avoid )) && avoid_count="$max_avoid"
    recent=()
    if (( avoid_count > 0 && ${#history[@]} > 0 )); then
        history_start=$((${#history[@]} - avoid_count))
        (( history_start < 0 )) && history_start=0
        recent=("${history[@]:history_start}")
    fi

    candidates=()
    for candidate in "${wallpapers[@]}"; do
        recently_used=0
        for previous in "${recent[@]}"; do
            if [[ "$candidate" == "$previous" ]]; then
                recently_used=1
                break
            fi
        done
        (( recently_used == 0 )) && candidates+=("$candidate")
    done
    (( ${#candidates[@]} > 0 )) || candidates=("${wallpapers[@]}")
    wallpaper="${candidates[RANDOM % ${#candidates[@]}]}"
fi

if [[ ! -r "$wallpaper" ]]; then
    printf 'Wallpaper not found: %s\n' "$wallpaper" > "$log_file"
    exit 1
fi

case "${wallpaper,,}" in
    *.jpg|*.jpeg|*.png|*.webp) wallpaper_type=image ;;
    *.mp4) wallpaper_type=video ;;
    *)
        printf 'Unsupported wallpaper type: %s\n' "$wallpaper" > "$log_file"
        exit 1
        ;;
esac

if [[ "$wallpaper_type" == image ]]; then
    if ! command -v feh >/dev/null 2>&1; then
        printf 'Required command not found: feh\n' > "$log_file"
        exit 1
    fi
else
    for command_name in xwinwrap mpv; do
        if ! command -v "$command_name" >/dev/null 2>&1; then
            printf 'Required command not found: %s\n' "$command_name" > "$log_file"
            exit 1
        fi
    done
fi

# Keep unique entries, oldest first, and update the history file atomically.
updated_history=()
for previous in "${history[@]}"; do
    [[ -n "$previous" && "$previous" != "$wallpaper" ]] && updated_history+=("$previous")
done
updated_history+=("$wallpaper")
if (( ${#updated_history[@]} > history_size )); then
    updated_history=("${updated_history[@]: -history_size}")
fi
temporary_history="$(mktemp --tmpdir="$log_dir" .wallpaper-history.XXXXXX)"
printf '%s\n' "${updated_history[@]}" > "$temporary_history"
mv -- "$temporary_history" "$history_file"
printf 'Selected %s wallpaper: %s\n' "$wallpaper_type" "$wallpaper" >> "$log_file"

stop_wallpaper_pid() {
    local target_pid="$1"
    local command_line

    [[ "$target_pid" =~ ^[0-9]+$ ]] || return 0
    kill -0 "$target_pid" 2>/dev/null || return 0
    command_line="$(tr '\0' ' ' 2>/dev/null < "/proc/$target_pid/cmdline")"
    [[ "$command_line" == *xwinwrap* ]] || return 0

    pkill -TERM -P "$target_pid" 2>/dev/null || true
    kill "$target_pid" 2>/dev/null || true
    for _ in {1..20}; do
        kill -0 "$target_pid" 2>/dev/null || break
        sleep 0.1
    done
}

set_root_fallback() {
    if command -v xsetroot >/dev/null 2>&1; then
        xsetroot -solid "$fallback_color" >> "$log_file" 2>&1 \
            || printf 'Could not set the root fallback color.\n' >> "$log_file"
    else
        printf 'Optional command not found: xsetroot; root fallback was not set.\n' >> "$log_file"
    fi
}

# The live renderer covers the root while the next palette is generated. A
# static image remains in place until feh atomically replaces the root pixmap.
if [[ "$wallpaper_type" == video ]]; then
    set_root_fallback
fi
if [[ -x "$theme_script" ]]; then
    "$theme_script" "$wallpaper" "${PYWAL_VIDEO_SEEK:-auto}" >> "$log_file" 2>&1 \
        || printf 'Pywal theme generation failed; continuing with the wallpaper.\n' >> "$log_file"
fi

# Stop only the live wallpaper process recorded by an earlier run.
if [[ -r "$pid_file" ]]; then
    read -r old_pid < "$pid_file"
    stop_wallpaper_pid "$old_pid"
fi

# Earlier revisions did not record their renderer PID. Remove only orphaned
# xwinwrap instances that launch MPV with media from the configured video path.
for command_line_file in /proc/[0-9]*/cmdline; do
    [[ -r "$command_line_file" ]] || continue
    candidate_pid="${command_line_file#/proc/}"
    candidate_pid="${candidate_pid%/cmdline}"
    candidate_command="$(tr '\0' ' ' 2>/dev/null < "$command_line_file")"
    if [[ "$candidate_command" == *xwinwrap*mpv\ -wid* \
        && "$candidate_command" == *"$video_dir/"* ]]; then
        stop_wallpaper_pid "$candidate_pid"
    fi
done

if [[ "$wallpaper_type" == image ]]; then
    rm -f -- "$pid_file"
    printf 'Setting static wallpaper with: %s\n' "$wallpaper" >> "$log_file"
    flock -u "$selection_lock_fd"
    exec {selection_lock_fd}>&-
    exec feh --no-fehbg --bg-fill "$wallpaper" >> "$log_file" 2>&1
fi

printf 'Starting live wallpaper with: %s\n' "$wallpaper" >> "$log_file"
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
        "$wallpaper" >> "$log_file" 2>&1

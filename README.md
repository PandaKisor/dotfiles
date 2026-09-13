# Portable dotfiles

This repository stages reviewed configuration before it is linked into the
home directory or pushed to GitHub. Files under `home/` mirror paths beneath
`$HOME`.

The initial snapshot focuses on the i3 desktop: i3, Picom, Polybar, Alacritty,
Dunst, Rofi, and a small Fish config. See `docs/review-notes.md` for exclusions
and portability decisions.

## Review the current machine

```bash
./scripts/manage.sh status
./scripts/check.sh
```

`status` never changes files. It reports whether each tracked file is already
linked, has identical content, differs, or is missing.

## Install the reviewed files

```bash
./scripts/manage.sh install
```

Installation creates per-file symbolic links. Existing targets are moved to a
timestamped backup under `~/.local/state/dotfiles/backups/`; they are not
deleted. Run the status and check commands first and inspect the diff before
installing.

Personal startup behavior is opt-in. Copy `profiles/home-i3.conf.example` to
`~/.config/i3/config.d/90-local.conf` for the current home app assignments, and
copy `profiles/local-startup.sh.example` to `~/.config/i3/local-startup.sh` for
the physical display and wallpaper commands. Both destinations are ignored by
Git so a work machine can use different values.

## Auto-tiling and wallpaper colors

The i3 config runs the CachyOS/Arch `autotiling` package directly. The old
`quadrant-tiling.py` remains for reference but is not started; never run both
helpers together.

`live-wallpaper.sh` asks `video-theme.sh` to extract a frame at 12 seconds,
scales it down for quick palette analysis, and runs Pywal16 without replacing
the animated wallpaper. Generated colors are consumed by i3, Polybar, Rofi,
Dunst, and new Fish/Alacritty terminals. Override the frame time with
`PYWAL_VIDEO_SEEK`, for example `PYWAL_VIDEO_SEEK=00:00:30`.

Install the two missing components on CachyOS with:

```bash
sudo pacman -S --needed autotiling
paru -S --needed python-pywal16-git
```

Install dependencies on CachyOS with the reviewed package names in
`packages/cachyos.txt`. Package installation is intentionally not automatic.

## GitHub preparation

Before adding a remote:

1. Run `./scripts/check.sh`.
2. Review `git diff` and `git status --ignored`.
3. Rotate the old weather API key and use the ignored `weather.env` file.
4. Confirm your workplace permits each configuration and script.

No GitHub remote is configured by this repository.

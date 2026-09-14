# Portable dotfiles

This repository stages reviewed configuration before it is linked into the
home directory or pushed to GitHub. Files under `home/` mirror paths beneath
`$HOME`.

The initial snapshot focuses on the i3 desktop: i3, Picom, Polybar, Alacritty,
Dunst, Rofi, GTK 2/3/4 theming, session defaults, and a small Fish config. See
`docs/review-notes.md` for exclusions and portability decisions.

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
physical display commands. Both destinations are ignored by Git so a work
machine can use different values.

## Visual design

The desktop uses a restrained glass style: ten-pixel tiled gaps, rounded Picom
corners and shadows, a floating Polybar, and a shared Meslo Nerd Font. GTK apps
use the CachyOS Nord theme, Pop icons, Capitaine cursors, and Fira Sans. The GTK
and Qt theme bridge in `.profile` takes effect at the next login; newly opened
GTK applications pick up their settings immediately.

Picom starts on physical hosts. It skips actual virtual machines by default so
the work VM has a safe non-composited fallback; create the untracked file
`~/.config/picom/enable-in-vm` there only if its graphics stack handles Picom
well.

## Widget workspace and YouTube Music

Workspace 10 is named `10:widgets` and is reserved for persistent,
low-attention applications. Pear Desktop is its first resident: when installed,
it starts with the i3 session and is assigned there without pulling focus from
the main workspace. `Mod+0` opens the widget workspace; `Mod+m` opens it and
focuses or launches YouTube Music.

The workspace follows a responsive three-column by four-row grid. A base widget
is approximately 31 percent wide by 20 percent tall; Pear occupies the upper
left column and spans two rows at 31 by 43 percent. This keeps the full player
usable while leaving predictable slots for future status panels, calendars,
system monitors, or communication widgets.

The launcher prefers [Pear Desktop](https://github.com/pear-devs/pear-desktop),
an unofficial dedicated client, and falls back to a separate Firefox window
when Pear is not installed. Install the signed CachyOS package with:

```bash
sudo pacman -S --needed pear-desktop
```

In Pear, enable the Shortcuts plugin's MPRIS integration, but leave its
media-key override disabled because i3 handles those keys through Playerctl.

Polybar shows the active track when an MPRIS player is available. Left-click
the track to play or pause, middle-click for the previous track, right-click for
the next track, and scroll over it to change player volume. The keyboard's
play/pause, previous, next, and stop keys follow the most recently active media
player, including Firefox when Pear is not running.

Future widget-style applications can join the same workspace with another i3
`assign` rule keyed to their X11 window class and a `for_window` rule selecting
its grid position and row span.

## Session polish

`Mod+p` opens a Pywal-colored Rofi control center; the gear at the right edge
of Polybar opens the same menu. It provides lock, audio, network, Bluetooth,
notification, wallpaper, desktop refresh, session, and power controls. Logout,
suspend, reboot, and shutdown require a second confirmation. Network management
prefers the graphical NetworkManager editor and falls back to `nmtui` in
Alacritty; Bluetooth similarly falls back to `bluetoothctl` when Blueman is not
installed.

`Mod+l` opens a blurred lock screen with a centered clock, date, authentication
ring, and colors read from the current Pywal palette. Media and brightness keys
remain available while the session is locked.

The keyboard volume and brightness keys display short, replaceable Dunst
progress overlays. Polybar's volume module uses the same volume overlay when it
is clicked or scrolled. Brightness control prefers `brightnessctl`, then
XBacklight, and uses XRandR software dimming as a portable fallback for external
monitors without a backlight interface.

## Auto-tiling and wallpaper colors

The i3 config runs the CachyOS/Arch `autotiling` package directly. The old
`quadrant-tiling.py` remains for reference but is not started; never run both
helpers together.

Put any number of `.mp4` files in the automatically created
`~/.config/i3/wallpapers/videos/` directory. At i3 startup,
`live-wallpaper.sh` randomly selects one while avoiding the previously selected
three videos when enough alternatives exist. Press `Mod+Shift+N` to select
another video and apply its colors through a preserving i3 restart, or run
`~/.config/i3/live-wallpaper.sh example.mp4` to choose one by name.
The X root underneath the animated wallpaper is set to solid black, so startup,
player handoffs, and renderer failures never expose an unrelated default image.
During a normal change, the old animation remains visible while the next color
palette is generated; black appears only if the new player needs time to draw.

`wallpaper-rotation.sh` selects another wallpaper every 30 minutes. Set
`VIDEO_WALLPAPER_INTERVAL` in the environment before i3 starts to change the
interval in seconds, or set it to `0` to disable automatic rotation. Set
`VIDEO_WALLPAPER_HISTORY_SIZE` the same way to change the three-video history.
Set `VIDEO_WALLPAPER_FALLBACK_COLOR` to another six-digit hex color if black is
not desired.

Each selection asks `video-theme.sh` to extract a frame 35 percent into the
video, scales it down for quick palette analysis, and runs Pywal16 without
replacing the animated wallpaper. Generated colors are consumed by i3,
Polybar, Rofi, Dunst, and new Fish/Alacritty terminals. Override the automatic
frame time with `PYWAL_VIDEO_SEEK`, for example
`PYWAL_VIDEO_SEEK=00:00:30`.

Install the two components on CachyOS with:

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

# Portable dotfiles

This repository stages reviewed configuration before it is linked into the
home directory or pushed to GitHub. Files under `home/` mirror paths beneath
`$HOME`.

The repository is a one-stop workstation setup. It includes the i3 desktop,
Picom, Polybar, Alacritty, Dunst, Rofi, GTK 2/3/4 theming, session defaults,
Fish, and the complete Neovim configuration. See `docs/review-notes.md` for
exclusions and portability decisions.

Future desktop work should begin with [`CURRENT_STATE.md`](CURRENT_STATE.md),
which records the implemented behavior, live validation baseline, known
boundaries, and remaining optional polish.

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
`~/.config/i3/config.d/90-local.conf` for the personal login layout: Discord and
Firefox on `2:media`, Steam and a dedicated Alacritty terminal on `1:main`.
These applications start once per login; wallpaper-driven i3 restarts do not
launch them again. The terminal rule matches only the login terminal, so later
terminals can open on the current workspace. Copy `profiles/local-startup.sh.example` to
`~/.config/i3/local-startup.sh` for physical display commands. Both
destinations are ignored by Git so a work machine can use different values.

## Neovim development setup

The complete Neovim configuration and its pinned Lazy plugin lockfile live
under `home/.config/nvim/`. On first launch, Neovim bootstraps Lazy and installs
the pinned plugins, so the work rig does not need a second configuration clone.

The configuration requires Neovim 0.11 or newer for `vim.lsp.config()` and
`vim.lsp.enable()`. Ripgrep and fd support Telescope search, jdtls supplies the
Java language server, and Stylua and Prettier provide the configured formatters.
The required package names are listed in `packages/cachyos.txt`.

Neovim and Lualine read the active wallpaper palette from
`~/.cache/wal/colors.json`. The local theme derives higher-contrast UI surfaces,
syntax groups, diagnostics, Treesitter/LSP groups, Telescope, NvimTree, and Git
sign colors from that palette. It checks the cache every 1.5 seconds, so an
already-open editor follows the next wallpaper without restarting. If the cache
is absent or malformed, the pinned Nord theme remains the fallback. Run
`:WallpaperThemeReload` to request a manual reload and see which path was used.

Only configuration is portable. Lazy's downloaded plugins, Treesitter parsers,
undo files, caches, and other generated Neovim state remain outside this
repository. The old nested `.git` directory from the former standalone Neovim
repository must not be copied to the work rig.

## Visual design

The desktop uses a restrained glass style: ten-pixel tiled gaps, rounded Picom
corners and shadows, a floating Polybar, and a shared Meslo Nerd Font. GTK apps
use the CachyOS Nord theme, Pop icons, Capitaine cursors, and Fira Sans. The GTK
and Qt theme bridge in `.profile` takes effect at the next login; newly opened
GTK applications pick up their settings immediately.

Polybar keeps workspace labels compact and shows a palette-colored circle for
the focused or urgent workspace. Every label state has the same outer padding,
so adding the circle does not collapse the space between workspace numbers.

Picom starts on physical hosts. It skips actual virtual machines by default so
the work VM has a safe non-composited fallback. If Picom causes trouble on any
machine, run `touch ~/.config/picom/disable` to suppress it unconditionally.
Create `~/.config/picom/enable-in-vm` only when a VM's graphics stack has been
tested successfully; the disable marker takes precedence over that opt-in.

## Widget workspace and YouTube Music

Workspace 10 is named `10:widgets` and is reserved for persistent,
low-attention applications. Pear Desktop, Calcurse, Cava, and a compact Conky
system panel start with the i3 session and are assigned there without pulling
focus from the main workspace. `Mod+0` opens the widget workspace and restores
any card that was closed; `Mod+m` opens it and focuses or launches YouTube
Music.

The workspace follows a responsive three-column grid. Pear, Calcurse, and
Conky occupy 31-by-43-percent cards across the upper half, while Cava spans a
98-by-20-percent row beneath them. Cava and Conky regenerate their colors from
the active Pywal palette; Calcurse receives the same palette through
Alacritty's live color import.

Install the three widget applications with:

```bash
sudo pacman -S --needed cava calcurse conky
```

Each card remains a normal application: close one when it is not useful and
press `Mod+0` to restore it. Cava listens to the default PipeWire output and
its arrow keys adjust sensitivity and bar density. Calcurse stores personal
appointments in its standard XDG data directory; those files are deliberately
not part of the dotfiles repository.

The launcher prefers [Pear Desktop](https://github.com/pear-devs/pear-desktop),
an unofficial dedicated client, and falls back to a separate Firefox window
when Pear is not installed. Install the signed CachyOS package with:

```bash
sudo pacman -S --needed pear-desktop
```

At login, the music launcher waits five seconds, then waits up to another
30 seconds for the default audio output to appear. An idle/suspended output
counts as ready. If audio is still unavailable, it starts the player and logs
the timeout in `~/.local/state/i3/music-player.log`. It does not change the
focused workspace or duplicate a player opened during the wait. `Mod+M` remains
immediate, and the Firefox fallback is only used for an explicit music request.

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

## Flexible workspace sessions

The first three workspaces have light-purpose names without permanent
application routing: `1:main`, `2:media`, and `3:dev`. Ordinary `Mod+number`
navigation and `Mod+Shift+number` moves still work normally, so these names are
guides rather than restrictions.

Three optional launch actions prepare the common starting arrangement:

- `Mod+Ctrl+1` opens `1:main` and asks whether to start Steam or Heroic.
- `Mod+Ctrl+2` opens `2:media`, starts Discord if it is not already open, and
  ensures a separate Firefox window is present there.
- `Mod+Ctrl+3` opens `3:dev` and ensures it contains an Alacritty terminal.

The media action never moves an existing Discord window from another
workspace. The development terminal starts in `~/dev` when that directory
exists; set `DEV_WORKSPACE_DIR` to choose another default. After launch, every
window remains freely movable.

## Session polish

`Mod+p` opens a Pywal-colored Rofi control center; the gear at the right edge
of Polybar opens the same menu. It provides lock, audio, network, Bluetooth,
notification, wallpaper, desktop refresh, session, and power controls. Logout,
suspend, reboot, and shutdown require a second confirmation. Audio opens a
compact menu for mute, volume changes, and the advanced mixer. Network uses a
native Wi-Fi menu for radio control, scans, connection, disconnection, hidden
networks, and a private password prompt. Either mouse button on Polybar's
network readout opens it; right-clicking the volume readout opens Audio.
Bluetooth has a matching menu for power, discovery, pairing, trust, connection,
disconnection, and confirmed device removal. Devices that require an
interactive passkey exchange fall back to `bluetoothctl` in Alacritty.

Every custom Rofi pop-out is a managed floating window rather than an exclusive
keyboard grab. While one is open, i3 temporarily handles `Escape` (or
`Ctrl+G`) as an unconditional dismiss action and returns to its normal binding
mode. Menus are single-shot, so canceling a nested prompt never reopens its
parent, and simultaneous instances are refused.

`Mod+n`, the Polybar bell, or the Notifications row in the control center opens
a Rofi notification center. It lists recent app notifications, restores a
selected item, restores the newest item, closes visible notifications, clears
history with confirmation, and toggles Do Not Disturb. Volume and brightness
OSDs are filtered from this history. Middle-click the Polybar bell to toggle Do
Not Disturb directly; right-click it to close visible notifications. While
paused, the bell changes to a muted icon and includes the number waiting.

`Mod+l` opens a blurred lock screen with a centered clock, date, authentication
ring, and colors read from the current Pywal palette. Media and brightness keys
remain available while the session is locked.

The keyboard volume and brightness keys display short, replaceable Dunst
progress overlays. Polybar's volume module uses the same volume overlay when it
is clicked or scrolled. Brightness control prefers `brightnessctl`, then
XBacklight, and uses XRandR software dimming as a portable fallback for external
monitors without a backlight interface.

Three marked i3 scratchpads keep utility windows available without dedicating
workspace space. `Mod+grave` toggles a large Alacritty drop-down, `Mod+C`
toggles Qalculate GTK, and `Mod+Shift+A` toggles Pavucontrol. The first press
launches and centers the utility; later presses hide or restore the same window.
If an unmarked instance is already open, the helper adopts it instead of
starting a duplicate. Install the calculator frontend with
`sudo pacman -S --needed qalculate-gtk`.

## Login screen

LightDM's Slick Greeter has a separate system-wide appearance under
`system/lightdm/`: centered login, a static dark Nord mountain background,
Fira Sans, Pop icons, and Capitaine cursors. The clock, keyboard layout,
accessibility, session chooser, and power controls remain available. It uses
system-readable assets and does not need a home directory or Pywal cache.

This is an explicit system installation, separate from `manage.sh install`:

```bash
./scripts/login-screen.sh check
sudo ./scripts/login-screen.sh install
```

The installer requires an already active `lightdm-slick-greeter`, the desktop
theme packages, and `python-gobject`. It backs up both affected paths under
`/var/lib/dotfiles/login-screen-backups/` and prints the exact restore command.
The new appearance is used when the next greeter starts; the installer does
not restart LightDM or interrupt the desktop. See
[`docs/login-screen.md`](docs/login-screen.md) for preview and recovery steps.

## Auto-tiling and wallpaper colors

The i3 config runs the CachyOS/Arch `autotiling` package directly. The old
`quadrant-tiling.py` remains for reference but is not started; never run both
helpers together.

Put JPG, PNG, or WebP files in `~/.config/i3/wallpapers/images/`, and put MP4
files in `~/.config/i3/wallpapers/videos/`. Both directories are created
automatically and excluded from Git. At i3 startup, `live-wallpaper.sh` chooses
a static image when it detects a VM and otherwise prefers an MP4. If the
preferred directory is empty, automatic mode falls back to the available type.
Set `WALLPAPER_MODE=image` or `WALLPAPER_MODE=video` before i3 starts to force a
type. These settings may also be placed in the ignored machine-local
`~/.config/i3/wallpaper.env` file. Static mode uses feh and does not start
xwinwrap or MPV.

Press `Mod+Shift+N` to select another wallpaper and apply its colors through a
preserving i3 restart, or run `~/.config/i3/live-wallpaper.sh example.png` to
choose one by name. The selector avoids the three most recent choices when
enough alternatives exist.

For animated wallpapers, the X root underneath the animation is solid black,
so startup, player handoffs, and renderer failures never expose an unrelated
default image. During a normal change, the old wallpaper remains visible while
the next color palette is generated.

`wallpaper-rotation.sh` selects another wallpaper every 30 minutes. Set
`WALLPAPER_INTERVAL` in the environment before i3 starts to change the interval
in seconds, or set it to `0` to disable automatic rotation. Set
`WALLPAPER_HISTORY_SIZE` to change the three-wallpaper history, and set
`WALLPAPER_FALLBACK_COLOR` to another six-digit hex color if black is not
desired. The former `VIDEO_WALLPAPER_INTERVAL`,
`VIDEO_WALLPAPER_HISTORY_SIZE`, and `VIDEO_WALLPAPER_FALLBACK_COLOR` names
remain compatible.

Fullscreen applications automatically pause both the countdown and animated
wallpaper playback, including games left fullscreen on another workspace or
monitor. Exiting fullscreen resumes the remaining countdown and animation.
The fullscreen check also runs after palette generation, before i3 restarts,
so launching a game during an update defers that update until fullscreen ends.
If i3 cannot be queried, wallpaper changes wait until it is available again.

The control center (`Mod+P` or the Polybar gear) includes **Pause wallpaper
timer** and **Pause animation (still frame)**. Each becomes a Resume action
while paused. The timer control keeps the current wallpaper until resumed;
**Next wallpaper** remains available for manual changes. Animation pause holds
the current MP4 frame in MPV without decoding further frames or recoloring the
desktop. It applies to subsequent MP4 selections too. These two preferences
are independent and persist across logins in `~/.local/state/i3/`. A manual
animation pause remains in force when a fullscreen application closes.
Setting the rotation interval to `0` still allows automatic fullscreen
animation pausing; it only disables scheduled wallpaper changes.

Run `python3 scripts/test-wallpaper-controls.py` for the isolated fullscreen,
timer, and renderer regression checks.

Each selection asks `video-theme.sh` to run Pywal16 without replacing the
wallpaper. Static images are analyzed directly. For an MP4, it extracts and
scales a frame 35 percent into the video. Generated colors are consumed by i3,
Polybar, Rofi, Dunst, Neovim, and Fish/Alacritty terminals. Open Neovim sessions
watch the cache and refresh automatically. The Pywal output path is pinned to
`~/.cache/wal`, and the required generated templates and source image are
verified before the desktop reloads. The wallpaper log records the actual
generated i3 colors; a desktop notification points to that log if generation
fails. Override the automatic video frame time with `PYWAL_VIDEO_SEEK`, for
example `PYWAL_VIDEO_SEEK=00:00:30`.

The focused window has a two-pixel outline derived from a lightened palette
accent. Both i3 border fields use it. A global application rule covers newly
opened windows, while an i3-restart hook normalizes already-open windows such
as Steam and Discord that can retain a borderless state. Focus therefore stays
visible with either static or animated wallpapers. The generated i3 include
defines and consumes its own `$pywal_focus` variable because i3 parent configs
cannot consume variables defined inside an included file.

Install the two components on CachyOS with:

```bash
sudo pacman -S --needed autotiling
paru -S --needed python-pywal16-git
```

Install dependencies on CachyOS with the reviewed package names in
`packages/cachyos.txt`. Package installation is intentionally not automatic.

## Work VM quick start

The public repository can be installed without signing into GitHub:

```bash
git clone https://github.com/PandaKisor/dotfiles.git
cd dotfiles
./scripts/check.sh
./scripts/manage.sh install
mkdir -p ~/.config/i3/wallpapers/images
cp profiles/work-vm-wallpaper.env.example ~/.config/i3/wallpaper.env
cp profiles/work-vm-desktop.env.example ~/.config/i3/desktop.env
```

Copy one or more JPG, PNG, or WebP wallpapers into the new image directory,
then log out and back in. The copied work-VM profile forces static mode and
disables automatic rotation; use `Mod+Shift+N` when you want another image.
The desktop profile disables Cava, the dedicated music launcher (including
`Mod+M`), Playerctld startup, and Polybar's media module. Calendar and system
widgets remain available on `Mod+0`. Disabled Cava is excluded from recovery
and palette refreshes. With static mode and rotation disabled, the wallpaper
monitor exits and the control center hides timer and animation controls.
Both profile files are machine-local and ignored by Git. Log out and back in
after applying them to retire any music, Cava, or timer processes from the old
session. Apply these copies on the work VM only; omit `desktop.env` or set its
switches to `1` to retain the personal desktop behavior.
Without that profile, a detected VM still prefers static images automatically. Run
`touch ~/.config/picom/disable` if Picom needs to be suppressed explicitly;
the VM detector already skips it by default. Start Neovim once while online so
Lazy can download its pinned plugins.

For later updates, pull the public repository and rerun the installer. Existing
links consume changed files immediately; rerunning the installer adds links for
any newly tracked files:

```bash
cd ~/dotfiles
git pull --ff-only
./scripts/check.sh
./scripts/manage.sh install
```

Package installation remains a separate, deliberate step. CachyOS users can
review `packages/cachyos.txt`; on another distribution, install the equivalent
packages with its package manager before installing the links.
For this work profile, omit `cava`, `pear-desktop`, `playerctl`, `mpv`,
`ffmpeg`, and the optional `xwinwrap-git`; static wallpaper still uses `feh`
and Pywal16. These packages may remain installed if other applications use them.

## Publishing updates

The canonical remote is `git@github.com:PandaKisor/dotfiles.git`. Before
publishing an update:

1. Run `./scripts/check.sh`.
2. Review `git diff` and `git status --ignored`.
3. Rotate the old weather API key and use the ignored `weather.env` file.
4. Confirm your workplace permits each configuration and script.

No GitHub remote is configured by this repository.

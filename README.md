# dotfiles

An i3 desktop for CachyOS: Polybar, Picom, Rofi, Dunst, Alacritty, Fish,
Neovim, and a Pywal palette taken from the wallpaper (video or image) that
recolours everything when the wallpaper changes.

Files under `home/` mirror `$HOME`. They are installed as symlinks, so edits
in the repo take effect immediately.

## Install

```bash
./scripts/check.sh            # syntax, secrets, and i3 config validation
./scripts/manage.sh status    # what is linked, identical, different, missing
./scripts/manage.sh install   # link everything; replaced files are backed up
```

Backups go to `~/.local/state/dotfiles/backups/<timestamp>/`. Packages are a
separate, deliberate step: `packages/cachyos.txt` lists them (repo packages
first, AUR packages in comments at the end).

Then copy the personal profile and log out and back in:

```bash
cp profiles/home-i3.conf.example ~/.config/i3/config.d/90-local.conf
```

## Keys

| Key | Action |
| --- | --- |
| `Mod+Return` | Terminal |
| `Ctrl+Space` | App launcher |
| `Mod+p` | Control center (also the Polybar gear) |
| `Mod+n` | Notification center (also the Polybar bell) |
| `Mod+q` | Close window |
| `Mod+Arrows` / `Mod+Shift+Arrows` | Focus / move |
| `Mod+1..9` / `Mod+Shift+1..9` | Workspace / move window there |
| `Mod+0` | Widgets workspace (restores closed cards) |
| `Mod+Ctrl+1/2/3` | Start the game / media / dev arrangement |
| `Mod+h` `Mod+v` `Mod+t` | Split horizontal / vertical / toggle |
| `Mod+f` | Fullscreen |
| `Mod+s` `Mod+w` `Mod+e` | Stacked / tabbed / split layout |
| `Mod+Shift+Space` / `Mod+Space` | Float / switch focus between floating and tiled |
| `Mod+Shift+w` | Sticky |
| `Mod+r` | Resize mode |
| `` Mod+` `` | Drop-down terminal |
| `Mod+c` | Calculator |
| `Mod+Shift+a` | Audio mixer (Wiremix) |
| `Mod+Shift+k` | KeePassXC |
| `Mod+Shift+v` | Clipboard history |
| `Mod+Shift+s` or `Print` | Snip a region |
| `Shift+Print` / `Ctrl+Print` | Screenshot window / full screen |
| `Mod+Ctrl+s` | Flameshot (annotate) |
| `Mod+m` | Music (Pear, on the widgets workspace) |
| `Mod+Shift+f` / `Mod+Shift+b` | Thunar / btop |
| `Mod+Shift+n` | Next wallpaper |
| `Mod+l` | Lock |
| `Mod+Shift+c` / `Mod+Shift+r` / `Mod+Shift+e` | Reload / restart / exit i3 |

Scratchpads (drop-down terminal, calculator, mixer, KeePassXC) launch on the
first press and show/hide the same window after that.

## What's where

**Wallpaper and colours.** Put MP4s in `~/.config/i3/wallpapers/videos/` and
images in `~/.config/i3/wallpapers/images/` (not tracked). `live-wallpaper.sh`
plays video through xwinwrap + mpv (images through feh) and pauses the video
while anything is fullscreen. `video-theme.sh` runs Pywal16 on a frame, then
reloads i3, Polybar, Rofi, Dunst, the widgets, and open Neovim sessions.
Rotation is off by default because each change restarts i3; `Mod+Shift+n`
changes it on demand.

**Widgets workspace** (`10:widgets`). Pear (YouTube Music), a month calendar
(`calendar-card.py`), Conky (system, hardware, top processes), and Cava. A
monitor restores any card that closes. Geometry is in the i3 config's
`for_window` rules.

**Polybar.** Workspaces, the playing track (click to play/pause, middle/right
for previous/next), a red count of pending updates (click to upgrade), CPU,
memory, network, volume, date, notifications, and the control-center gear.

**Session.** The screen locks after 10 idle minutes and before suspend
(`xss-lock` + `idle-lock.sh`). The Polkit agent handles admin prompts.
greenclip records clipboard history; keep KeePassXC in
`blacklisted_applications` in `~/.config/greenclip.toml`.

**Neovim.** Full config with a pinned Lazy lockfile; plugins install on first
launch (needs Neovim 0.11+). The theme follows the Pywal palette.

**Login screen** (optional, system-wide). `./scripts/login-screen.sh check`,
then `sudo ./scripts/login-screen.sh install`. See
[`docs/login-screen.md`](docs/login-screen.md).

## Machine-local files (ignored by Git)

| File | Purpose | Example |
| --- | --- | --- |
| `~/.config/i3/config.d/90-local.conf` | Login apps, workspace assignments, refresh rate | `profiles/home-i3.conf.example` |
| `~/.config/i3/local-startup.sh` | Display commands run at login | `profiles/local-startup.sh.example` |
| `~/.config/i3/wallpaper.env` | `WALLPAPER_MODE`, `WALLPAPER_INTERVAL`, `PYWAL_SATURATE` (default `-0.15`) | `profiles/work-vm-wallpaper.env.example` |
| `~/.config/i3/desktop.env` | `CAVA_ENABLED`, `MUSIC_ENABLED`, `COMPOSITOR_MODE` | `profiles/work-vm-desktop.env.example` |
| `~/.config/greenclip.toml` | Clipboard history settings | — |

`COMPOSITOR_MODE` is `auto` (Picom on hardware, a lighter XRender profile in a
VM), `picom`, `vm`, `xcompmgr`, or `off`. `touch ~/.config/picom/disable` turns
compositing off entirely.

## Work VM

```bash
git clone https://github.com/PandaKisor/dotfiles.git && cd dotfiles
./scripts/check.sh && ./scripts/manage.sh install
mkdir -p ~/.config/i3/wallpapers/images
cp profiles/work-vm-wallpaper.env.example ~/.config/i3/wallpaper.env
cp profiles/work-vm-desktop.env.example ~/.config/i3/desktop.env
```

Add an image or two, log out and back in, and start Neovim once while online.
This profile uses static wallpapers, no music or Cava, and the XRender
compositor. Skip `cava`, `pear-desktop`, `mpv`, `ffmpeg`, and `xwinwrap-git`
when installing packages. To update later: `git pull --ff-only`, then
`./scripts/check.sh && ./scripts/manage.sh install`.

## Troubleshooting

Logs live in `~/.local/state/i3/`: `live-wallpaper.log`, `picom.log`,
`screenshot.log`, `music-player.log`, `autotiling.log`, and `widgets/`.
Polybar logs are in `~/.local/state/polybar/`.

Tests: `python3 scripts/test-*.py` (each runs in an isolated temp directory).

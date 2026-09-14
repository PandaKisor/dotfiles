# Current desktop state and future review

Last reviewed: 2026-09-14

Feature checkpoint: one-stop workstation configuration with Neovim and a
low-power static-wallpaper path for VMs

This is the handoff document for future desktop-polish work. Read it before
changing the configuration, then use `README.md` for installation details and
`docs/review-notes.md` for the original import and portability decisions.

## Intent and scope

- The current physical CachyOS machine is the visual and behavioral reference.
- A work machine will eventually consume the desktop and development
  configuration through a VM. Portability matters, but VM compromises should
  not reduce the quality of the physical desktop.
- The desired style is a cohesive, restrained Linux rice: wallpaper-aware,
  dark, rounded, responsive, and useful without filling the screen or Polybar
  with decorative modules.
- Files under `home/` mirror `$HOME` and are installed as individual symbolic
  links by `scripts/manage.sh`.
- Wallpaper media, generated caches, secrets, machine-specific display setup,
  and personal/work application assignments remain outside Git.
- The public GitHub remote is `PandaKisor/dotfiles`. Each update should be
  reviewed manually before publishing or using it at work.

## Current visual system

- i3 uses 10-pixel inner gaps, 8-pixel outer gaps, two-pixel borders, and a
  compact wallpaper-derived focused border.
- Picom supplies rounded corners, shadows, fading, and opacity on the physical
  host. `start-picom.sh` skips actual VMs unless the local untracked
  `~/.config/picom/enable-in-vm` marker exists. The local
  `~/.config/picom/disable` marker suppresses it on any host and takes
  precedence over the VM opt-in.
- Polybar spans the full output and floats eight pixels below the top edge. Its
  workspace selection is a compact circle-and-number marker rather than a wide
  filled block.
- Polybar is deliberately tray-free. Its right side currently contains media,
  CPU, memory, network, volume, date, notification, and control-center modules.
- Rofi, Dunst, i3, Polybar, and newly launched Alacritty/Fish sessions consume
  the current Pywal palette. GTK and Qt applications retain the coordinated
  Nord/Pop/Capitaine visual layer rather than being recolored per wallpaper.
- Rofi selected rows use a dark raised surface with a palette accent outline.
  Do not return to an arbitrary accent-filled row: some generated palettes had
  insufficient selected-text contrast.

## Implemented behavior

### Wallpaper and palette pipeline

- Put static JPG, PNG, or WebP files in `~/.config/i3/wallpapers/images/` and
  MP4 files in `~/.config/i3/wallpapers/videos/`; both are ignored by Git.
- In automatic mode, `live-wallpaper.sh` prefers static images in a VM and MP4
  video on a physical host, with a fallback to the available type.
- Static mode uses feh, requires no continuous decoder, and feeds the image
  directly to Pywal. Animated mode retains the xwinwrap/MPV pipeline.
- Selection excludes the three most recent wallpapers when enough alternatives
  exist.
- `wallpaper-rotation.sh` changes the wallpaper every 30 minutes by default.
- `video-theme.sh` analyzes static images directly or extracts a scaled frame
  35 percent into a selected video, then generates Pywal templates.
- Palette application intentionally uses a preserving `i3-msg restart`. A
  plain i3 reload did not reliably replace imported color variables. Do not
  change this back without proving every consumer updates immediately.
- The current wallpaper remains visible while the next palette is generated.
  The X root underneath animated media is solid black, so decoder startup or a
  renderer failure cannot reveal an old/default image.
- Wallpaper process cleanup is PID-scoped, with a narrow migration cleanup for
  xwinwrap/MPV processes using media from the configured video directory. A
  stale pre-PID Nebula renderer was previously the apparent fallback image.
- Selection and rotation locks prevent timer/manual races. The recent-history
  file lives under `~/.local/state/i3/`.

Environment overrides:

- `WALLPAPER_MODE` — `auto`, `image`, or `video`; VMs prefer images in `auto`.
- `WALLPAPER_INTERVAL` — rotation seconds; `0` disables rotation.
- `WALLPAPER_HISTORY_SIZE` — recent selections excluded; default `3`.
- `WALLPAPER_FALLBACK_COLOR` — X root hex color; default `#000000`.
- `IMAGE_WALLPAPER_DIR` — static JPG, PNG, and WebP directory.
- `VIDEO_WALLPAPER_DIR` — MP4 directory.
- `VIDEO_WALLPAPER_GPU_CONTEXT` — MPV GPU context.
- `PYWAL_VIDEO_SEEK` — explicit palette-frame seek instead of automatic 35%.

These values can be stored in the ignored `~/.config/i3/wallpaper.env` file.
`profiles/work-vm-wallpaper.env.example` forces static mode and disables timed
rotation for a constrained VM.

### Tiling and workspace layout

- The packaged `autotiling` IPC helper is active through
  `start-autotiling.sh`. The wrapper keeps one instance across i3 restarts and
  retires copies of the old `quadrant-tiling.py` helper.
- `quadrant-tiling.py` remains tracked only as reference. Never start it beside
  `autotiling` because both respond to the same window events.
- Workspace `10:widgets` holds persistent low-attention applications.
- Pear Desktop is assigned to the widget workspace and occupies a responsive
  31-by-43-percent card at the upper left. The intended workspace grid is three
  columns by four rows, with approximately 31-by-20-percent base cards.
- `music-player.sh` prefers Pear Desktop and falls back to a separate Firefox
  YouTube Music window. MPRIS/playerctld provides media keys and Polybar track
  controls.

### Session controls

- `control-center.sh` presents a palette-aware Rofi menu for lock, audio,
  network, Bluetooth, notifications, wallpaper selection, desktop refresh,
  suspend, logout, reboot, and shutdown.
- Suspend, logout, reboot, and shutdown require a separate confirmation.
- Network opens NetworkManager's graphical editor and falls back to `nmtui`.
  Bluetooth currently falls back to `bluetoothctl` in Alacritty because Blueman
  is not installed.
- `notification-center.sh` shows up to twelve recent application notifications
  and can restore a selected item, restore the newest item, close visible
  notifications, clear history with confirmation, or toggle Do Not Disturb.
- Volume and brightness Dunst OSD entries are intentionally filtered from the
  notification-center history.
- The Polybar bell changes to a muted icon during Do Not Disturb and includes
  the waiting count. Middle-click toggles DND; right-click closes visible
  notifications.
- The lock screen is blurred and palette-aware, with centered time/date and an
  authentication ring. Volume and brightness keys remain usable while locked.
- Volume and brightness keys display short, replaceable Dunst progress OSDs.
  Brightness control falls back through brightnessctl, XBacklight, and XRandR
  software dimming.

## Important shortcuts

| Shortcut | Behavior |
| --- | --- |
| `Ctrl+Space` | Rofi application launcher |
| `Mod+P` | Rofi desktop control center |
| `Mod+N` | Rofi notification center |
| `Mod+L` | Palette-aware lock screen |
| `Mod+M` | Open/focus YouTube Music on the widget workspace |
| `Mod+0` | Open `10:widgets` |
| `Mod+Shift+N` | Select another video and regenerate the palette |
| `Mod+Shift+S` | Flameshot region capture |
| `Mod+Shift+V` | CopyQ clipboard history |
| `Mod+Shift+A` | Pavucontrol |
| `Mod+Shift+F` | Thunar |
| `Mod+Shift+B` | Btop in Alacritty |
| `Mod+Shift+K` | KeePassXC |
| `Mod+Shift+C` | Reload i3 configuration |
| `Mod+Shift+R` | Restart i3 while preserving the window tree |

Standard `Mod+1` through `Mod+0` workspace navigation and matching
`Mod+Shift+number` window moves are also active.

## File map

| Area | Primary tracked files |
| --- | --- |
| i3 layout and bindings | `home/.config/i3/config` |
| Wallpaper selection | `home/.config/i3/live-wallpaper.sh` |
| Rotation daemon | `home/.config/i3/wallpaper-rotation.sh` |
| Image/video palette extraction | `home/.config/i3/video-theme.sh` |
| Rofi control center | `home/.config/i3/control-center.sh` |
| Rofi notifications | `home/.config/i3/notification-center.sh` |
| Lock and OSDs | `home/.config/i3/lock-screen.sh`, `volume-osd.sh`, `brightness-osd.sh` |
| Tiling lifecycle | `home/.config/i3/start-autotiling.sh` |
| Widget music launcher | `home/.config/i3/music-player.sh` |
| Polybar | `home/.config/polybar/config.ini`, `launch.sh`, `scripts/` |
| Rofi appearance | `home/.config/rofi/config.rasi` |
| Dunst | `home/.config/dunst/dunstrc` |
| Picom | `home/.config/picom/picom.conf`, `home/.config/i3/start-picom.sh` |
| Pywal templates | `home/.config/wal/templates/` |
| Neovim | `home/.config/nvim/`, including `lazy-lock.json` |
| Package inventory | `packages/cachyos.txt` |
| Machine-local examples | `profiles/`, including the work-VM wallpaper profile |

## Verified baseline

At this checkpoint:

- All tracked shell scripts pass `bash -n`; the repository check script passes.
- Rofi control and notification menus were rendered and inspected against live
  wallpaper palettes.
- The notification-history index-to-Dunst-ID mapping was tested, including the
  System OSD exclusion.
- Do Not Disturb active/paused status output was tested and restored to off.
- Polybar loaded the control and notification modules without errors or
  deprecated-property warnings.
- Live process checks showed one Polybar, one Picom, one autotiling client, and
  one xwinwrap/MPV wallpaper pair after migration cleanup.
- `scripts/manage.sh status` reported the newly added control and notification
  scripts linked into the live home configuration.

Useful review commands:

```bash
./scripts/manage.sh status
./scripts/check.sh
git status --short
git log --oneline -12
```

Useful live logs:

- `~/.local/state/i3/live-wallpaper.log`
- `~/.local/state/i3/wallpaper-rotation.log`
- `~/.local/state/i3/autotiling.log`
- `~/.local/state/i3/picom.log`
- `~/.local/state/polybar/*.log`

## Known boundaries

- Wallpaper media are local-only and must be copied separately. Static images
  are the recommended low-power choice for the work VM.
- Pywal updates existing desktop components through an i3 restart, but existing
  terminal/application processes may retain colors until they are reopened.
- There is no system tray by design; `nm-applet` is therefore disabled.
- Network and Bluetooth controls are launchers, not native Rofi device/SSID
  submenus yet.
- The work VM still needs an independent graphics test. Picom is disabled there
  by default, can be disabled explicitly with `~/.config/picom/disable`, and
  static wallpapers are selected automatically when images are available.
- Weather credentials remain local in the ignored
  `~/.config/polybar/weather.env`. Never commit that file or another API key.
- Neovim configuration and its plugin lockfile are included in this repository.
  Downloaded plugins, parsers, caches, undo history, and the former standalone
  repository's nested `.git` directory remain local-only.

## Optional future polish

The desktop is stable enough to pause. Remaining work is discretionary, in this
rough order:

1. Add named scratchpads for a dropdown terminal, calculator, and audio mixer.
2. Add only two or three restrained residents to `10:widgets`, such as a
   calendar, Cava visualizer, or compact system panel.
3. Give common workspaces names and optionally add machine-local application
   routing after the user's real workflow is known.
4. Replace the NetworkManager/Bluetooth launcher fallbacks with native Rofi
   Wi-Fi and Bluetooth selection submenus if that would improve daily use.
5. Consider LightDM, Plymouth, and GRUB styling last. Those changes are more
   system-specific, riskier to transport, and less valuable during daily use.

Avoid adding modules merely to make the bar busier. The current direction
favors a few cohesive entry points—Rofi, the widget workspace, and contextual
Polybar controls—over persistent visual clutter.

## How to resume safely

1. Read this file, `README.md`, and `docs/review-notes.md`.
2. Run the four review commands above before editing.
3. Treat unrelated working-tree changes as user-owned and preserve them.
4. Use the ignored local profiles for machine-specific displays, applications,
   work policy, credentials, or VM overrides.
5. After adding a new tracked file under `home/`, run
   `./scripts/manage.sh install`; existing symlinks update automatically, but a
   new file needs its own link.
6. Validate script syntax and `./scripts/check.sh`, then test only the affected
   live component.
7. For visual changes, inspect an actual live render under more than one Pywal
   palette when color contrast is involved.
8. Recheck the relevant process count and logs after i3/Polybar lifecycle
   changes.
9. Delete temporary screenshots and test artifacts before committing.
10. Update this checkpoint when a new polish phase is complete.

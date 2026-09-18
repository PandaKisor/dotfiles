# Current desktop state and future review

Last reviewed: 2026-09-18

Feature checkpoint: one-stop workstation configuration with Neovim and a
low-power static-wallpaper path for VMs

This is the handoff document for future desktop-polish work. Read it before
changing the configuration, then use `README.md` for installation details and
`docs/review-notes.md` for the original import and portability decisions.

## Intent and scope

- The current physical CachyOS machine is the visual and behavioral reference.
- A work machine also consumes the desktop and development configuration
  through a VM. Portability matters, but VM compromises should not reduce the
  quality of the physical desktop.
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

- i3 uses 10-pixel inner gaps, 8-pixel outer gaps, and a two-pixel focused
  outline derived from a lightened wallpaper accent. Both i3 border fields use
  it. A global rule covers new application windows, and an i3-restart hook
  restores borders on already-open windows such as Steam and Discord.
- Picom supplies rounded corners, shadows, fading, and opacity on the physical
  host. `start-picom.sh` selects a separate XRender `vm.conf` on VMs, retaining
  corners, shadows, and opacity without OpenGL, blur, or animations. An error
  exit or absent Picom triggers one xcompmgr fallback attempt. That fallback
  supports shadows and application transparency, but no rounded corners or
  Picom opacity rules. `COMPOSITOR_MODE=auto|vm|picom|xcompmgr|off` in the local
  `desktop.env` overrides selection. The legacy `enable-in-vm` marker selects
  the physical profile in auto mode; `~/.config/picom/disable` suppresses both
  compositors in every mode. Mode changes take effect after logout/login.
- Polybar spans the full output and floats eight pixels below the top edge. Its
  workspace selection is a compact circle-and-number marker rather than a wide
  filled block. Focused and urgent markers use the same one-cell outer padding
  as ordinary workspace numbers, so their state circle does not crowd either
  neighbor.
- Polybar is deliberately tray-free. Its right side currently contains media,
  CPU, memory, network, volume, date, notification, and control-center modules.
- Rofi, Dunst, i3, Polybar, Neovim, and newly launched Alacritty/Fish sessions
  consume the current Pywal palette. GTK and Qt applications retain the
  coordinated Nord/Pop/Capitaine visual layer rather than being recolored per
  wallpaper.
- Rofi selected rows use a dark raised surface with a palette accent outline.
  Do not return to an arbitrary accent-filled row: some generated palettes had
  insufficient selected-text contrast.
- Neovim's local theme reads `~/.cache/wal/colors.json`, derives contrast-safe
  editor, syntax, diagnostic, plugin, and Lualine colors, and checks the cache
  every 1.5 seconds. Open sessions therefore follow wallpaper changes. The
  pinned `nord.nvim` theme remains the fallback for a missing or malformed
  cache, and `:WallpaperThemeReload` provides a manual refresh command.

## Implemented behavior

### Work VM profile

- VM wallpaper troubleshooting: a missing `jq` previously made the fullscreen
  guard wait forever while holding the selection lock. Desktop waits now fail
  explicitly for missing `jq` or `i3-msg`, log when waiting, and competing
  selectors preserve the active log. Nine isolated wallpaper checks pass,
  including missing-tool failures and lock release. The user confirmed the
  wallpaper now loads and Pywal16 installation restored theme switching.
- Eleven isolated compositor checks cover physical/container/VM selection,
  fallback with absent or failed Picom, explicit modes, old markers, existing
  compositors, duplicate starts, shutdown, and lock release. An actual Picom
  XRender session in Xvfb passed screenshot/pixel checks for all three effects:
  rounded corners, shadow darkening, and 75-percent application opacity.
  Xcompmgr execution is covered by a stub here (the binary is not installed on
  the primary host); its visual behavior and the VM GPU remain unverified.
- Copy `profiles/work-vm-desktop.env.example` to the ignored
  `~/.config/i3/desktop.env` on the VM. `CAVA_ENABLED=0` excludes Cava from
  startup, recovery, direct widget launches, and palette refreshes.
  `MUSIC_ENABLED=0` disables the music launcher, its browser fallback,
  Playerctld startup, and Polybar's media module. Calendar and Conky remain.
- Pair it with `profiles/work-vm-wallpaper.env.example` in
  `~/.config/i3/wallpaper.env`: static wallpaper, manual changes, and no
  persistent wallpaper polling. Static mode rejects explicit MP4 requests too.
  The control center omits inactive timer and animation controls.
- Apply these profiles only on the VM and log out/in to retire old processes.
  The physical desktop retains its defaults when `desktop.env` is absent.
  The user has deployed the VM; the new compositor profile still needs VM
  installation and visual verification. Its xcompmgr package must be installed
  separately, and the dotfiles installer must link the new `picom/vm.conf`.
- Repository checks, six music checks, seven wallpaper checks, and widget
  recovery checks pass. Isolated work-profile checks confirm Cava stays off
  while Calendar/Conky still launch, and Polybar/control-center menus omit the
  disabled features. No work profile was installed on the physical host.

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
- Fullscreen application containers pause the remaining rotation countdown and
  MPV animation automatically. This includes other workspaces and outputs;
  workspace-level fullscreen flags do not count as fullscreen applications.
  The daemon checks every two seconds and remains active for animation control
  when `WALLPAPER_INTERVAL=0`. Failed i3 queries defer changes as well.
- The control center has independent timer pause/resume and animation
  pause/resume controls. Animation pause holds the current MP4 frame through
  MPV IPC, without another palette generation or i3 restart. Manual pause
  choices persist in `~/.local/state/i3/wallpaper-{rotation,animation}-paused`.
  Animation remains paused across new selections and after a game closes until
  explicitly resumed. Next wallpaper still works with the timer paused.
- Scheduled selections recheck fullscreen/manual pause after taking their lock.
  The palette loader checks again before reloading desktop consumers and
  restarting i3, covering games launched while ffmpeg/Pywal was running. Manual
  wallpaper changes also wait for fullscreen applications to exit.
- MPV exposes a private runtime IPC socket. `live-wallpaper.sh --current`
  upgrades an older renderer using the same wallpaper without changing its
  palette or history. The applied wallpaper is saved in `current-wallpaper`.
- `video-theme.sh` analyzes static images directly or extracts a scaled frame
  35 percent into a selected video, then generates Pywal templates.
- Pywal output is pinned to `~/.cache/wal`; the palette source and required
  generated templates are verified before consumers reload. The wallpaper log
  records the generated i3 colors, and palette failures raise a visible Dunst
  notification instead of failing silently.
- The generated i3 include defines and consumes its `$pywal_*` variables in the
  same file, then directly overrides the fallback `client.*` directives. A
  parent i3 config cannot consume variables defined by an included file.
- Palette application intentionally uses a preserving `i3-msg restart`. A
  plain i3 reload did not reliably replace generated client colors. Do not
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
- Workspaces 1 through 3 are lightly named `1:main`, `2:media`, and `3:dev`.
  They have no permanent application assignments. `workspace-session.sh`
  offers optional game, media, and development starting arrangements while
  leaving every resulting window freely movable.
- Pear Desktop, Calcurse, and the Conky system panel occupy responsive
  31-by-43-percent cards across its upper half. Cava occupies a wide
  98-by-20-percent card below them. `widget-workspace.sh` starts missing cards,
  prevents duplicates, and restores closed cards whenever `Mod+0` is pressed.
- Widget recovery uses `i3-widget-launch-$UID.lock`; child applications never
  inherit it. The former `i3-widgets-$UID.lock` could remain held by Calcurse
  after Cava closed, blocking all subsequent recovery. Existing calendar
  windows can stay open through this migration. Cava errors now go to
  `~/.local/state/i3/widgets/cava.log` for diagnosing unexpected exits.
- A session-owned widget monitor checks the cards every five seconds and
  restores any missing application without changing the focused workspace.
  Its own singleton lock is closed in launcher and sleep children, preventing
  stale descendants from blocking recovery after logout or session restart.
  A live close-and-recovery check replaced the Cava process within seven
  seconds while retaining exactly one visualizer window.
- Cava's gradient and Conky's panel colors come directly from the active Pywal
  cache and refresh when the wallpaper changes. Calcurse inherits the same
  palette from Alacritty while keeping its personal calendar data untracked.
  Cava's generated config is replaced only when its contents change; rewriting
  identical contents during the five-second recovery check caused live reload
  to repeatedly reset the visualizer.
- `music-player.sh` prefers Pear Desktop and falls back to a separate Firefox
  YouTube Music window. MPRIS/playerctld provides media keys and Polybar track
  controls.
- Its login-only `--autostart` mode waits five seconds, then checks for an
  available default audio sink for up to 30 additional seconds. Idle/suspended
  outputs count as ready. A timeout is logged before starting anyway. Startup
  does not change workspace or open the browser fallback, and it skips a player
  already present, including one opened during the wait. `Mod+M` stays immediate.
- The personal `90-local.conf` profile starts Discord and Firefox on `2:media`,
  and Steam plus a dedicated Alacritty terminal on `1:main`. These are login-only
  `exec` entries. The terminal assignment matches its `i3-main-startup` instance,
  leaving ordinary, scratchpad, and widget terminals alone. New Discord,
  Firefox, and Steam windows use the personal workspace assignments; all windows
  remain movable. The portable default remains free of personal app startup.
- `scratchpad.sh` manages marked, reusable terminal, Qalculate GTK, and
  Pavucontrol windows. It adopts an existing matching window, or launches and
  centers one on first use, then toggles the same container thereafter.

### Session controls

- `control-center.sh` presents a palette-aware Rofi menu for lock, audio,
  network, Bluetooth, notifications, wallpaper selection, desktop refresh,
  suspend, logout, reboot, and shutdown.
- Suspend, logout, reboot, and shutdown require a separate confirmation.
- Audio opens a native menu for mute, five-percent volume changes, and the
  advanced mixer. Polybar's volume readout opens it on right-click.
- Network opens a native Rofi Wi-Fi menu with radio, scan, connect, disconnect,
  hidden-network, and password-prompt controls. New secrets travel to nmcli on
  stdin instead of appearing in process arguments. The Polybar network module
  opens this menu with either left- or right-click; its Advanced row retains
  access to the full NetworkManager editor.
- Bluetooth opens a matching Rofi menu for controller power, scanning,
  pairing, trust, connection, disconnection, and confirmed device removal.
  Passkey-based devices retain an explicit interactive terminal fallback.
- Custom Rofi pop-outs run as managed floating windows through `rofi-popup.sh`,
  not exclusive keyboard-grab windows. i3 enters `popup-menu` only while the
  window exists; `Escape` or `Ctrl+G` runs `dismiss-popup.sh`, kills any stale
  Rofi process, and returns immediately to the default binding mode. Menus do
  not refresh their parent after an action or cancellation, and the wrapper
  refuses simultaneous instances.
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
| `Mod+grave` | Toggle the terminal scratchpad |
| `Mod+C` | Toggle the calculator scratchpad |
| `Mod+0` | Open `10:widgets` |
| `Mod+Ctrl+1` | Open `1:main` and choose Steam or Heroic |
| `Mod+Ctrl+2` | Prepare Discord and Firefox on `2:media` |
| `Mod+Ctrl+3` | Ensure a terminal is available on `3:dev` |
| `Mod+Shift+N` | Select another wallpaper and regenerate the palette |
| `Mod+Shift+S` | Flameshot region capture |
| `Mod+Shift+V` | CopyQ clipboard history |
| `Mod+Shift+A` | Toggle the audio mixer scratchpad |
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
| Fullscreen and wallpaper pause controls | `home/.config/i3/wallpaper-controls.sh` |
| Image/video palette extraction | `home/.config/i3/video-theme.sh` |
| Rofi control and connectivity | `home/.config/i3/control-center.sh`, `audio-menu.sh`, `network-menu.sh`, `bluetooth-menu.sh`, `rofi-popup.sh`, `dismiss-popup.sh` |
| Rofi notifications | `home/.config/i3/notification-center.sh` |
| Lock, scratchpads, and OSDs | `home/.config/i3/lock-screen.sh`, `scratchpad.sh`, `volume-osd.sh`, `brightness-osd.sh` |
| Login screen | `system/lightdm/`, `scripts/login-screen.sh`, `docs/login-screen.md` |
| Tiling lifecycle | `home/.config/i3/start-autotiling.sh` |
| Flexible workspace sessions | `home/.config/i3/workspace-session.sh` |
| Widget music launcher | `home/.config/i3/music-player.sh` |
| Polybar | `home/.config/polybar/config.ini`, `launch.sh`, `scripts/` |
| Rofi appearance | `home/.config/rofi/config.rasi` |
| Dunst | `home/.config/dunst/dunstrc` |
| Compositors | `home/.config/picom/picom.conf`, `home/.config/picom/vm.conf`, `home/.config/i3/start-picom.sh` |
| Pywal templates | `home/.config/wal/templates/` |
| Neovim | `home/.config/nvim/`, including `lua/config/theme.lua` and `lazy-lock.json` |
| Package inventory | `packages/cachyos.txt` |
| Machine-local examples | `profiles/`, including the work-VM wallpaper profile |

## Verified baseline

At this checkpoint:

- Four isolated music startup checks pass: delayed audio readiness (including
  an idle sink), bounded timeout, an already-open player, and a player opened
  during the wait. The personal login profile is installed as `90-local.conf`,
  and the full live i3 configuration passes `i3 -C`. A fresh login remains the
  end-to-end check for the reported initial music playback issue.
- Six isolated wallpaper regression checks pass: container/global fullscreen
  detection and IPC failure, timer toggles, skipped scheduled changes, remaining
  countdown preservation, fullscreen during palette generation, renderer
  migration, and preventing sleep from inheriting the timer lock.
- An isolated real i3/MPV session verified fullscreen animation pause/resume,
  manual pause surviving fullscreen exit, and animation control with rotation
  disabled. The expanded control-center menu was rendered as a floating popup.
- The updated wallpaper renderer and timer are active on the physical desktop.
  The existing video and palette were preserved, focus stayed on the same
  window, and a live MPV check confirmed its playback position stops while
  paused. Playback was restored to its original running state after testing.
  The old timer's orphaned sleep process was retired because it inherited the
  rotation lock; the new daemon closes that descriptor for its sleep child.
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
- The static-image and video theme paths generated distinct palettes in
  isolated caches, including their lightened focus colors. The full static
  selector path also passed with isolated state and mocked desktop reloads.
- A live preserving restart on the primary rig restored both Steam and Discord
  to `pixel` borders at width `2`, then loaded the current palette-derived
  focus color. Screenshot pixel inspection confirmed the rendered border uses
  the generated teal after Picom frame opacity, not the pale static fallback.
- The terminal scratchpad passed a live first-launch, mark, geometry, border,
  show, and hide test. Pavucontrol passed the same live adoption and hide test,
  and the user confirmed the Qalculate GTK scratchpad is working as intended.
- The completed widget workspace was rendered and inspected at 2560 by 1440.
  Pear, Calcurse, and Conky align in three equal upper cards; Cava fills one
  wide lower card without obscuring the remaining wallpaper. `Mod+0` focused
  the exact named workspace and a repeat launch kept one instance of each
  managed widget. A live palette refresh replaced Conky, reloaded Cava, and
  restored the intended geometry after Conky's initial X11 placeholder map.
- Existing workspaces 1 and 2 were renamed in place without moving their
  windows. The media action focused the existing Discord and Firefox pair on
  `2:media` without duplication. Two consecutive development actions created
  and retained exactly one Alacritty window on `3:dev`, then focus was returned
  to `1:main`.
- The Wi-Fi and Bluetooth menu status paths were checked against the live
  NetworkManager and BlueZ session without changing either radio. Mocked menu
  tests covered escaped and duplicate SSIDs, multiword device names, connection
  selection, and connected/paired device actions. Both menus were rendered and
  inspected under the live Pywal palette without selecting an action.
- Polybar restarted with all ten modules and no config warnings. A bar-only
  screenshot confirmed even spacing around the active workspace circle after
  focused and urgent padding were normalized.
- A live X11 test confirmed the managed Audio popup entered `popup-menu`, an
  Escape event left zero Rofi processes, and i3 returned to `default`. A
  controlled click on the rendered Polybar network label opened the Wi-Fi menu
  and entered the same safe popup mode.
- Headless Neovim tests loaded the current Pywal foreground/background, selected
  Nord with an empty cache, and observed an open editor change background after
  an atomic `colors.json` replacement. Lualine's normal-mode color changed in
  the same watcher event, proving its dynamic theme refreshed too.

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
- `~/.local/state/i3/widgets/widgets.log`
- `~/.local/state/polybar/*.log`

## Known boundaries

- Wallpaper media are local-only and must be copied separately. Static images
  are the recommended low-power choice for the work VM.
- Pywal updates existing desktop components through an i3 restart. The managed
  Cava and Conky widgets refresh explicitly, and Alacritty reloads its imported
  palette; unrelated applications may retain colors until they are reopened.
- There is no system tray by design; `nm-applet` is therefore disabled.
- The work VM is operational and exposed the static-palette issue addressed in
  this pass. The application focus-outline correction was observed on the
  primary personal rig. VMs now select the Picom XRender profile with an
  xcompmgr fallback; `~/.config/picom/disable` still disables all compositing.
  Static wallpapers are selected automatically when images are available.
- Weather credentials remain local in the ignored
  `~/.config/polybar/weather.env`. Never commit that file or another API key.
- Neovim configuration and its plugin lockfile are included in this repository.
  Downloaded plugins, parsers, caches, undo history, and the former standalone
  repository's nested `.git` directory remain local-only.

## Optional future polish

The login-screen pass now targets the already active LightDM Slick Greeter:
centered login, dark static Nord mountains, Fira Sans, Pop icons, and Capitaine
cursors. `scripts/login-screen.sh` separately installs system-readable copies,
preserves rollback snapshots, and never restarts the display manager. The
schema validation and isolated real-greeter test render passed. Isolated install
and restore checks passed for absent files, existing files, and symlink targets.
Slick test mode uses fake users and fixed small monitors; authentication and physical monitor
placement still require a real login. See `docs/login-screen.md` for recovery.
System installation is pending: the elevated installer reached sudo, which
requires interactive authentication. Run the documented install command in a
local terminal; no live system files were changed by this pass.

The desktop is stable enough to pause. Remaining work is discretionary, in this
rough order:

1. Refine the existing lock screen's composition and authentication feedback,
   then validate it against both bright and dark wallpaper palettes.
2. Confirm the new Slick Greeter appearance and physical monitor placement at
   the next normal login. Refine it alongside future lock-screen polish.

Plymouth and GRUB styling are no longer active goals. They add system-specific
risk and little day-to-day value; reconsider them only if boot visuals become a
real priority later.

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

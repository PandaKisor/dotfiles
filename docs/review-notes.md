# Initial review notes

## Imported

- i3, including the existing quadrant helper
- Picom
- Polybar, with the weather integration rewritten to keep its key private
- Alacritty, Dunst, Rofi, GTK 2/3/4 settings, the login theme bridge, the
  hand-written Fish config, and the complete Neovim configuration and plugin
  lockfile

Backup files and generated application state were not imported.

## Issues fixed in this pass

- Removed the broken `tumblerd` startup command. The installed binary is not
  on `PATH`, and Tumbler already provides D-Bus activation.
- Corrected the update script, which checked the repository count twice and
  never validated the AUR count.
- Bounded Polybar's shutdown wait at five seconds and moved logs out of `/tmp`.
- Enabled Picom damage tracking and removed its obsolete experimental-backend
  switch. This avoids unnecessary full-screen repainting behind a 4K video.
- Replaced broad wallpaper process matching with a PID file scoped to the
  current user.
- Removed the embedded weather key and automatic IP-geolocation request.
- Added a consistent visual layer across i3, Picom, Polybar, Rofi, Dunst,
  Alacritty, GTK applications, and Qt applications using the GTK bridge.
- Added a palette-aware Rofi control center with keyboard and Polybar entry
  points. Destructive session and power choices use a separate confirmation.
- Added a Dunst-backed Rofi notification center and stateful Polybar indicator.
  Desktop OSD events are filtered from the user-facing notification history.
- Corrected Picom host detection so development containers do not make this
  physical desktop look like a VM; only full virtual machines skip it.

## Portability decisions

- `autotiling` replaces the custom quadrant helper at startup. The old helper
  remains as reference, but the two must not run together. A PID-scoped wrapper
  retires legacy copies and restarts exactly one autotiling IPC client after an
  i3 restart.
- The wallpaper launcher supports static JPG/PNG/WebP images and MP4 videos,
  keeps the three most recent choices out of the candidate pool, and rotates
  every 30 minutes. Automatic mode prefers static images in a VM and video on a
  physical host. Pywal16 analyzes images directly or a frame 35 percent into a
  selected animation. The current wallpaper remains visible during palette
  generation, and the X root is solid black underneath video for startup and
  player handoffs. The launcher also retires renderers left by the older,
  pre-PID implementation. i3 and Rofi have static fallbacks when the Pywal cache
  does not exist; Polybar selects a static fallback from its launch script.
- Neovim and Lualine now read the same `colors.json` cache through a local
  contrast-aware theme module. A lightweight timer refreshes open sessions when
  Pywal atomically replaces the cache, while `nord.nvim` remains available when
  no valid palette exists.
- VMs now select a separate Picom XRender profile with xcompmgr as a fallback
  after an error exit; see README for local mode selection and the fallback's
  lack of rounded corners. The old `enable-in-vm` marker selects the physical
  Picom profile in auto mode. `~/.config/picom/disable` suppresses both
  compositors and always takes precedence.
- Display layout moved out of the portable i3 config. Use
  `profiles/local-startup.sh.example` as the per-machine starting point.
- Personal app assignments and startup (including Steam and Discord) moved to
  `profiles/home-i3.conf.example`; they will not be enabled at work by default.
- Wallpaper media are excluded because they are personal, machine-local assets
  and the current video is about 144 MB.

## Deliberately excluded

- The original weather script contained an API key. Its replacement reads an
  ignored `~/.config/polybar/weather.env` and no longer submits automatic IP
  geolocation requests. Rotate the old key before using the replacement.
- Neovim's downloaded plugins, Treesitter parsers, caches, undo history, and
  former standalone `.git` metadata are generated or local state. Only its
  configuration and pinned Lazy lockfile are imported.
- `fish_variables` is generated state and often includes machine-specific
  universal variables.
- The Fish greeting now falls back to Fastfetch defaults when its separate
  config has not been imported.

## Still to review

The rest of `~/.config` includes application data as well as configuration.
Import items one at a time only after checking for accounts, tokens, absolute
paths, cache data, and work-specific policy constraints.

The unused Polybar typing-speed script still names one specific Bluetooth
keyboard. If that module is enabled later, its device should move to a local
setting. Picom, Polybar, and the palette-generated styling passed a live X11
visual test on the physical desktop; the work VM still needs its own compositor
test before opting in there.

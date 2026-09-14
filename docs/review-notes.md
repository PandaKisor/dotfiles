# Initial review notes

## Imported

- i3, including the existing quadrant helper
- Picom
- Polybar, with the weather integration rewritten to keep its key private
- Alacritty, Dunst, Rofi, and the hand-written Fish config

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

## Portability decisions

- `autotiling` replaces the custom quadrant helper at startup. The old helper
  remains as reference, but the two must not run together.
- The wallpaper launcher selects from every MP4 in its media directory, keeps
  the three most recent choices out of the candidate pool, and rotates every
  30 minutes. Pywal16 colors come from a frame 35 percent into the selected
  animation. i3 and Rofi have static fallbacks when the Pywal cache does not
  exist; Polybar selects a static fallback from its launch script.
- Picom is skipped automatically in a detected VM. Create the untracked file
  `~/.config/picom/enable-in-vm` to opt in on a capable VM.
- Display layout moved out of the portable i3 config. Use
  `profiles/local-startup.sh.example` as the per-machine starting point.
- Personal app assignments and startup (including Steam and Discord) moved to
  `profiles/home-i3.conf.example`; they will not be enabled at work by default.
- Wallpaper media are excluded because the current video is about 144 MB and
  is a poor fit for an ordinary Git repository.

## Deliberately excluded

- The original weather script contained an API key. Its replacement reads an
  ignored `~/.config/polybar/weather.env` and no longer submits automatic IP
  geolocation requests. Rotate the old key before using the replacement.
- `~/.config/nvim` is already its own Git repository with an `origin` remote.
  Keep it separate or reference it later as a submodule.
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
setting. Picom also needs a visual test in a real X11 session; this environment
does not expose its display socket.

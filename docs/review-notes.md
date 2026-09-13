# Initial review notes

## Imported

- i3, including the existing quadrant helper
- Picom
- Polybar, except the weather integration
- Alacritty, Dunst, Rofi, and the hand-written Fish config

Backup files and generated application state were not imported.

## Portability decisions

- `autotiling` is the default i3 tiling mode. The launcher also accepts
  `autotiling-rs` if that is what a machine has installed.
- `quadrant` preserves the existing custom 1/2/3/4-window behavior, and `off`
  disables both. Change the single word in `~/.config/i3/autotiling-mode`.
- Picom is skipped automatically in a detected VM. Create the untracked file
  `~/.config/picom/enable-in-vm` to opt in on a capable VM.
- Display layout and wallpaper startup moved out of the portable i3 config.
  Use `profiles/local-startup.sh.example` as the per-machine starting point.
- Personal app assignments and startup (including Steam and Discord) moved to
  `profiles/home-i3.conf.example`; they will not be enabled at work by default.
- Wallpaper media are excluded because the current video is about 144 MB and
  is a poor fit for an ordinary Git repository.

## Deliberately excluded

- `polybar/scripts/weather-openmap.sh` contains an API key. Before tracking it,
  change the script to read the key from an ignored environment file or secret
  manager, then rotate the exposed key.
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

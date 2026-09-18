# Login screen appearance

The physical reference machine runs LightDM with **Slick Greeter**. Its
`lightdm-gtk-greeter.conf` belongs to a different, inactive greeter. The new
configuration targets `/etc/lightdm/slick-greeter.conf`; the authentication
configuration and selected greeter in `lightdm.conf` stay intact.

The design uses a centered login card, a dark geometric mountain background,
the installed `cachyos-nord` GTK theme, Pop icons, Capitaine cursors, and Fira
Sans 12. The background is an original SVG in this repository. It repeats on
each monitor and disables per-user wallpaper substitutions. Automatic HiDPI
and monitor selection retain Slick's defaults.

Configuration keys were checked against the installed Slick 2.2.7 schema and
the [upstream configuration documentation](https://github.com/linuxmint/slick-greeter#configuration).

## Preview

The optional preview requires `bubblewrap`, `xorg-server-xvfb`, `imagemagick`,
`python-gobject`, and `dbus`. Run it as your normal user:

```bash
python3 scripts/login-screen-preview.py --output /tmp/login-screen-preview.png
```

The script runs the installed greeter in its own filesystem, X server, and
D-Bus session. It mounts the staged configuration read-only and uses in-memory
settings. The preview and adjacent `.log` file are the only retained output.

Slick's built-in test mode supplies fake users and two fixed virtual monitors
(800×600 plus 640×480). The resulting image is an appearance check, not a
full-resolution screenshot of your physical monitors or a real login test.
Test mode reports a missing LightDM connection and can emit startup allocation
warnings because its fake monitor setup has no primary monitor. Actual
authentication and physical monitor placement require a later real login.

## Install and recover

```bash
./scripts/login-screen.sh check
sudo ./scripts/login-screen.sh install
```

The installer prints a restore command with the precise backup directory.
Save that command. Each installation preserves the previous configuration and
background, including whether either file was absent. System files are copied,
not linked to the checkout, so moving the repository will not break login.

To revert, run the printed command, for example:

```bash
sudo ./scripts/login-screen.sh restore /var/lib/dotfiles/login-screen-backups/install-TIMESTAMP-SUFFIX
```

Replace the example path with the actual directory printed at installation.
Restore archives the displaced theme files alongside the backups rather than
deleting them. The original LightDM and GTK greeter configurations are not
modified by this workflow.

If the greeter cannot be used, switch to a text console with `Ctrl+Alt+F3`,
log in, change to this checkout, and run the restore command. From that console,
`sudo systemctl restart lightdm` starts the recovered greeter. Restarting
LightDM ends graphical sessions, so save any work first. Neither installer nor
restore invokes that command automatically.

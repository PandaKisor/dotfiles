#!/usr/bin/env python3
"""Validate the installed Slick schema; render the real greeter in isolation."""
import argparse
import configparser
import os
from pathlib import Path
import select
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET

import gi

from gi.repository import Gio, GLib

ROOT = Path(__file__).resolve().parent.parent
CONFIG = ROOT / "system/lightdm/slick-greeter.conf"
BACKGROUND = ROOT / "system/lightdm/login.svg"


def validate():
    config = configparser.ConfigParser(interpolation=None)
    config.read(CONFIG)
    schema = Gio.SettingsSchemaSource.get_default().lookup("x.dm.slick-greeter", True)
    if schema is None:
        raise ValueError("Install lightdm-slick-greeter first")
    for name, value in config["Greeter"].items():
        if not schema.has_key(name):
            raise ValueError(f"Unsupported greeter option: {name}")
        key = schema.get_key(name)
        kind = key.get_value_type().dup_string()
        variant = GLib.Variant("s", value) if kind == "s" else GLib.Variant.parse(
            key.get_value_type(), value, None, None
        )
        if not key.range_check(variant):
            raise ValueError(f"Invalid value for {name}: {value}")
    if ET.parse(BACKGROUND).getroot().tag != "{http://www.w3.org/2000/svg}svg":
        raise ValueError("Background must be a valid SVG")
    print("Slick Greeter configuration and SVG validated.")


def render_worker(output, width, height):
    processes = []
    read_fd, write_fd = os.pipe()
    try:
        with open(str(output) + ".log", "w") as log:
            server = subprocess.Popen(
                ["Xvfb", "-displayfd", str(write_fd), "-screen", "0",
                 f"{width}x{height}x24", "-nolisten", "tcp"],
                pass_fds=(write_fd,), stdout=log, stderr=log,
            )
            processes.append(server)
            os.close(write_fd)
            write_fd = None
            if not select.select([read_fd], [], [], 10)[0]:
                raise RuntimeError("Xvfb did not become ready; inspect the preview log")
            display = os.read(read_fd, 32).decode().strip()
            if not display.isdecimal():
                raise RuntimeError("Xvfb failed; inspect the preview log")
            env = dict(os.environ, DISPLAY=f":{display}")
            greeter = subprocess.Popen(["slick-greeter", "--test-mode"],
                                       env=env, stdout=log, stderr=log)
            processes.append(greeter)
            time.sleep(4)
            if greeter.poll() is not None:
                raise RuntimeError("Greeter exited; inspect the preview log")
            subprocess.run(["magick", "import", "-window", "root", str(output)],
                           env=env, check=True, timeout=10)
    finally:
        for process in reversed(processes):
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        os.close(read_fd)
        if write_fd is not None:
            os.close(write_fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.worker:
        # Slick test mode hard-codes adjacent 800x600 and 640x480 displays.
        render_worker(args.output, 1440, 600)
        return
    validate()
    if args.check:
        return
    if args.output is None:
        parser.error("use --check or --output /path/to/preview.png")
    output = args.output.resolve()
    # Namespace mounts only: no changes to the host's /etc, theme, or dconf.
    with tempfile.TemporaryDirectory(prefix="login-preview-") as directory:
        stage = Path(directory)
        for name in ("config", "cache", "data", "state", "runtime"):
            (stage / name).mkdir(mode=0o700)
        command = [
            "bwrap", "--die-with-parent", "--unshare-all", "--ro-bind", "/", "/",
            "--dev", "/dev", "--proc", "/proc", "--tmpfs", "/tmp",
            "--bind", directory, directory,
            "--tmpfs", "/etc/lightdm",
            "--ro-bind", str(CONFIG), "/etc/lightdm/slick-greeter.conf",
            "--tmpfs", "/usr/local/share",
            "--ro-bind", str(BACKGROUND), "/usr/local/share/backgrounds/dotfiles/login.svg",
            "--setenv", "GSETTINGS_BACKEND", "memory",
            "--setenv", "GDK_BACKEND", "x11",
            "--unsetenv", "GTK_THEME", "--unsetenv", "DBUS_SESSION_BUS_ADDRESS",
            "--unsetenv", "GDK_SCALE", "--unsetenv", "GDK_DPI_SCALE",
        ]
        for name in ("config", "cache", "data", "state"):
            command += ["--setenv", f"XDG_{name.upper()}_HOME", str(stage / name)]
        command += ["--setenv", "XDG_RUNTIME_DIR", str(stage / "runtime"),
                    "dbus-run-session", "--", sys.executable, str(Path(__file__).resolve()),
                    "--worker", "--output", str(stage / "preview.png")]
        result = subprocess.run(command)
        log = stage / "preview.png.log"
        if log.exists():
            Path(str(output) + ".log").write_bytes(log.read_bytes())
        result.check_returncode()
        output.write_bytes((stage / "preview.png").read_bytes())
    print(f"Preview: {output} (test users; no real authentication)")


if __name__ == "__main__":
    main()

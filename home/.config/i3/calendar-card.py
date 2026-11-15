#!/usr/bin/env python3
"""Widget card: a large month calendar with today highlighted.

Runs inside the i3-widget-calendar Alacritty window. Colours come from the
active Pywal palette and are re-read on every redraw, so the card follows
wallpaper changes. Redraws on resize, at midnight, and once a minute.
Press q to close (the widget monitor brings the card back).
"""
import calendar
import datetime as dt
import os
import re
import select
import shutil
import signal
import sys
import termios
import tty

FALLBACK = {
    "foreground": "#D8DEE9",
    "color4": "#5E81AC",
    "color5": "#B48EAD",
    "color8": "#4C566A",
    "background": "#0B1118",
}


def palette():
    colors = dict(FALLBACK)
    cache = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    try:
        with open(os.path.join(cache, "wal", "colors.sh"), encoding="utf-8") as f:
            for line in f:
                m = re.match(r"^(\w+)='(#[0-9a-fA-F]{6})'$", line.strip())
                if m and m.group(1) in colors:
                    colors[m.group(1)] = m.group(2)
    except OSError:
        pass
    return colors


def fg(hex_color):
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return f"\033[38;2;{r};{g};{b}m"


def bg(hex_color):
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return f"\033[48;2;{r};{g};{b}m"


BOLD, RESET = "\033[1m", "\033[0m"


def center(text, width, visible=None):
    visible = len(text) if visible is None else visible
    return " " * max((width - visible) // 2, 0) + text


def month_block(year, month, today, cell, row_gap, c):
    """Lines for one month grid. Each day cell is `cell` columns wide."""
    lines = []
    head = "".join(f"{d:>{cell - 1}} " for d in ("Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"))
    lines.append((fg(c["color8"]) + head + RESET, len(head)))
    for week in calendar.Calendar(firstweekday=0).monthdayscalendar(year, month):
        parts = []
        for weekday, day in enumerate(week):
            if day == 0:
                parts.append(" " * cell)
                continue
            text = f"{day:>{cell - 1}} "
            if (year, month, day) == (today.year, today.month, today.day):
                parts.append(bg(c["color4"]) + fg(c["background"]) + BOLD + text + RESET)
            elif weekday >= 5:
                parts.append(fg(c["color5"]) + text + RESET)
            else:
                parts.append(fg(c["foreground"]) + text + RESET)
        lines.append(("".join(parts), cell * 7))
        lines.extend([("", 0)] * row_gap)
    return lines


def render():
    c = palette()
    cols, rows = shutil.get_terminal_size((80, 40))
    today = dt.date.today()
    cell = max(3, min((cols - 2) // 7, 10))
    width = cell * 7

    nxt = (today.replace(day=28) + dt.timedelta(days=4)).replace(day=1)
    # Rows used without gaps: title, blank, header, up to 6 weeks, blank,
    # footer, then the next month (title, header, 6 weeks) if it fits.
    base = 2 + 1 + 6 + 2
    small = 1 + 1 + 6
    show_next = rows >= base + small + 2
    spare = rows - base - (small + 2 if show_next else 0)
    row_gap = max(0, min(2, spare // 6))

    out = []
    title = today.strftime("%B %Y")
    out.append(center(BOLD + fg(c["color4"]) + title + RESET, cols, len(title)))
    out.append("")
    for text, visible in month_block(today.year, today.month, today, cell, row_gap, c):
        out.append(center(text, cols, visible if visible else 0) if text else "")
    while out and out[-1] == "":
        out.pop()
    out.append("")
    year_end = dt.date(today.year, 12, 31)
    footer = (f"Week {today.isocalendar().week}  ·  Day {today.timetuple().tm_yday}"
              f"  ·  {(year_end - today).days} days left")
    out.append(center(fg(c["color8"]) + footer + RESET, cols, len(footer)))

    if show_next:
        out.append("")
        small_cell = 4
        ntitle = nxt.strftime("%B %Y")
        out.append(center(fg(c["color5"]) + ntitle + RESET, cols, len(ntitle)))
        for text, visible in month_block(nxt.year, nxt.month, today, small_cell, 0, c):
            if text:
                out.append(center(text, cols, visible))

    # Vertically centre the whole block.
    top = max((rows - len(out)) // 2, 0)
    screen = "\033[H\033[2J" + "\n" * top + "\n".join(out[: rows - top])
    sys.stdout.write(screen)
    sys.stdout.flush()


def seconds_until_next_minute():
    now = dt.datetime.now()
    return 60 - now.second - now.microsecond / 1e6


class Resized(Exception):
    pass


def on_resize(*_):
    # Raising (rather than setting a flag) interrupts select(), which Python
    # would otherwise retry transparently after the signal.
    raise Resized


def main():
    signal.signal(signal.SIGWINCH, on_resize)
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    interactive = sys.stdin.isatty()
    saved = termios.tcgetattr(sys.stdin) if interactive else None
    sys.stdout.write("\033[?25l")  # hide cursor
    try:
        if interactive:
            tty.setcbreak(sys.stdin)
        while True:
            try:
                render()
                ready, _, _ = select.select([sys.stdin] if interactive else [], [], [],
                                            seconds_until_next_minute())
            except Resized:
                continue  # redraw at the new size immediately
            if ready and sys.stdin.read(1) in ("q", "Q"):
                break
    except KeyboardInterrupt:
        pass
    finally:
        if saved is not None:
            termios.tcsetattr(sys.stdin, termios.TCSADRAIN, saved)
        sys.stdout.write(RESET + "\033[?25h\033[H\033[2J")
        sys.stdout.flush()


if __name__ == "__main__":
    main()

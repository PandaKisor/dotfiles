#!/usr/bin/env python3
"""Quadrant-aware tiling helper for i3.

Per workspace, the opening sequence is:
  1 tiled window  -> full workspace
  2 tiled windows -> 50/50 left/right (normal i3 behavior)
  3 tiled windows -> first two across the top, newest full-width on bottom
                     with the bottom row at about 1/3 of the workspace height
  4 tiled windows -> newest goes into the bottom-right and rows rebalance
                     to 50/50, yielding four equal quadrants

For 5+ tiled windows, this helper stops rearranging and lets i3 behave normally.
Floating windows are ignored.
"""

import fcntl
import json
import os
import subprocess
import sys
import time
from pathlib import Path

# i3 resize uses integer percentage points. Starting from 50/50, 17 ppt gives
# approximately 67/33; growing by the same amount returns to 50/50.
BOTTOM_ROW_DELTA_PPT = 17
MARK_PREFIX = "__quad_bottom_"


def i3_msg(command: str, message_type: str | None = None) -> str:
    args = ["i3-msg"]
    if message_type is not None:
        args += ["-t", message_type]
    args.append(command)
    result = subprocess.run(
        args,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    return result.stdout


def get_tree() -> dict | None:
    raw = i3_msg("", "get_tree")
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def find_path(node: dict, target_id: int, path: list[dict] | None = None):
    path = [] if path is None else path
    here = path + [node]
    if node.get("id") == target_id:
        return here

    for child in node.get("nodes", []):
        found = find_path(child, target_id, here)
        if found:
            return found

    for child in node.get("floating_nodes", []):
        found = find_path(child, target_id, here)
        if found:
            return found

    return None


def tiled_leaf_ids(node: dict) -> list[int]:
    """Return X11-backed leaf container IDs, excluding floating_nodes."""
    out: list[int] = []

    def visit(cur: dict):
        if cur.get("window") is not None:
            out.append(cur["id"])
        for child in cur.get("nodes", []):
            visit(child)
        # Deliberately do not recurse through floating_nodes.

    visit(node)
    return out


def find_marked(node: dict, mark: str) -> dict | None:
    if mark in node.get("marks", []):
        return node
    for child in node.get("nodes", []):
        found = find_marked(child, mark)
        if found:
            return found
    return None


def contains_id(node: dict, target_id: int) -> bool:
    if node.get("id") == target_id:
        return True
    return any(contains_id(child, target_id) for child in node.get("nodes", []))


def handle_new_window(container_id: int):
    # Give assignment/for_window rules a moment to finish (especially floating
    # rules) before deciding whether this is a tiled workspace client.
    time.sleep(0.06)

    tree = get_tree()
    if not tree:
        return

    path = find_path(tree, container_id)
    if not path:
        return

    workspace = next((n for n in reversed(path) if n.get("type") == "workspace"), None)
    if workspace is None:
        return

    tiled = tiled_leaf_ids(workspace)
    if container_id not in tiled:
        return  # floating/dialog window

    count = len(tiled)
    mark = f"{MARK_PREFIX}{workspace['id']}"

    if count == 3:
        # i3's implicit-container behavior does exactly what we need here:
        # moving the 3rd member of a horizontal row down changes the workspace
        # to splitv and groups the first two in a new horizontal container.
        # Then wrap the bottom window in a one-child splith container so the
        # fourth window has a deterministic bottom-right destination.
        cmd = (
            f'[con_id="{container_id}"] focus; '
            f'move down; '
            f'split horizontal; '
            f'focus parent; '
            f'resize shrink height {BOTTOM_ROW_DELTA_PPT} ppt; '
            f'mark --replace {mark}; '
            f'focus child'
        )
        i3_msg(cmd)
        return

    if count == 4:
        bottom = find_marked(workspace, mark)
        if bottom is None:
            # If the 3-window state was created before this helper started, do
            # not guess at the user's existing layout.
            return

        # If focus was moved elsewhere before window #4 opened, force the new
        # window into the marked bottom row. If it already opened there, leave
        # it in place.
        if not contains_id(bottom, container_id):
            i3_msg(
                f'[con_id="{container_id}"] focus; '
                f'move container to mark {mark}'
            )

        # Grow the bottom row from ~33% to 50%, making a true 2x2 grid.
        i3_msg(
            f'[con_mark="^{mark}$"] focus; '
            f'resize grow height {BOTTOM_ROW_DELTA_PPT} ppt; '
            f'focus child'
        )


def acquire_single_instance_lock():
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
    lock_path = runtime / f"i3-quadrant-tiling-{os.getuid()}.lock"
    lock_file = lock_path.open("w")
    try:
        fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)
    return lock_file


def subscribe_forever():
    while True:
        try:
            proc = subprocess.Popen(
                ["i3-msg", "-t", "subscribe", "-m", '["window"]'],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                bufsize=1,
            )
        except FileNotFoundError:
            sys.exit("quadrant-tiling.py: i3-msg was not found in PATH")

        assert proc.stdout is not None
        for line in proc.stdout:
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            if event.get("change") != "new":
                continue

            container = event.get("container") or {}
            container_id = container.get("id")
            if isinstance(container_id, int):
                handle_new_window(container_id)

        # i3 restart/reload can break the subscription. Reconnect rather than
        # leaving the helper dead for the remainder of the session.
        time.sleep(0.25)


def main():
    _lock = acquire_single_instance_lock()
    subscribe_forever()


if __name__ == "__main__":
    main()

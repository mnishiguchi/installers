#!/usr/bin/env python3
"""Manage selected live Plasma 6 shortcuts without replacing other bindings."""
import argparse
import ast
import os
import re
import subprocess
import sys


# (human-readable shortcut, Qt combined key, component, action)
TARGETS = (
    ("Super+Space", 268435488, "org.kde.krunner.desktop", "_launch"),
    ("Super+Enter", 285212676, "Alacritty.desktop", "New"),
    ("Super+Shift+S", 301989971, "org.kde.spectacle.desktop", "RectangularRegionScreenShot"),
    ("Ctrl+Alt+Left", 218103826, "kwin", "Switch to Previous Desktop"),
    ("Ctrl+Alt+Right", 218103828, "kwin", "Switch to Next Desktop"),
    ("Ctrl+Alt+Up", 218103827, "kwin", "Overview"),
    ("Ctrl+Alt+Down", 218103829, "kwin", "ExposeAll"),
)
SPECTACLE_LAUNCH = ("org.kde.spectacle.desktop", "_launch")
SCREENSHOT_KEY = 301989971


class ShortcutError(Exception):
    pass


def parse_reply(text):
    # gdbus prints GVariant text, with type annotations for empty arrays.
    # Only these known array annotations are accepted. Never eval D-Bus text.
    text = re.sub(r"@(?:a\(ssssssaiai\)|a\(ai\)|aas|ai|as) (?=\[\])", "", text)
    try:
        result = ast.literal_eval(text.strip())
    except (SyntaxError, ValueError) as exc:
        raise ShortcutError(f"Unexpected gdbus reply: {text.strip()}") from exc
    if not isinstance(result, tuple):
        raise ShortcutError("Expected a D-Bus return tuple")
    return result


def call(method, *args):
    result = subprocess.run(
        ["gdbus", "call", "--session", "--timeout", "10",
         "--dest", "org.kde.kglobalaccel", "--object-path", "/kglobalaccel",
         "--method", f"org.kde.KGlobalAccel.{method}", *args],
        check=True, capture_output=True, text=True,
    )
    return parse_reply(result.stdout)


def one_array(result):
    if len(result) != 1 or not isinstance(result[0], list):
        raise ShortcutError("Expected a single array from KGlobalAccel")
    return result[0]


def action_ids(component):
    rows = one_array(call("allActionsForComponent", repr([component, "", "", ""])))
    actions = {}
    for row in rows:
        if (not isinstance(row, list) or len(row) != 4
                or not all(isinstance(s, str) for s in row) or row[0] != component):
            raise ShortcutError(f"Unexpected action ID for {component}")
        if row[1] in actions:
            raise ShortcutError(f"Ambiguous action: {component}/{row[1]}")
        actions[row[1]] = row
    return actions


def bindings(action):
    rows = one_array(call("shortcutKeys", repr(action)))
    keys = []
    for row in rows:
        if (not isinstance(row, tuple) or len(row) != 1
                or not isinstance(row[0], list) or len(row[0]) != 4
                or not all(type(n) is int and 0 <= n <= 2147483647 for n in row[0])):
            raise ShortcutError(f"Unexpected key sequence for {action[:2]}")
        keys.append(tuple(row[0]))
    return keys


def owners(key):
    rows = one_array(call("getGlobalShortcutsByKey", str(key)))
    found = []
    for row in rows:
        if (not isinstance(row, tuple) or len(row) != 8
                or not all(isinstance(s, str) for s in row[:6])
                or row[4] != "default"):
            raise ShortcutError(f"Unexpected or non-default shortcut context for {key}")
        found.append((row[2], row[0]))
    return found


def seq(key):
    return (key, 0, 0, 0)


def set_bindings(action, expected):
    # Pass structured GVariant arguments without shell interpolation.
    if call("setForeignShortcutKeys", repr(action), repr([(list(k),) for k in expected])) != ():
        raise ShortcutError(f"Unexpected write reply for {action[:2]}")
    if set(bindings(action)) != set(expected):
        raise ShortcutError(f"Readback differs after writing {action[:2]}")


def configure(check=False):
    ids = {}
    for component in dict.fromkeys(t[2] for t in TARGETS):
        ids[component] = action_ids(component)
    required = [(t[2], t[3]) for t in TARGETS] + [SPECTACLE_LAUNCH]
    for component, action in required:
        if action not in ids[component]:
            raise ShortcutError(
                f"Action not registered: {component}/{action}. Add it in KDE System Settings > Keyboard > Shortcuts first."
            )
    # Inspect all targets before writing anything. A conflict on the last
    # shortcut must not cause earlier shortcuts to be modified.
    pending = []
    for label, key, component, name in TARGETS:
        target = (component, name)
        action = ids[component][name]
        current = bindings(action)
        assigned = owners(key)
        if assigned == [target] and seq(key) in current:
            print(f"  [ok] {label}: {component}/{name}")
            continue
        if seq(key) in current or target in assigned:
            raise ShortcutError(f"Inconsistent live state for {label}; no changes made")
        transfer = key == SCREENSHOT_KEY and assigned == [SPECTACLE_LAUNCH]
        if assigned and not transfer:
            raise ShortcutError(f"Conflict for {label}: {assigned}; no changes made")
        pending.append((label, key, target, action, transfer))
        print(f"  [review] {label}: assign {component}/{name}")
    if check:
        print(f"\n{len(pending)} shortcut(s) need changes." if pending else "\nManaged KDE shortcuts are ready.")
        return int(bool(pending))

    for label, key, target, action, transfer in pending:
        # Recheck live state immediately before mutation. Do not steal a
        # shortcut that was assigned to another action since preflight.
        if owners(key) != ([SPECTACLE_LAUNCH] if transfer else []):
            raise ShortcutError(f"Live shortcut changed during apply: {label}; run --check")
        if transfer:
            old = ids[SPECTACLE_LAUNCH[0]][SPECTACLE_LAUNCH[1]]
            current = bindings(old)
            if seq(key) not in current:
                raise ShortcutError(f"Spectacle launch binding changed during apply: {label}")
            set_bindings(old, [k for k in current if k != seq(key)])
            if owners(key):
                raise ShortcutError(f"Could not release {label}; run --check")
        current = bindings(action)
        set_bindings(action, current + [seq(key)])
        if owners(key) != [target]:
            raise ShortcutError(f"Could not verify owner of {label}; run --check")
        print(f"  [ok] Applied {label}")
    print("\nManaged KDE shortcuts are ready.")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report drift without writing")
    args = parser.parse_args()
    try:
        if os.geteuid() == 0:
            raise ShortcutError("Run as the desktop user, not root")
        if os.environ.get("XDG_CURRENT_DESKTOP") != "KDE" or os.environ.get("XDG_SESSION_TYPE") != "wayland":
            raise ShortcutError("Run inside a KDE Wayland session")
        return configure(args.check)
    except (ShortcutError, OSError, subprocess.CalledProcessError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        if isinstance(exc, subprocess.CalledProcessError) and exc.stderr:
            print(exc.stderr.strip(), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

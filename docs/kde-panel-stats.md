# Compact Stats for KDE Plasma

An optional bottom-panel monitor using the native Plasma 6 System Monitor
applet and a small local QML sensor face. No separate monitoring daemon, sudo,
or third-party widget download is needed. The layout was accepted on Fedora
Asahi Remix 45 (M1 Pro, ten logical CPUs).

## Apply and verify

Run in the active Plasma 6 session as the desktop user:

```bash
./kde/panel-stats.sh --dry-run
./kde/panel-stats.sh
./kde/panel-stats.sh --check
```

The helper requires Bash, `busctl`, `kreadconfig6`, standard Linux utilities,
and the native KDE System Monitor applet and sensor infrastructure. It reads
`/proc/stat` to generate the per-logical-CPU sensor IDs. Rerun it if the CPU
configuration changes. `--check` returns nonzero for drift or missing state;
`--dry-run` reports the same differences without modifying the panel or face.

The face is installed in `${XDG_DATA_HOME:-$HOME/.local/share}/ksysguard/sensorfaces/org.example.installers.compactstats.cores`.
The ID and `.installers-preview` marker are deliberately retained to adopt the
working preview in place. An unowned directory or an unrelated CPU widget is
not overwritten. The helper expects exactly one bottom panel and at most one
CPU monitor on it. It preserves the position of an existing matching monitor;
for a new monitor it attempts to place it immediately before the system tray
when the scripting API reports a valid tray index. If positioning is unavailable,
move the widget once using panel edit mode. It does not replace the panel or
modify other widgets.

## Display

| Reading | Native sensor |
| --- | --- |
| CPU percentage | `cpu/all/usage` |
| Individual logical CPU bars | `cpu/cpuN/usage` |
| Application memory percentage | `memory/physical/applicationPercent` |
| Aggregate download | `network/all/download` |
| Aggregate upload | `network/all/upload` |

The panel uses integer percentages, blue CPU labels/bars, green RAM, purple
network arrows and a 1000 ms sensor update rate limit. RAM is application memory,
not necessarily identical to every other tool's definition of used memory.
No temperature or CPU cluster identification is inferred. The popup displays
the four aggregate readings. The compact face is designed for a horizontal
panel. If the display is cached, log out and back in.

## Rollback

To stop using Compact Stats, remove the CPU monitor through panel edit mode, or
select the built-in **Text Only** display in its settings. The local face files
can safely remain installed. The installer is opt-in; applying it again will
restore Compact Stats. No desktop bootstrap calls it automatically.

## Verification

```bash
bash test/kde-panel-stats.sh
```

The test uses Node.js for the JavaScript API model and mocked D-Bus calls; Node
is a test dependency only. The working preview was visually verified on Asahi.
The repository helper's live adoption, clean-panel creation, placement and
behavior on other Plasma versions or CPU architectures still require real
session acceptance. `--check` verifies the managed files and widget keys, not
sensor accuracy or QML rendering.

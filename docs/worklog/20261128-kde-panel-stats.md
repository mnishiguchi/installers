# 2026-11-28: Compact Stats on KDE

## Real-machine experiment

On Fedora Asahi Remix 45 KDE, a native CPU System Monitor widget was added to
the bottom panel. The live Plasma D-Bus scripting API successfully configured
CPU, application memory and aggregate network sensors, labels and colors.
The configuration diff showed a single added applet before the system tray;
other panel entries were preserved.

The built-in Text Only face reserved excessive horizontal space. A local QML
sensor face using the same KDE sensor infrastructure produced a more compact
layout. A second preview added ten logical CPU bars, discovered from `/proc/stat`.
The user confirmed the rendered layout and selected it for adoption.

## Repository integration

Retain the accepted QML representations, package ID, sensor choices and colors.
Add an opt-in `kde/panel-stats.sh` helper with dry-run/check, preview adoption,
creation when missing, ownership checks and targeted live widget configuration.
No whole-panel config copies, bootstrap changes, temperature monitoring or
third-party packages. Keep existing widget placement. Fresh placement is best
effort through the panel scripting API.

## Verification boundary

The preview appearance was confirmed by the user on Asahi. The new helper is
covered by offline JavaScript and shell regression tests (creation, adoption,
drift, idempotency, unrelated-widget preservation and refusal of ambiguity).
Live execution of the repository helper, fresh-panel creation and per-core
load verification remain pending. ShellCheck is expected in CI.

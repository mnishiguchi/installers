# Fedora Asahi Remix workstation

This guide covers the tested target: **Fedora Asahi Remix 45 KDE on Apple
Silicon ARM64**. It is not a claim of support for every Fedora edition or
architecture. The installer checks `ID=fedora-asahi-remix` and `aarch64` before
changing anything.

## Restore the workstation

Run from this checkout as the normal desktop user, not with `sudo`:

```bash
./fedora-asahi-bootstrap.sh --check
./fedora-asahi-bootstrap.sh
```

The default restore installs the verified DNF workstation and KDE integration
packages, FiraCode Nerd Font, the dotfiles checkout, Mise-managed Yazi/shfmt/
resvg, and Fish as the login shell. It does not overwrite the user's KDE
shortcuts, browser choice, terminal choice, or other desktop preferences.

Native build dependencies and language runtimes are separate so that the
wxWidgets/OpenGL development stack is installed before Erlang is compiled:

```bash
./fedora-asahi-bootstrap.sh --only build,runtimes
```

`build` installs the native compiler, OpenSSL and Erlang build dependencies,
including wxGTK and Mesa development packages. `runtimes` installs Erlang/OTP
28 first, then Elixir 1.19.5 for OTP 28, Node 24, Python 3.12, Ruby, Go, Rust,
and uv through Mise. If Erlang was compiled before wxGTK development packages
were installed, rebuild it with `mise install --force erlang@28.5` so the wx
native driver is built.

Useful focused commands:

```bash
./fedora-asahi-bootstrap.sh --only packages,desktop
./fedora-asahi-bootstrap.sh --only fonts
./fedora-asahi-bootstrap.sh --only dotfiles,mise
./fedora-asahi-bootstrap.sh --only build
./fedora-asahi-bootstrap.sh --check
```

Set `DOTFILES_DIR` to select a particular existing checkout or clone destination.
The bootstrap preserves local dotfiles changes and uses the dotfiles installer's
`--verify` / `--force` contract.

## Package ownership

- DNF owns native terminal tools, Neovim, Alacritty, clangd, preview utilities,
  Fcitx5/Mozc, and CopyQ.
- Mise owns Yazi, shfmt, resvg, and the optional language runtimes.
- The `build` package manifest contains the native dependencies needed for
  source-built Erlang and Nerves development.
- `dotfiles` owns shell/editor/terminal configuration, not system packages or
  KDE's complete desktop state.

The package manifests intentionally do not install Docker, ESP-IDF, OpenOCD,
AtomVM, or Nerves tooling. Those workflows still need dedicated validation on
this machine before they are added to a managed restore.

## KDE Wayland setup

### Compact Stats panel monitor (optional)

See [Compact Stats](kde-panel-stats.md) for the compact CPU, per-core, RAM
and network panel layout, and the standalone installer and verification.

### Japanese input

Installations include Fcitx5 and Mozc. In KDE System Settings:

1. Open **Keyboard → Virtual Keyboard**.
2. Select **Fcitx 5** (the normal option, not the experimental Wayland Launcher).
3. Open `fcitx5-configtool` and add **Mozc**, keeping **Keyboard - English (US)**.
4. Use `Ctrl+Space` to switch input methods.

The tested setup uses KDE/KWin to start Fcitx5. Do not add global `GTK_IM_MODULE`
or `QT_IM_MODULE` overrides for this Wayland configuration unless a specific
application demonstrates that it needs one.

### Clipboard history: evaluate Klipper first

KDE already provides Klipper. Follow the [native clipboard evaluation](kde-clipboard-evaluation.md) before deciding whether CopyQ is necessary. The current manifest still installs CopyQ; do not remove it or migrate history automatically.

### CopyQ (existing optional workflow)

CopyQ is installed from Fedora's package repository. If needed after evaluation:

1. Start CopyQ and enable its autostart option.
2. Configure a KDE global shortcut for the CopyQ window (for example, run
   `copyq toggle` from the shortcut command).
3. Test history and recall across applications.
4. Review CopyQ's password/secret ignore rules before copying real credentials.

Package installation is verified; full clipboard-history and shortcut
acceptance remains a manual check.

### Selected desktop preferences

The desktop preferences are opt-in and separate from the package bootstrap.
Run as the logged-in desktop user in a Plasma 6 Wayland session:

```bash
./kde/desktop-config.sh --check
./kde/desktop-config.sh
```

The script manages selected keyboard layout, virtual desktop count/rows,
wraparound, desktop change indicator, slide animation, Breeze Dark, and the
KWin Fcitx5 service entry. It writes individual KConfig keys only when their
values differ. Applying the color scheme uses Plasma's color scheme utility.
It does not copy generated desktop IDs, monitor settings, tiling layouts,
window decoration or complete configuration files. The intended keyboard
layout is US with Caps Lock as an additional Ctrl and Shift+Caps Lock as
regular Caps Lock.

`--check` reads persisted effective values and returns nonzero for drift.
It does not verify live behavior. If changes were applied, log out and back
in, run `--check` again and test the keyboard and virtual desktops. This
script has offline regression coverage; live restore on a new KDE session
is still pending.

### Keyboard shortcuts

Run as the KDE Wayland desktop user, with Python 3 and `gdbus` available:

```bash
./kde/shortcuts-config.sh --check
./kde/shortcuts-config.sh
```

| Shortcut | Action |
| --- | --- |
| Super+Space | KRunner |
| Super+Enter | Alacritty: New |
| Super+Shift+S | Spectacle: Capture Rectangular Region |
| Ctrl+Alt+Left/Right | Previous/next desktop |
| Ctrl+Alt+Up | Overview |
| Ctrl+Alt+Down | Present Windows (all desktops) |

The script discovers existing registered action IDs and key sequences via
KGlobalAccel, preserves alternative shortcuts and refuses unexpected conflicts
before writing. The only allowed transfer is Super+Shift+S from generic
Spectacle launch to rectangular capture. It verifies each change by readback.
If an action is not registered (e.g. Alacritty on a fresh desktop), add it in
System Settings > Keyboard > Shortcuts and rerun. It does not register unknown
actions or edit `kglobalshortcutsrc`. No sudo or session restart is required
for the tested live calls. The script is not transactional: if a write fails,
review the live state with `--check`, resolve conflicts in System Settings and
rerun. In particular the screenshot shortcut may be unassigned after a failed
transfer. Do not run concurrent shortcut editors during restore.

The manual D-Bus experiment confirmed all seven owners and preserved alternative
bindings. The automation has offline tests; verify physical keys and persistence
after logout/login on real KDE. KRunner and Spectacle are native; Rofi is not
required.

Fcitx5's input-method profile remains manual (US keyboard, Mozc, Ctrl+Space
trigger). Do not replace a live daemon's profile file. Browser preferences and
clipboard/snippet integration remain manual.

## Desktop applications

Follow the [manual desktop application guide](fedora-asahi-applications.md)
for Brave, Slack, Discord and 1Password. Slack and Discord were installed
as Brave web apps and launched through KRunner. Slack dark mode was verified.
Call, notification and screen-sharing acceptance remains pending. Account
authentication and app registration are outside the managed bootstrap.

## Yazi preview support

The tested Yazi configuration uses the Chafa image adapter and the following
native/Mise tools:

- `chafa` for image previews;
- `poppler-utils` (`pdftoppm`) for PDFs;
- `ffmpeg-free` (`ffmpeg`/`ffprobe`) for video metadata and previews;
- `ImageMagick` for image conversion;
- `7zip` (`7z`) for archives;
- Mise-managed `resvg` for SVG rendering.

`ueberzugpp` and a standalone `7zz` executable were not present in the test
report; they are not required for the verified Chafa/7z preview path.

## Neovim and clangd on Linux ARM64

Mason does not provide a usable `clangd` installer for Linux ARM64. The
Neovim configuration therefore excludes `clangd` from Mason on `aarch64` and
enables the system executable when present. On Fedora Asahi, install
`clang-tools-extra`, which provides the native `clangd` binary. Other Mason
servers and formatters remain Mason-managed.

Verify in a C/C++ project with `:LspInfo`; `clangd` should attach using the
system executable (normally `/usr/bin/clangd`).

## Verification status and limitations

The 2026-11-27 experiment verified the M1 Pro/ARM64 Fedora Asahi boot, KDE
Wayland, 16 KiB memory pages, the core CLI toolchain, Mise activation, Yazi
previews, Fcitx5/Mozc conversion in its test field and Alacritty, native
clangd/Mason behavior, and Erlang/Elixir compilation and smoke tests. Erlang
crypto/SSL reported OpenSSL 4.0.3. Erlang Observer initialized after wxGTK and
Mesa development packages were installed; GTK emitted non-fatal state notices.

Still requiring manual acceptance: CopyQ history/shortcut behavior, Japanese
input in Brave and Neovim, Docker/Compose with PostgreSQL, Nerves firmware and
fwup, ESP-IDF/OpenOCD/AtomVM, suspend/resume, audio/microphone/camera, USB,
external displays, battery behavior, and physical shortcut/persistence acceptance. The initial
Mason `clangd` installation errors stopped after the Linux ARM64 configuration
was updated; no new Mason error was reported.

The machine reported one timed-out DrKonqi user service. This is recorded for
investigation, not automatically disabled or reset by the installer.

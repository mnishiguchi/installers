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

### Japanese input

Installations include Fcitx5 and Mozc. In KDE System Settings:

1. Open **Keyboard → Virtual Keyboard**.
2. Select **Fcitx 5** (the normal option, not the experimental Wayland Launcher).
3. Open `fcitx5-configtool` and add **Mozc**, keeping **Keyboard - English (US)**.
4. Use `Ctrl+Space` to switch input methods.

The tested setup uses KDE/KWin to start Fcitx5. Do not add global `GTK_IM_MODULE`
or `QT_IM_MODULE` overrides for this Wayland configuration unless a specific
application demonstrates that it needs one.

### CopyQ

CopyQ is installed from Fedora's package repository. After installation:

1. Start CopyQ and enable its autostart option.
2. Configure a KDE global shortcut for the CopyQ window (for example, run
   `copyq toggle` from the shortcut command).
3. Test history and recall across applications.
4. Review CopyQ's password/secret ignore rules before copying real credentials.

Package installation is verified; full clipboard-history and shortcut
acceptance remains a manual check.

### Keyboard and desktop shortcuts

The following preferences were configured manually on the tested KDE system.
They are recorded here for consistency, but are not yet exported or applied by
the bootstrap:

- Caps Lock as an additional Ctrl, with Shift+Caps Lock toggling Caps Lock
  (`caps:ctrl_shifted_capslock`).
- `Super+Space` for the application launcher.
- `Super+Enter` for Alacritty.
- `Super+Shift+S` for rectangular screenshot capture.
- `Alt+Ctrl+Arrow` for virtual-desktop navigation.
- KDE shortcuts for showing all windows and all desktops.
- Brave as the default browser and Alacritty as the default terminal.

KDE shortcut export and automated restoration are deliberately deferred until
the settings can be captured and tested independently. KRunner is KDE's native
application launcher; Rofi is not required for this desktop.

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
external displays, battery behavior, and full KDE shortcut export. The initial
Mason `clangd` installation errors stopped after the Linux ARM64 configuration
was updated; no new Mason error was reported.

The machine reported one timed-out DrKonqi user service. This is recorded for
investigation, not automatically disabled or reset by the installer.

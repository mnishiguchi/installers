# Fedora Asahi Remix 45 workstation bring-up

Date: 2026-11-27

Hardware: Apple MacBook Pro (16-inch, 2021), M1 Pro, 32 GiB RAM, 1 TB SSD.
Installed target: Fedora Asahi Remix 45 KDE Plasma prerelease, aarch64, Wayland.
The system reported 16 KiB memory pages and a Btrfs root filesystem.

## Verified during the experiment

- Asahi installation and first Fedora boot succeeded; a subsequent DNF upgrade
  and reboot returned to the KDE login screen.
- Core tools were installed from Fedora repositories: Fish, tmux, Neovim,
  Alacritty, Git/GitHub CLI, fzf, ripgrep, fd, zoxide, just, direnv, fastfetch,
  ShellCheck, wl-clipboard, eza, lazygit, diff-so-fancy, htop, btop, age,
  Chafa, Poppler utilities, ImageMagick, FFmpeg, 7-Zip, and related utilities.
- FiraCode Nerd Font was installed with the existing
  `user/nerd-fonts-install.sh` helper.
- Mise 2026.11.14 was installed from the official `mise.run` installer and
  activated in Fish. Yazi 26.9.1, shfmt 3.14.1, and resvg 0.50.0 were installed
  through Mise. Preview diagnostics identified Chafa as the active image
  adapter; `pdftoppm`, FFmpeg/ffprobe, ImageMagick, 7z, jq, and wl-clipboard
  were available.
- Native development packages were installed: GCC/G++, Make, CMake, Autoconf,
  Automake, Libtool, OpenSSL, ncurses, readline, libyaml, zlib, libffi, bzip2,
  xz, SQLite, pkgconf, and `clang-tools-extra`. Fedora's native clangd 23.1.6
  was executable on aarch64.
- Erlang/OTP 28.5 and Elixir 1.19.5 (OTP 28) installed through Mise. Hex 2.7.0
  and Rebar3 were installed. A new Mix project passed ExUnit; a Jason Hex
  dependency resolved, compiled, and executed. Erlang crypto/SSL reported
  OpenSSL 4.0.3.
- Erlang Observer initially failed because the wx native driver was absent.
  Installing `wxGTK-devel`, `mesa-libGL-devel`, and `mesa-libGLU-devel`, then
  rebuilding Erlang, produced `wxe_driver.so`. `wx` initialization succeeded
  and `:observer.start()` returned `:ok`; GTK emitted non-fatal state notices.
- The initial Mason log showed missing Ruby/Go/Rust toolchains, a gersemi Rust
  build failure, and an unsupported ARM64 clangd installer. After installing
  runtimes and native clangd, the Ruby/Go/gersemi installs succeeded. The
  dotfiles configuration was updated to skip Mason's clangd package on Linux
  aarch64 and enable the native executable. The user later confirmed no Mason
  errors remained.
- Fcitx5, Mozc, the Fcitx5 KDE integration packages, and CopyQ installed from
  Fedora repositories. KDE's Virtual Keyboard setting was set to Fcitx 5;
  Mozc was added beside Keyboard - English (US). Japanese conversion worked in
  the Fcitx test field and Alacritty.
- KDE shortcuts and preferences were configured manually: Caps Lock as another
  Ctrl with Shift+Caps Lock toggling Caps Lock, Super+Space for launcher,
  Super+Enter for terminal, Super+Shift+S for rectangular screenshot,
  Alt+Ctrl+Arrow for workspace navigation, plus show-all-windows/show-all-
  desktops shortcuts. Brave and Alacritty were selected as default browser and
  terminal. These settings have not yet been exported to a managed snapshot.
- The user's diagnostics reported a roughly 10-second systemd boot-to-graphical
  target and no failed system services in the later pending-check run. A prior
  PackageKit timeout was not persistent. A DrKonqi coredump pickup user service
  reported a timeout and remains for review.

## Locale correction

The system locale was `en_US.UTF-8`, `locale charmap` returned `UTF-8`, and
`localectl` reported the expected US keyboard layout. Qt/Elixir warnings came
from the diagnostic script's `export LC_ALL=C`, not the system. The script was
changed locally to `LC_ALL=C.UTF-8`; no system locale change was needed.

## Decisions for the bootstrap

- Use a dedicated Fedora Asahi Remix / aarch64 bootstrap, not a generic Fedora
  bootstrap.
- Keep native packages in DNF manifests, Mise tools/runtimes in Mise, and
  user configuration in dotfiles.
- Install `clang-tools-extra` natively; Mason does not install clangd on Linux
  ARM64.
- Install wxGTK/Mesa development packages before building Erlang when Observer
  support is required.
- Keep CopyQ/Fcitx5 packages in the KDE desktop package manifest, but leave
  global shortcuts and KWin settings to explicit GUI setup for now.
- Use KRunner as KDE's native launcher; Rofi is not a KDE prerequisite.
- Do not claim Docker, Nerves/fwup, ESP-IDF, OpenOCD, AtomVM, or full hardware
  support until their acceptance tests pass.

## Remaining manual checks

- CopyQ clipboard history, global shortcut, and secret-ignore behavior.
- Japanese input in Brave and Neovim (Alacritty and the Fcitx test field passed).
- Docker/Compose with PostgreSQL and native ARM64 containers.
- Nerves firmware/fwup; ESP-IDF, OpenOCD, and AtomVM.
- Suspend/resume, audio, microphone, camera, USB, external display, and battery.
- Capture/export the configured KDE shortcuts and test restoration.
- Inspect the DrKonqi user-service timeout without disabling crash reporting.

The worklog records the user's interactive experiments. It does not claim that
these manual checks were performed by the repository's automated tests.

## Repository implementation validation

The initial implementation adds an offline Fedora bootstrap regression test. It
mocks DNF/RPM/Mise and verifies target detection, read-only package checks,
package application, dotfiles reuse, font/shell checks, Mise tool checks, and
Erlang-before-Elixir runtime ordering. It does not install packages or replace
the manual acceptance tests above.

In the editing environment, `bash test/fedora-asahi-bootstrap.sh` passed, the
existing macOS bootstrap regression test passed (its real-Fish integration was
skipped because Fish was unavailable), and the dotfiles regression tests passed
except `shell_health_test.sh`, which was skipped because Fish was unavailable.
The focused Cinnamon keybinding test was not run because it refuses to run as
root. Shell syntax checks and YAML parsing passed. ShellCheck was unavailable in
the editing environment, so the full `test/lint.sh` run remains outstanding.

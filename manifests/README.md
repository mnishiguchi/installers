# Workstation manifests

Declarative package, application, and tool lists consumed by the workstation
bootstrap scripts.

- `apt-packages.txt`: LMDE system packages.
- `flatpak-apps.txt`: LMDE desktop applications.
- `Brewfile`: macOS CLI tools, native build dependencies and terminal font.
- `fedora-asahi-packages.txt`: tested Fedora Asahi Remix 45 ARM64 core workstation packages.
- `fedora-asahi-desktop-packages.txt`: KDE Wayland Fcitx5/Mozc and CopyQ packages.
- `fedora-asahi-build-packages.txt`: native build dependencies, including wxGTK/Mesa for Erlang Observer.
- `Brewfile.colima`: optional Colima and Docker CLI tools (`--only colima`).

CopyQ is managed by APT on LMDE (`copyq` and `copyq-plugins`), DNF on Fedora
Asahi, and the official upstream DMG on macOS through the opt-in `copyq`
bootstrap section. It is intentionally not in the Homebrew Brewfile because the
official cask is disabled.

The Fedora Asahi manifests are consumed by `../fedora-asahi-bootstrap.sh` and
are intentionally scoped to Fedora Asahi Remix on aarch64. They are not generic
Fedora package manifests. Mise-managed tools and language runtimes are declared
in that bootstrap script rather than these DNF manifests.

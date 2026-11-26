# Workstation manifests

Declarative package, application, and tool lists consumed by the workstation
bootstrap scripts.

- `apt-packages.txt`: LMDE system packages.
- `flatpak-apps.txt`: LMDE desktop applications.
- `Brewfile`: macOS CLI tools, native build dependencies and terminal font.
- `Brewfile.colima`: optional Colima and Docker CLI tools (`--only colima`).

CopyQ is managed by APT on LMDE (`copyq` and `copyq-plugins`). On macOS, the
official upstream DMG is installed through the opt-in `copyq` bootstrap section;
it is intentionally not in the Homebrew Brewfile because the official cask is disabled.

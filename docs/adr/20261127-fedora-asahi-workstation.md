# Fedora Asahi workstation responsibilities

Date: 2026-11-27

Status: Accepted for the tested Fedora Asahi Remix 45 KDE / aarch64 target

## Decision

Add a dedicated `fedora-asahi-bootstrap.sh` and Fedora Asahi package manifests.
Do not broaden the claim to generic Fedora support: the bootstrap verifies the
Asahi Remix OS identity and ARM64 architecture before proceeding.

Use DNF for native packages and build dependencies, Mise for user-scoped
runtimes and tools, and the shared dotfiles installer for shell/editor/terminal
configuration. Keep build dependencies and language runtimes opt-in; install
wxGTK/Mesa development packages before compiling Erlang when Observer support
is wanted.

Treat KDE Wayland input-method selection, CopyQ global shortcuts, desktop
shortcuts, default applications, and other GUI preferences as manual setup
until their settings can be captured and restored safely. Do not restore a
whole KDE configuration directory or silently overwrite user desktop state.

On Linux ARM64, Neovim uses the distribution's `clangd` rather than asking Mason
to install an unsupported binary. The distro package remains a system-level
responsibility.

## Consequences

The base restore is reproducible for the tested Asahi KDE environment while
leaving optional native builds and unverified embedded/container workflows
explicit. Existing LMDE and macOS bootstraps remain independent. Hardware
acceptance and KDE shortcut export remain manual follow-up work.

# Cross-platform workstation responsibilities

Date: 2026-11-26

Status: Accepted for LMDE/macOS. See the later [workstation philosophy](../workstation-philosophy.md) for KDE-specific choices.

## Decision

Use shared dotfiles and developer-facing commands on LMDE and macOS, while
letting each OS manage its own packages and services. `installers` owns
platform-specific installation and bootstrap; `dotfiles` owns configuration,
shared snippets and advisory diagnostics. Application repositories own their
Docker and Compose definitions.

Use CopyQ with separate local histories. On LMDE, install it with APT; on
macOS, use the official DMG through the optional installer. Normal installation
preserves quarantine; signature repair is a separate, explicit security
exception documented in [the CopyQ guide](../copyq.md).

Use native Docker Engine on LMDE and opt-in Colima on macOS. Colima runs on
demand, and neither installation nor diagnostics requires a running VM.
Preserve existing Docker configuration and data. See [the Colima guide](../colima.md).

Use Rofi on Linux and Spotlight on macOS for launching applications and shared
snippets. Platform-specific launchers remain in dotfiles.

## Consequences

The same CLI workflow is available across machines, but packages, desktop
shortcuts, container architectures and service management can differ. Optional
tool checks remain advisory, so an unavailable Docker daemon does not fail
`dotfiles-doctor`. Platform-specific setup and GUI acceptance still need to be
verified on each OS.

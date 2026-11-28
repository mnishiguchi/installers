# 2026-11-28 — Native ARM64 1Password maintenance

## Real-machine observations

- Fedora Asahi host `asahi`: `uname -m` reports `aarch64`.
- Brave is an aarch64 RPM from the vendor repository `brave-browser`.
- `rpm -q 1password` and the Flatpak query did not identify a 1Password package.
- `/usr/bin/1password` resolves to `/opt/1Password/1password`; `file -L` reports
  a native ARM64 ELF executable. The vendor `after-install.sh` exists and
  `1password --version` reports `8.12.48`.
- The layout matches the official standalone Linux installation instructions.
  The original download was not independently authenticated in this experiment.
  No reinstallation or system configuration change was needed.

## Implementation

Added the opt-in `fedora/1password.sh` for Fedora ARM64 only. The default run
preserves an existing healthy installation. `--check` is local-only and
`--update` verifies the signed stable archive before staged replacement.
Do not add 1Password to the generic bootstrap or alter Debian/macOS installers.

Offline tests cover detached signature acceptance, unexpected key rejection,
modified archive rejection, existing installation checks and no-op execution,
missing/broken/foreign installations, simulated replacement and binary-tree
rollback after a failing vendor hook. Real hardware installation/update and
browser integration still require validation. The original installation's
provenance is not established by a successful local check.

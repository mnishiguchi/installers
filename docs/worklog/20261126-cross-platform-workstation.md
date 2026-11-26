# LMDE and macOS workstation integration

Date: 2026-11-26

The installers and dotfiles changes established shared snippets, CopyQ and
Docker CLI workflows across LMDE and macOS. macOS uses Spotlight snippet apps
and opt-in Colima; LMDE uses Rofi and native Docker Engine. Bootstrap discovery,
verification and Cinnamon settings were also improved. The architectural
boundary is recorded in [the decision](../adr/20261126-cross-platform-workstation.md).

The source report records passing dotfiles doctor and CopyQ checks on both
machines, macOS bootstrap, CopyQ and Colima regression tests, and a macOS
Colima smoke test covering Compose, networking and PostgreSQL persistence.
LMDE's native Docker Engine passed a hello-world test. These are historical
results from the machines, not tests run as part of this documentation change.

Still unverified in that report: an application-specific Phoenix acceptance
test, the full Compose/PostgreSQL smoke test on LMDE, CopyQ password exclusion
with dummy credentials, and private registry authentication. Copy-on-write was
discussed but not implemented or tested. The separate [CopyQ incident
note](20261126-copyq-macos-signature-recovery.md) records the macOS signature
issue and its recovery trade-off.

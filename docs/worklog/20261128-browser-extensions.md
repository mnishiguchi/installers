# Declarative browser extension baseline

Date: 2026-11-28

The LMDE Brave active profile was `Profile 3`, not `Default`. Six extension
IDs were inventoried from its `Extensions` directory; only 1Password and Save
Pinned Tabs were selected for the workstation baseline. No full profile or
extension storage was exported into the repository.

Added an opt-in native Linux helper and one shared manifest for Brave, Chrome,
Chromium and Firefox. Chromium-family browsers use a dedicated JSON policy
file and Firefox uses an additive `Extensions.Install` list. The current Save
Pinned Tabs Firefox GUID could not be independently confirmed, so the first
pass uses its official Mozilla Add-ons slug rather than a guessed GUID. The
existing backup helper and all platform bootstraps remain unchanged.

The offline regression test exercises policy generation, explicit targeting,
read-only preview/check, installation, idempotency, unrelated policy
preservation and refusal of conflicts or symlinks. It does not launch a browser
or contact an extension store. Verify real browser acceptance first on Fedora
Asahi Brave, then LMDE and other native browser packages. Confirm 1Password
integration and Firefox/ESR extension compatibility before claiming support.

Follow-up: Brave extension installation on Fedora Asahi was reported working.
Other browser/platform combinations and extension integration remain pending.
The separate [Brave settings baseline](20261128-brave-settings.md) records the
optional service policy experiment.

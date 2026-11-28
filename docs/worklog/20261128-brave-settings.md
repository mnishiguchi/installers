# Minimal Brave policy baseline

Date: 2026-11-28

The LMDE Brave preference inventory showed a small number of customizations.
The intended baseline was narrowed to the two existing extensions, disabling
optional Brave services, and a dark appearance. Browser shortcuts are explicitly
out of scope. No complete Preferences or Local State file was exported into
this repository.

A manual experiment installed six mandatory machine policies in
`/etc/brave/policies/managed/workstation-settings.json`. The policy page showed
all six names and expected boolean values, with restart indications. The
machine used for this screenshot was not explicitly identified. Feature-level
acceptance after a complete restart remains pending.

Added a standalone opt-in helper and manifest for these six policies, using
native Linux Brave policy files rather than editing profiles. The helper adopts
an identical manual trial without elevation, repairs boolean drift, preserves
unrelated policy files, and refuses conflicting or unexpected policy content.
The existing extension and backup helpers and platform bootstraps remain
unchanged. Dark mode is left to the desktop theme or manual browser selection;
no unsupported dark-mode policy or profile-writing mechanism is introduced.

Offline tests cover preview, drift, installation, idempotency, adoption of the
manual trial, unrelated extension-policy preservation and conflict refusal.
Actual runtime acceptance of the helper on LMDE and Fedora Asahi is pending.
Extension toolbar pinning and Firefox policy modernization remain separate
follow-ups. The Gecko ID observed in the LMDE Save Pinned Tabs extension
manifest is `savepinnedtabs@buildyourweb.app`; verify against the actual Firefox
add-on before migrating the installer.

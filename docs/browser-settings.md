# Minimal Brave settings

The optional browser settings helper configures six Brave services using native
Linux group policies. It is independent of the [browser extension installer](browser-extensions.md)
and the [browser settings backup](browser-settings-backup.md). It is not part
of the platform bootstraps.

The source of truth is [`manifests/brave-settings.json`](../manifests/brave-settings.json).

| Policy | Value | Intended effect |
| --- | --- | --- |
| `BraveAIChatEnabled` | `false` | Disable Leo AI |
| `BraveNewsDisabled` | `true` | Disable Brave News |
| `BraveRewardsDisabled` | `true` | Disable Brave Rewards |
| `BraveTalkDisabled` | `true` | Disable Brave Talk |
| `BraveVPNDisabled` | `true` | Disable Brave VPN |
| `BraveWalletDisabled` | `true` | Disable Brave Wallet |

Brave Shields, search engines, privacy defaults, keyboard shortcuts, tab
behavior and other preferences are left unchanged. Dark mode is intentionally
not enforced: prefer the desktop theme or select Dark in
`brave://settings/appearance` manually if needed. No profile files are read or
modified. Extension toolbar pinning is a separate follow-up.

## Apply and verify

Prerequisites: native Linux Brave on PATH, Bash, jq, and sudo for policy writes.
Run as the desktop user on LMDE or Fedora Asahi:

```bash
./user/browser-settings.sh --dry-run
./user/browser-settings.sh
./user/browser-settings.sh --check
```

`--browser brave` is optional; other browsers are not implemented by this helper.
The target is `/etc/brave/policies/managed/workstation-settings.json`.
The previous manual experiment used this same path: matching JSON is adopted
without rewriting it or requesting sudo. Drift in the six boolean settings
can be repaired by applying the manifest again. The helper refuses unrelated
content at the target path, symlink policy files, malformed policy files and
any duplicate managed/recommended policy keys for these six settings. Review
conflicts manually rather than deleting unrelated policies. The separate
`workstation-extensions.json` remains unchanged.

Dry-run and check are read-only. Check verifies the local JSON content, not the
browser's runtime state. These are mandatory machine-wide policies for all
profiles and may display a managed-browser notice. After applying, completely
quit and relaunch Brave, open `brave://policy`, and confirm all six values are
recognized without errors or restart warnings. Check the UI for the intended
feature changes. The initial manual experiment showed all six values recognized
with restart indications; post-restart behavior has not yet been recorded.

Native Linux packages are the initial scope; Flatpak, Snap, alternate channels,
macOS and Windows are not supported by this helper.

## Undo

If the dedicated file contains only this baseline, remove it to stop enforcing
these six policies:

```bash
sudo rm /etc/brave/policies/managed/workstation-settings.json
```

Restart Brave. This does not remove extensions or restore historical profile
values; it only removes the policy enforcement. The browser may retain its own
preferences. Do not remove other policy files.

## Tests and reference

```bash
bash test/browser-settings.sh
bash test/browser-extensions.sh
```

The tests use a temporary policy tree and simulated sudo, without launching
Brave or changing real system files.

- [Brave group policy](https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy)

# Browser extensions

Install a small shared extension baseline without copying profiles or requiring
browser synchronization. This is an opt-in helper for native Linux packages
on LMDE and Fedora Asahi. Brave extension installation on Fedora Asahi was
reported working; other native browser and platform combinations remain
unverified.

The source of truth is [`manifests/browser-extensions.json`](../manifests/browser-extensions.json):

| Extension | Chrome Web Store ID | Firefox add-on slug |
| --- | --- | --- |
| 1Password | `aeblfdkhhhdcdjpifhhbdiojplfjncoa` | `1password-x-password-manager` |
| Save Pinned Tabs | `anmidgajdonkgmmilbccfefkfieajakd` | `save-pinned-tabs` |

The Chromium IDs were extracted from the LMDE Brave profile. The Firefox slugs
refer to the corresponding official Mozilla Add-ons listings. No versions are
pinned. No other extensions are blocked, and profile data is not accessed.

## Install

Prerequisites: an already installed native browser, Bash, jq, and sudo for
policy writes. Run as the desktop user. Preview before applying:

```bash
./user/browser-extensions.sh --browser brave --dry-run
./user/browser-extensions.sh --browser brave
./user/browser-extensions.sh --browser brave --check
```

Use `--browser chrome`, `--browser chromium`, or `--browser firefox` for
another browser. Omit `--browser` to target all detected supported browsers
on PATH. Only native packages are intended; Snap, Flatpak, alternate browser
channels, macOS, Windows and Edge are not implemented. A custom wrapper or
distribution-specific policy directory may need manual setup. The script does
not install browser packages or start browsers.

`--dry-run` prints the proposed JSON (including preserved existing Firefox
policy values); do not publish it unredacted if those values are private.
`--check` checks local policy content without sudo or network access. It exits
nonzero for missing/drifted policies or conflicts. Neither mode verifies that
extensions have actually downloaded or are enabled.

## Native policy locations

| Browser | Policy destination |
| --- | --- |
| Brave | `/etc/brave/policies/managed/workstation-extensions.json` |
| Chrome | `/etc/opt/chrome/policies/managed/workstation-extensions.json` |
| Chromium | `/etc/chromium/policies/managed/workstation-extensions.json` |
| Firefox / ESR | `/etc/firefox/policies/policies.json` |

Chromium-family browsers use `ExtensionSettings` with `normal_installed` and
the Chrome Web Store update endpoint. The browser downloads the extensions;
users may disable them. These are machine-wide policies for all profiles and
may display a managed-browser notice. The installer owns the dedicated
`workstation-extensions.json` file. It refuses unrelated content at that path
and refuses extension-install policies in other managed/recommended JSON files
rather than guessing which policy takes precedence. If a previous manual
experiment installed an `ExtensionSettings` file, review and reconcile it
before running this helper; do not remove unrelated settings blindly.

Firefox uses Mozilla's `Extensions.Install` with latest-XPI URLs constructed
from the official add-on slugs. This avoids guessing the current Save Pinned
Tabs Firefox GUID and does not lock extensions. It is an additive install
policy rather than the Chromium `normal_installed` policy; it preserves the
existing install list and other Firefox policies. Removing an entry from the
manifest does not remove an existing Firefox policy URL or uninstall an add-on.
The helper refuses a pre-existing Firefox `ExtensionSettings` policy, other
`Extensions` controls (such as `Locked` or `Uninstall`), and application-local
policy files in common native installation paths. Review those manually.
Mozilla recommends `ExtensionSettings` for new deployments; migration to that
policy is a follow-up after confirming the current Firefox add-on IDs.

Unchanged policy content does not trigger sudo. Policy changes are staged
and atomically replaced per file. When targeting multiple browsers, each is
processed independently; an error on a later browser does not undo earlier
writes. For a machine with existing policies, target one browser at a time.

## Verify in the actual browser

Completely restart the browser, then check:

| Browser | Policy page | Extension page |
| --- | --- | --- |
| Brave | `brave://policy` | `brave://extensions` |
| Chrome | `chrome://policy` | `chrome://extensions` |
| Chromium | `chrome://policy` | `chrome://extensions` |
| Firefox | `about:policies` | `about:addons` |

Confirm both extensions are installed and that the policy page reports no
errors. Store availability, browser version and packaging can affect the
result. In particular, the current Save Pinned Tabs Firefox release requires
Firefox 142 or later according to its version history; verify compatibility
with the installed ESR. The helper does not install unsigned extensions or
bypass browser compatibility checks.

Sign in to 1Password, configure desktop integration and restore saved tab sets
separately. This helper never reads passwords, Secret Keys, cookies, history,
bookmarks, browser profiles or extension-specific storage. The existing
[browser settings backup](browser-settings-backup.md) is a separate workflow.

## References

- [Brave group policy](https://support.brave.app/hc/en-us/articles/360039248271-Group-Policy)
- [Chrome extension policies on Linux](https://support.google.com/chrome/a/answer/7517525)
- [Chromium Linux policy paths](https://www.chromium.org/administrators/linux-quick-start/)
- [Firefox policy configuration](https://firefox-admin-docs.mozilla.org/guides/policies-configuration/)
- [Firefox Extensions policy](https://firefox-admin-docs.mozilla.org/reference/policies/extensions/)
- [1Password deployment](https://support.1password.com/deploy-1password-browser/)
- [1Password Firefox listing](https://addons.mozilla.org/en-US/firefox/addon/1password-x-password-manager/)
- [Save Pinned Tabs Firefox listing](https://addons.mozilla.org/en-US/firefox/addon/save-pinned-tabs/)

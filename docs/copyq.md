# CopyQ on LMDE and macOS

Use [CopyQ](https://copyq.readthedocs.io/) as the common clipboard history
manager. Installation is owned by this `installers` repository; `dotfiles`
only checks that the `copyq` command is available.

## LMDE 7

The APT manifest installs `copyq` and the upstream-recommended `copyq-plugins`
package (plugins are split into a separate package on Debian):

```bash
sudo apt install copyq copyq-plugins
```

The Cinnamon settings snapshot already assigns **Super+V** to `copyq show`.
Restore the desktop settings with `lm-desktop-settings.sh` if that binding is
missing. The normal `lm-bootstrap.sh` APT section installs the managed packages.

## macOS 13 and newer

The official Homebrew cask is currently disabled because the upstream app
does not pass Homebrew's Gatekeeper checks. Do not add `cask "copyq"` to the
Brewfile, use an unofficial tap, remove quarantine automatically, or ad-hoc
sign the app as part of workstation bootstrap.

Use the pinned official Apple Silicon or Intel DMG instead:

```bash
./macos-bootstrap.sh --only copyq
```

The installer opens the official `hluk/CopyQ` GitHub release asset in your
browser. Download the Apple Silicon or Intel DMG, then provide its path when
prompted (the default is `~/Downloads`). A browser download is required because
it carries macOS quarantine metadata; the installer refuses a DMG without that
attribute. It downloads the official SHA-512 manifest, verifies the DMG, copies
the app to `/Applications` when writable (otherwise `~/Applications`), and
propagates the quarantine marker to the copied app. It creates a user-local
`~/.local/bin/copyq` link. It does not launch the app or change macOS security
settings. You can set `COPYQ_DMG_PATH` to a previously downloaded, quarantined
DMG to skip opening the browser.

The upstream macOS app is not Developer ID signed/notarized. The installer
requires the explicit phrase `INSTALL COPYQ` before proceeding. It propagates
the browser's quarantine attribute to the installed app; normal installation
never clears quarantine or changes code signatures. It also repairs only an
exact, dangling `~/.local/bin/copyq` symlink that points to the expected
`/Applications/CopyQ.app` executable. It refuses to replace regular files,
live links, or links to any other target.

After installation, `--check` verifies the app version, CLI link, and nested
code-signature integrity. The upstream release may fail strict nested signature
verification on macOS even though its DMG checksum is correct. If that happens,
do not blindly remove quarantine or ad-hoc sign the app. First inspect the
bundle and decide whether you accept the application-specific security
exception described below.

### Optional signature repair

The `repair-signature` mode implements the upstream workaround as a separate,
explicit operation. It is not run by `install`, `macos-bootstrap.sh`, or normal
workstation bootstrap:

```bash
./macos/copyq-install.sh repair-signature
```

It requires the original browser-downloaded, quarantined DMG (default:
`~/Downloads/CopyQ-17.0.0-macos-13-m1.dmg` on Apple Silicon), re-downloads the
official SHA-512 manifest, verifies the DMG, mounts it read-only, and compares
the installed app's contents with the app inside that verified release. It
refuses repair if the contents differ or CopyQ is running. It then asks for the
exact phrase `REPAIR COPYQ SIGNATURE`, removes the quarantine attribute from
this `CopyQ.app` bundle only, and runs the documented deep ad-hoc signing
workaround. A strict nested-signature verification must pass afterward.

**Security trade-off:** removing quarantine bypasses macOS's downloaded-app
quarantine protection for CopyQ. An ad-hoc signature provides local code
integrity checking; it does not identify the developer, establish publisher
authenticity, or notarize the app. The verified DMG checksum establishes that
the source matches the published release asset, not that the upstream release
is safe. Use this only if you have reviewed and accept that risk. It does not
disable Gatekeeper globally or modify SIP, other applications, or Accessibility
permissions. To return to the original quarantined app, reinstall from the
official DMG; the original downloaded DMG is left unchanged.

If signature verification already passes, `repair-signature` is a no-op. The
`--check` mode reports ad-hoc signing explicitly and does not claim that the
app is Developer ID signed or notarized. Accessibility permission may be
required for global shortcuts. Add CopyQ manually under System Settings >
General > Login Items if you want it to start at login.

Check the installation without launching the app:

```bash
./macos-bootstrap.sh --only copyq --check
copyq --version
```

## Shortcuts

| Action | LMDE 7 | macOS |
| --- | --- | --- |
| Show clipboard history | Super+V (managed Cinnamon binding) | Command+Shift+V (configure in CopyQ) |
| Search | Type in the history window | Type in the history window |
| Select/paste | Enter | Enter |
| Close/hide | Esc | Esc |

To configure the macOS shortcut:

1. Start CopyQ.
2. Open the Commands dialog with `F6`.
3. Click Add and choose **Show/hide main window**.
4. Set its Global Shortcut to **Command+Shift+V** and save.

This GUI shortcut is deliberately not written into macOS preferences by the
bootstrap. Keep the Linux Super+V binding unchanged.

## Privacy and data

CopyQ stores clipboard history persistently. Treat it as sensitive local data:

- Do not assume passwords, access tokens, or 1Password items are automatically
  excluded from history.
- CopyQ provides an **Ignore Password window** automatic command. Configure
  and test it with dummy data; window-title matching is not reliable for every
  password manager or popup. Place the ignore command before other automatic
  commands. See the [CopyQ FAQ](https://copyq.readthedocs.io/en/latest/faq.html).
- Set a reasonable history limit and clear entries you no longer need.
- Do not synchronize or copy the live clipboard database between machines.
  Keep each computer's history local.

CopyQ 17.0.0 changes where tab data and state are stored. On first startup, it
migrates the existing files; this is backwards-incompatible, and older CopyQ
versions will not see the migrated data. Before a major-version upgrade, use
**File > Export** to back up tabs, configuration, and commands, or close CopyQ
and back up all its configuration, data, and state directories.

Default paths in CopyQ 17.0.0:

| Platform | Configuration | Data | State |
| --- | --- | --- | --- |
| LMDE / Linux | `~/.config/copyq` | `~/.local/share/copyq` | `~/.local/state/copyq` |
| macOS | `~/Library/Preferences/copyq` | `~/Library/Application Support/copyq` | `~/Library/Application Support/copyq` |

Use `copyq info config`, `copyq info data`, and `copyq info state` to inspect
the actual paths. Package versions may differ between LMDE's APT repository
and the pinned macOS DMG. Keep each computer's history local; do not copy the
live database between platforms.

## Diagnostics

```bash
command -v copyq
copyq --version
dotfiles-doctor
```

`dotfiles-doctor` treats CopyQ as an optional desktop application: it reports
missing CopyQ as an advisory warning and does not launch the GUI or inspect
clipboard contents.

# Fedora Asahi desktop applications

Manual post-installation steps for the tested Fedora Asahi Remix 45 KDE
Wayland workstation (Apple M1 Pro, aarch64, 16 KiB kernel pages).
Follow the [workstation restore guide](fedora-asahi.md) first.

## Application strategy

| Application | Approach on Fedora Asahi | Verification |
| --- | --- | --- |
| Brave | Official native ARM64 RPM | Repository `brave-browser`; version 158.1.100.59 observed |
| 1Password | Official-style native ARM64 standalone archive | 8.12.48 runs; local layout verified; original download signature not independently verified |
| Slack | Official web application installed through Brave | Sign-in, standalone window, KRunner and dark mode verified |
| Discord | Official web application installed through Brave | Installation and KRunner launch reported successful |

Use the vendor's web application in the existing native browser where it meets
the workflow requirements. This avoids another Electron runtime, x86 emulation,
and unofficial clients. Do not assume an ARM64 binary also supports the Asahi
16 KiB page size. Reevaluate alternatives only when a verified feature gap
justifies them. For work accounts, follow the organization's application and
browser policies.

Browser applications are manual user-level steps; the optional 1Password
installer is separate from the package bootstrap and its `--check` contract.
Existing LMDE and macOS workflows are unchanged.

## Browser prerequisites

Install Brave using its [official Linux installation instructions](https://brave.com/linux/)
for the target architecture if it is missing. The browser was already installed
for this experiment; the installation command was not replayed here.

```bash
brave-browser --version
uname -m
getconf PAGESIZE
```

Expected architecture: `aarch64`; the tested Asahi kernel reports `16384`.

## Slack and Discord

1. Open [Slack](https://app.slack.com/) or [Discord](https://discord.com/app)
   in the intended Brave profile and sign in manually.
2. In Brave, select **Menu > Save and Share > Install page as app...**.
3. Name the application `Slack` or `Discord` and confirm installation.
4. Press Super+Space, search for the application in KRunner and launch it.
5. Confirm it opens in a dedicated window and uses the intended account.

Repeat for the other application. Manage installed web apps at `brave://apps`.
If discovery fails, confirm installation in the correct Brave profile and
check KDE's application menu before creating any custom desktop entries.

### Appearance

For Slack, open **Profile picture > Preferences > Appearance > Color Mode**
and select **Dark**. This was verified and matches Breeze Dark without
requiring a browser extension. Discord appearance can be set independently
in its own user settings; no Discord theme change was recorded in this test.

### Audio, video and desktop integration

The following diagnostics were verified on the running desktop. They are
read-only and require no sudo:

```bash
rpm -q pipewire wireplumber xdg-desktop-portal xdg-desktop-portal-kde
systemctl --user is-active \
    pipewire.service \
    pipewire-pulse.service \
    wireplumber.service \
    xdg-desktop-portal.service \
    plasma-xdg-desktop-portal-kde.service
wpctl status
```

All five services were active. The KDE backend's service name includes the
`plasma-` prefix on the tested Fedora release; an `inactive` result from
`xdg-desktop-portal-kde.service` alone is not evidence of a failed backend.
PipeWire detected audio devices, Asahi audio processing filters and the
FaceTime HD camera. This does not establish that browser calls work.

Acceptance checklist (run separately for each application):

- [ ] Send and receive messages; attach a harmless test file.
- [ ] Receive desktop notifications with the web app in the background.
- [ ] Enter and commit Japanese text using Mozc.
- [ ] Test microphone and speaker output in a call (Slack huddle / Discord voice).
- [ ] Test camera access and screen/window sharing with non-sensitive content.
- [ ] Reopen the web app after logout/login and test suspend/resume behavior.

Allow site notification, microphone and camera permissions only as needed.
If Slack huddles fail in Brave, check Slack's current supported browsers and
consider an official native ARM64 browser before unofficial Slack clients.
If Discord voice or sharing fails, investigate the browser and KDE portal
first; do not install an unofficial client by default. Check current vendor
support and account policies before choosing alternatives.

## 1Password

The tested workstation runs 1Password 8.12.48 as a native aarch64 ELF binary,
with `/usr/bin/1password` pointing to `/opt/1Password/1password` and the vendor
`after-install.sh` present. It is not installed through RPM or Flatpak. This
matches the standalone layout in the [official Linux setup guide](https://support.1password.com/install-linux/).
The original archive and its signature were not retained for independent verification.

Use the optional Fedora ARM64 installer from the repository root:

```bash
./fedora/1password.sh --check   # Local layout and version only
./fedora/1password.sh           # Install if absent; no-op if healthy
./fedora/1password.sh --update  # Explicitly fetch and install a newer stable release
```

Run as your regular user. Quit 1Password completely (including its tray
process) before installing or updating; do not interrupt the operation.
The script requires `curl`, `gpg` (Fedora `gnupg2`), `tar`, `file`, `rpm`,
`sudo`, `procps-ng` and standard GNU utilities. It does not install packages
or change the system package manifest. The check does not contact the network
or authenticate the already-installed binary; it checks the expected layout,
architecture, ownership of key files and the locally reported version.

The install/update path fetches the stable ARM64 archive, its detached signature
and the signing key from 1Password. It pins the published primary fingerprint
`3FEF9748469ADBE15DA7CA80AC2D62742012EA22` in an isolated GPG home. Signature
failure, unexpected archive layout or architecture, an existing incompatible
installation, or a requested downgrade stops the operation. A same-version
update downloads and verifies the archive but does not replace the application.
If the vendor changes the archive naming scheme or signing key, review the
upstream documentation before changing the checks; never bypass them.

The script stages the application under `/opt`, retains the old binary tree
until the vendor hook and local checks succeed, then removes the staging tree.
If the hook or final version check fails, it attempts to restore the old tree
and retains the staging directory for inspection. System integration changes
made by the vendor hook are not transactional; inspect and repair them manually
if necessary. Do not run concurrent installers or updates. No user vault or
browser configuration is intentionally modified by the wrapper. Keep access to
your account recovery information before an update.

The standalone app is not updated by DNF. Consult the [stable release notes](https://releases.1password.com/linux/stable/)
and the [vendor update guide](https://support.1password.com/update-1password/)
for maintenance. Sign in manually and test browser extension integration after
installation. The script has offline regression coverage; real ARM64 installation,
upgrade, and browser integration are still to be tested.

## Restore and security boundaries

Do not commit browser profiles, generated account-specific desktop entries,
credentials, cookies, session tokens, vault exports, or account identifiers.
Use the [browser settings backup guide](browser-settings-backup.md) for portable
settings only; recreate web apps and authenticate manually after restoring.
Do not assume a settings-only backup restores web app registration or login
sessions.

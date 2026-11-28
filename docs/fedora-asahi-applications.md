# Fedora Asahi desktop applications

Manual post-installation steps for the tested Fedora Asahi Remix 45 KDE
Wayland workstation (Apple M1 Pro, aarch64, 16 KiB kernel pages).
Follow the [workstation restore guide](fedora-asahi.md) first.

## Application strategy

| Application | Approach on Fedora Asahi | Verification |
| --- | --- | --- |
| Brave | Native ARM64 browser | Running; version 158.1.100.59 observed |
| 1Password | Installed manually | Installation reported successful; package source and restore procedure not yet recorded |
| Slack | Official web application installed through Brave | Sign-in, standalone window, KRunner and dark mode verified |
| Discord | Official web application installed through Brave | Installation and KRunner launch reported successful |

Use the vendor's web application in the existing native browser where it meets
the workflow requirements. This avoids another Electron runtime, x86 emulation,
and unofficial clients. Do not assume an ARM64 binary also supports the Asahi
16 KiB page size. Reevaluate alternatives only when a verified feature gap
justifies them. For work accounts, follow the organization's application and
browser policies.

These are manual user-level steps, not part of the package bootstrap or its
`--check` contract. Existing LMDE and macOS workflows are unchanged.

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

Installation was reported successful on Fedora Asahi. Record the exact
installation source before adding a reproducible installer; do not reuse the
Debian-specific installer on Fedora. The following queries can help identify
an RPM installation and its source without accessing vault contents:

```bash
rpm -q 1password brave-browser
# If installed through DNF, inspect the corresponding package metadata:
dnf info --installed 1password brave-browser
```

Use the [official Linux setup guide](https://support.1password.com/install-linux/)
when restoring. Sign in manually; browser extension integration and vault
recovery have not been independently verified in this experiment.

## Restore and security boundaries

Do not commit browser profiles, generated account-specific desktop entries,
credentials, cookies, session tokens, vault exports, or account identifiers.
Use the [browser settings backup guide](browser-settings-backup.md) for portable
settings only; recreate web apps and authenticate manually after restoring.
Do not assume a settings-only backup restores web app registration or login
sessions.

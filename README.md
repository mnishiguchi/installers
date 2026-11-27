# Machine setup scripts

Personal scripts and manifests for rebuilding my LMDE workstation, Fedora Asahi
Remix ARM64 KDE workstation, and macOS terminal development environment. The
Fedora bootstrap targets the tested Asahi Remix environment, not generic Fedora.

## LMDE workstation restore

See [LMDE 7 clean installation](docs/lmde-clean-install.md) for the complete
installation and recovery procedure.

```bash
./lm-bootstrap.sh --upgrade
sudo reboot
```

After logging in again:

```bash
cd "$HOME/Projects/installers"
./lm-bootstrap.sh --check
```

## Fedora Asahi Remix 45 (ARM64 / KDE)

See [Fedora Asahi workstation](docs/fedora-asahi.md) for the tested target,
package ownership, KDE Wayland setup, and remaining acceptance checks.

```bash
./fedora-asahi-bootstrap.sh --check
./fedora-asahi-bootstrap.sh
./fedora-asahi-bootstrap.sh --only build,runtimes
```

The default restore manages native DNF packages, KDE input/clipboard packages,
FiraCode Nerd Font, shared dotfiles, Mise-managed Yazi/shfmt/resvg, and the Fish
login shell. Native build dependencies and language runtimes are an explicit
follow-up section.

Optional KDE preferences (separate from package installation):

```bash
./kde/desktop-config.sh --check
./kde/desktop-config.sh
```

Global shortcuts and Fcitx5 profile setup are still manual. See the Fedora Asahi guide.

## macOS development environment

See [macOS setup](docs/macos-setup.md) for Homebrew, Alacritty, and prerequisites.
See [Colima Docker development](docs/colima.md) for optional container tooling.
See [CopyQ across LMDE, Fedora Asahi, and macOS](docs/copyq.md) for clipboard manager setup and shortcuts.

```bash
./macos-bootstrap.sh --only preflight
./macos-bootstrap.sh --check
./macos-bootstrap.sh
```

Optional extras and native build dependencies are opt-in (`--only optional`,
`--only build,runtimes`). Run `--only verify` and `dotfiles-doctor` after setup.
The bootstrap reuses an active dotfiles checkout, preserves local changes, and
checks Mise tool resolution in a fresh Fish login shell. Re-run `--check` to
verify the managed state.

## Repository map

| Path | Purpose |
| --- | --- |
| [`debian/`](debian/) | System software installers and uninstallers for Debian/LMDE |
| [`user/`](user/) | Per-user tools, developer setup, and settings backup helpers |
| [`manifests/`](manifests/) | APT, Homebrew, and Fedora Asahi package manifests; managed Cinnamon/Fcitx state |
| [`docs/`](docs/) | Restore guides, operational notes, and incident records |

## Top-level tools

| Script | Purpose |
| --- | --- |
| [`fedora-asahi-bootstrap.sh`](fedora-asahi-bootstrap.sh) | Restore or check the tested Fedora Asahi Remix ARM64 KDE workstation |
| [`macos-bootstrap.sh`](macos-bootstrap.sh) | Restore or check the macOS terminal development environment |
| [`macos/colima-setup.sh`](macos/colima-setup.sh) | Optional Colima CLI setup (does not start a VM) |
| [`bin/colima-smoke-test`](bin/colima-smoke-test) | Disposable Docker Compose integration test |
| [`macos/copyq-install.sh`](macos/copyq-install.sh) | Verify/install the official CopyQ macOS DMG; optional, explicit nested-signature repair |
| [`lm-bootstrap.sh`](lm-bootstrap.sh) | Restore or check the managed workstation state by section |
| [`lm-desktop-settings.sh`](lm-desktop-settings.sh) | Capture, restore, or compare Cinnamon and Fcitx settings |
| [`lm-networkmanager-connections.sh`](lm-networkmanager-connections.sh) | Back up, encrypt, and restore NetworkManager profiles |
| [`lm-usb-writer.sh`](lm-usb-writer.sh) | Download, authenticate, write, and verify an LMDE installer USB |

The bootstrap and USB writer must be started as the desktop user. They request
`sudo` only for the operations that need it. The NetworkManager helper documents
which subcommands elevate privileges in its [guide](docs/networkmanager-connections.md).

## Safety conventions

- Run scripts from this checkout so relative manifests and companion scripts can
  be found.
- Start per-user scripts without `sudo`. System installers request elevation
  when needed.
- Uninstallers preserve user data by default where practical; destructive purge
  options are explicit.
- Keep NetworkManager exports encrypted because connection profiles can contain
  Wi-Fi passwords and VPN secrets.

## Recovery helpers

- [`lm-networkmanager-connections.sh`](lm-networkmanager-connections.sh) safely
  backs up and restores Wi-Fi, wired, and VPN connection profiles.
- [`user/browser-settings-backup.sh`](user/browser-settings-backup.sh) makes a
  settings-only Chrome and Brave backup without copying complete profiles.

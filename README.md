# Machine setup scripts

Personal scripts and manifests for rebuilding my LMDE workstation, including
installer media, applications, development tools, dotfiles, Cinnamon/Fcitx
settings.

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

## Repository map

| Path | Purpose |
| --- | --- |
| [`debian/`](debian/) | System software installers and uninstallers for Debian/LMDE |
| [`user/`](user/) | Per-user tools, developer setup, and settings backup helpers |
| [`manifests/`](manifests/) | Package lists and managed Cinnamon/Fcitx state |
| [`docs/`](docs/) | Restore guides, operational notes, and incident records |

## Top-level tools

| Script | Purpose |
| --- | --- |
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

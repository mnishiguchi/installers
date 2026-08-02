# Machine setup scripts

Personal scripts and manifests for rebuilding my LMDE workstation, including
installer media, applications, development tools, dotfiles, Cinnamon/Fcitx
settings, and device helpers.

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

## Recovery helpers

- [`lm-networkmanager-connections.sh`](lm-networkmanager-connections.sh) safely
  backs up and restores Wi-Fi, wired, and VPN connection profiles.

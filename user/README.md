# User environment helpers

Scripts for installing and configuring tools scoped primarily to the current
user's home directory.

Run these scripts as the desktop user, not with `sudo`.

## Script catalog

| Script | Purpose |
| --- | --- |
| `browser-settings-backup.sh` | Back up portable Chrome and Brave settings and bookmarks |
| `diff-so-fancy-install.sh` / `diff-so-fancy-uninstall.sh` | Manage a per-user diff-so-fancy checkout and command link |
| `git-config-generate.sh` | Interactively create common global Git settings |
| `github-ssh-setup.sh` | Generate and register a local GitHub SSH key |
| `neovim-install.sh` / `neovim-uninstall.sh` | Manage a per-user Neovim release under `~/.local` |
| `nerd-fonts-install.sh` | Install FiraCode Nerd Font for the current user |
| `nerves-setup.sh` | Bootstrap Hex/Rebar/Nerves tools and clone `nerves_systems` |

## Browser settings

See [Browser settings backup](../docs/browser-settings-backup.md) for the
settings-only Google Chrome and Brave backup helper.

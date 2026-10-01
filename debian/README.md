# Debian system helpers

Scripts for installing or removing software and OS dependencies on Debian-based
systems. Individual scripts document whether they operate system-wide or only
for the current user.

Run these scripts as the desktop user unless a script explicitly says otherwise.
System-wide installers invoke `sudo` for the operations that require it.

## Script catalog

| Software | Install | Uninstall | Scope and notes |
| --- | --- | --- | --- |
| 1Password | `1password-install.sh` | `1password-uninstall.sh` | Official APT repository, debsig policy, and Yama configuration |
| Android Studio | `android-studio-install.sh` | `android-studio-uninstall.sh` | System install under `/opt`; settings and SDK purges are optional |
| Arduino IDE | `arduino-ide-install.sh` | `arduino-ide-uninstall.sh` | Per-user XDG-aware install; no `sudo` |
| Docker Engine | `docker-install.sh` | `docker-uninstall.sh` | System install; Docker data and group removal are opt-in |
| Nerves dependencies | `nerves-deps-install.sh` | — | Debian build packages for Nerves development |
| Visual Studio Code | `vscode-install.sh` | `vscode-uninstall.sh` | Official Debian package; user-data removal is interactive |

## Arduino IDE

Arduino IDE is installed per-user from the official Linux ZIP, so these scripts
must be run without `sudo`:

```bash
./debian/arduino-ide-install.sh
./debian/arduino-ide-uninstall.sh
```

The installer supports `--version VERSION` and `--dry-run`. The uninstaller
keeps settings, downloaded board packages, and sketches by default; see
`./debian/arduino-ide-uninstall.sh --help` for the explicit purge options.

When `sha256sum` and `jq` are available, the installer obtains the selected
archive's SHA-256 digest from the official GitHub release API and verifies the
download. Set `ARDUINO_IDE_SHA256` to a known digest to verify without API
discovery.

The default layout follows Linux/XDG conventions where they apply:

- application payload: `~/.local/opt/arduino-ide-VERSION`
- command: `~/.local/bin/arduino-ide`
- desktop entry: `$XDG_DATA_HOME/applications/arduino-ide.desktop`
- themed icon: `$XDG_DATA_HOME/icons/hicolor/512x512/apps/arduino-ide.png`

XDG does not define a location for a private application payload containing
architecture-dependent executables and libraries. `~/.local/opt` is used as the
per-user counterpart to `/opt`; `ARDUINO_IDE_INSTALL_ROOT` can override it.

Arduino IDE itself stores some settings and downloaded packages in
upstream-defined paths such as `~/.arduinoIDE` and `~/.arduino15`. The
uninstaller's explicit purge options handle those alongside the IDE's XDG
config and cache directories.

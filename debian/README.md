# Debian system helpers

Scripts for installing or removing software and OS dependencies on Debian-based
systems. Individual scripts document whether they operate system-wide or only
for the current user.

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

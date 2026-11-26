# Desktop settings

Managed Cinnamon and Fcitx/Mozc snapshots captured and restored by
`lm-desktop-settings.sh`.

## Capture and check

Run commands as the logged-in desktop user, not with `sudo`.

```sh
# Capture the complete managed desktop, including Cinnamon applets and Fcitx.
./lm-desktop-settings.sh capture
./lm-desktop-settings.sh check

# Capture or check only Cinnamon keyboard shortcuts.
./lm-desktop-settings.sh capture-keybindings
./lm-desktop-settings.sh check-keybindings
```

The focused keybinding commands operate only on
`/org/cinnamon/desktop/keybindings/`, including custom shortcuts, window
manager shortcuts, and media-key bindings. They replace or compare only the
matching `desktop/keybindings` sections in `cinnamon.dconf`; other Cinnamon
settings, applet JSON snapshots, and the Fcitx profile are left untouched.
They do not include input-source layout configuration under
`/org/cinnamon/desktop/input-sources/`.

`capture-keybindings` is safe to repeat. It normalizes the home directory to
`@HOME@`, verifies the merged sections before replacing the snapshot, and
refuses to overwrite the snapshot if the live dconf subtree is empty or
verification fails. Review `git diff -- manifests/desktop/cinnamon.dconf`
before committing. `check-keybindings` is read-only and exits nonzero when the
tracked keybindings differ from the current desktop.

# Browser settings backup

Use `user/browser-settings-backup.sh` to back up portable Google Chrome and
Brave settings without copying complete browser profiles. Close both browsers
before running it.

```bash
./user/browser-settings-backup.sh
```

The default destination is a new timestamped directory under
`~/browser-settings-backup`. An explicit destination must not already exist:

```bash
./user/browser-settings-backup.sh /path/to/backup/browser-settings
```

The helper reads profiles named `Default` or `Profile *` from:

```text
~/.config/google-chrome
~/.config/BraveSoftware/Brave-Browser
```

Confirm the active profile in `chrome://version` or `brave://version`. The
backup includes root-level `Local State` and these files from each profile:

```text
Preferences
Secure Preferences
Bookmarks
Bookmarks.bak
```

Extension code and settings are optional because browser synchronization can
usually restore them. Include them only when needed:

```bash
./user/browser-settings-backup.sh --include-extension-settings
```

The settings-only backup excludes credentials, cookies, active sessions, site
storage, IndexedDB, service workers, synchronization state, lock files, caches,
and crash reports.

## Restore order

Close the browser and back up its newly created profile before replacing any
file. Restore and test one stage at a time:

1. `Bookmarks` and `Bookmarks.bak`
2. `Preferences`
3. `Secure Preferences`
4. `Local State`, only if browser-wide settings remain missing
5. Extension directories, only if synchronization is unavailable

Do not copy an old browser-data directory over a fresh installation.

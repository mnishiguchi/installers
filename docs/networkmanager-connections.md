# NetworkManager connection backup and restore

NetworkManager normally stores saved Wi-Fi, wired, and VPN profiles in:

```text
/etc/NetworkManager/system-connections/
```

These files can contain passwords and VPN secrets. Keep every backup encrypted
or accessible only to root.

## Back up profiles

From this repository, run:

```bash
./lm-networkmanager-connections.sh backup
```

This creates a timestamped, root-only directory under `/root`, keeping secrets
out of the Git checkout. Supply a destination on an encrypted backup volume to
make a persistent copy:

```bash
./lm-networkmanager-connections.sh backup /path/to/secure/backup
```

Remember that a home-directory backup will include these profiles only if the
chosen destination is inside the backed-up data. A normal backup of `/etc` may
already contain them.

## Export to a USB drive

FAT and exFAT USB drives cannot preserve the ownership and permissions required
for plaintext NetworkManager profiles. Export them as a GPG-encrypted archive
instead:

```bash
./lm-networkmanager-connections.sh export \
  "/media/$USER/DRIVE/networkmanager-connections-$(date +%Y%m%d-%H%M%S).tar.gpg"
```

Run the command as your normal user. The script asks for sudo authorization to
read the profiles, then GPG asks you to choose a passphrase. It streams the
profiles directly into the encrypted archive, without making a plaintext copy
on the USB drive. Store the passphrase separately; the archive cannot be
recovered without it.

## Restore profiles

Pass either the profile directory itself:

```bash
./lm-networkmanager-connections.sh restore \
  /path/to/backup/etc/NetworkManager/system-connections
```

or the root of a filesystem backup containing that path:

```bash
./lm-networkmanager-connections.sh restore /path/to/backup
```

An encrypted USB export can be restored directly. Run this as your normal user
as well; the script requests sudo authorization before decrypting the archive:

```bash
./lm-networkmanager-connections.sh restore \
  /media/$USER/DRIVE/networkmanager-connections-YYYYmmdd-HHMMSS.tar.gpg
```

The archive is decrypted into a temporary user-only directory. The script
removes that directory after the normal restore completes.

The script first saves the fresh machine's profiles under `/root`, installs the
restored files as `root:root` with mode `0600`, reloads NetworkManager, and lists
the available connections. Restore merges profiles and does not delete profiles
found only on the current machine.

Do not blindly restore `/etc/NetworkManager/NetworkManager.conf` or
`/var/lib/NetworkManager/`; they may contain installation-specific settings and
machine identity data.

After restoring, adjust profiles that refer to an old interface name, a specific
MAC address, or VPN certificate files that were stored elsewhere.

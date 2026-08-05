# LMDE 7 Clean Installation

Reinstall LMDE from `installers` and `dotfiles`, then restore personal data with
Pika Backup. Timeshift is only an emergency rollback of the old system. The
bootstrap does not restore personal files, credentials, browser profiles, or
project repositories.

## 1. Prepare

- Run Pika Backup and test restoring several files.
- If the backup is encrypted, store its password separately.
- Verify the Family Emergency Kit is complete and accessible.
- Create a fresh 1PUX export if an offline 1Password backup is needed. Desktop
  1PUX exports are unencrypted, so store one only in encrypted storage.
- Record which important accounts use passkeys. Desktop 1PUX exports do not
  include passkeys, so migrate or recreate them separately.
- Create a final Timeshift snapshot on an external drive.
- Review untracked files, stashes, and unpushed branches.
- Capture desktop changes:

  ```bash
  cd "$HOME/Projects/installers"
  ./lm-desktop-settings.sh capture
  git diff -- manifests/desktop
  ```

- Commit and push both `installers` and `dotfiles`.
- Disconnect backup drives.

Continue only after the restore test succeeds and all irreplaceable data is
backed up.

## 2. Create the installer USB

Connect only the disposable USB drive, then run:

```bash
cd "$HOME/Projects/installers"
./lm-usb-writer.sh
```

Before entering the required `ERASE /dev/...` confirmation, verify the USB by
model and capacity and select its whole-disk device (for example, `/dev/sdb`),
not a partition.

## 3. Install LMDE

1. Shut down, connect AC power, and insert the USB.
2. Open the one-time boot menu and select USB.
3. Test the keyboard, touchpad, Wi-Fi, display, and audio in the live session.
4. Open **Install Linux Mint** and choose the automated whole-disk install.

Verify the target disk by model and capacity. If enabling encryption, record
the passphrase before starting. When installation finishes, restart, remove
the USB, and log in.

## 4. Restore the system

Install Git and clone the bootstrap repository over HTTPS:

```bash
sudo apt update
sudo apt install -y git

mkdir -p "$HOME/Projects"
cd "$HOME/Projects"
git clone https://github.com/mnishiguchi/installers.git
cd installers
```

Restore the managed system state:

```bash
./lm-bootstrap.sh --upgrade
```

Use `--skip-shell-change` to keep Bash temporarily; see `--help` for selective
restoration.

After the bootstrap completes, sign in to 1Password using the Emergency Kit and
allow vault data to synchronize from the Family account. Do not restore
`~/.config/1Password` as the normal recovery method. Verify several important
logins before deleting any old backups.

Reboot to apply session, shell, Docker group, desktop, and input-method changes:

```bash
sudo reboot
```

## 5. Validate the clean desktop

Before reconnecting the backup drive or restoring personal configuration, log
in to the rebooted system and verify that the desktop, file manager, terminal,
browser, keyboard input, and managed shortcuts work normally.

Resolve any problems before restoring application configuration so bootstrap
issues can be distinguished from restored user state.

## 6. Restore personal data

Reconnect the backup drive and restore personal files from Pika. Do not restore
these directories wholesale:

```text
~/.cache
~/.config
~/.local
```

Restore browser profiles, application data, credentials, `~/.ssh`, and
`~/.gnupg` selectively. Keep `~/.config/1Password` out of this restoration:
sign in through the Emergency Kit and let the Family account synchronize vault
data. Clone published projects from GitHub and restore only local-only work
from Pika.

Validate the result:

```bash
cd "$HOME/Projects/installers"
./lm-bootstrap.sh --check

git status --short
git -C ../dotfiles status --short
ssh -T git@github.com
```

## 7. Create a new backup baseline

Create a Timeshift snapshot named `Clean LMDE 7 baseline`, then run a new Pika
Backup and test restoring several files. Keep the preinstallation backups until
the bootstrap check passes, personal files are present, GitHub access works,
and the new restore test succeeds.

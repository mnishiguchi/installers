#!/usr/bin/env bash
# Back up and restore NetworkManager connection profiles without machine state.
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
SCRIPT_PATH="$SCRIPT_DIR/$(basename -- "${BASH_SOURCE[0]}")"
readonly SCRIPT_PATH
readonly CONNECTION_DIR="/etc/NetworkManager/system-connections"

say() { printf '\n%s\n' "$*"; }
ok() { printf 'OK: %s\n' "$*"; }
fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: lm-networkmanager-connections.sh <command> [path]

Back up or restore NetworkManager connection profiles. Backups can contain
Wi-Fi passwords and VPN secrets, so directory backups are kept root-only and
portable backups are encrypted.

Commands:
  backup [directory]  Copy the current profiles to directory. By default, use
                      /root/networkmanager-connections-YYYYmmdd-HHMMSS.
  export <archive>    Write a GPG-encrypted archive suitable for a USB drive.
  restore <path>      Merge profiles from a profile directory, encrypted
                      archive, or PATH/etc/NetworkManager/system-connections.
                      The current profiles are first saved under /root.
  list                Show connections known to NetworkManager.
  help                Show this help.

Restore does not remove profiles that exist only on the current machine.
EOF
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

require_unprivileged_user() {
  [[ $EUID -ne 0 ]] ||
    fail "run this command without sudo; the script will request access when needed"
}

become_root() {
  [[ $EUID -eq 0 ]] && return 0
  require_command sudo
  exec sudo -- "$SCRIPT_PATH" "$@"
}

validate_profile_directory() {
  local directory="$1"
  local unsafe_entry

  [[ -d "$directory" ]] || fail "profile directory does not exist: $directory"
  unsafe_entry="$(find "$directory" -mindepth 1 -maxdepth 1 ! -type f -print -quit)"
  [[ -z "$unsafe_entry" ]] ||
    fail "profile directory contains a non-regular entry: $unsafe_entry"
}

profile_files() {
  find "$1" -mindepth 1 -maxdepth 1 -type f -print0
}

stream_profile_archive() {
  [[ $EUID -eq 0 ]] || fail "archive stream requires root"
  validate_profile_directory "$CONNECTION_DIR"
  require_command tar

  tar --create --file=- --directory="$CONNECTION_DIR" -- .
}

export_profiles() {
  local destination="$1"
  local partial_destination="${destination}.partial"
  local parent

  require_unprivileged_user
  require_command gpg
  require_command sudo
  [[ ! -e "$destination" ]] || fail "export destination already exists: $destination"
  [[ ! -e "$partial_destination" ]] ||
    fail "temporary export destination already exists: $partial_destination"

  parent="$(dirname -- "$destination")"
  [[ -d "$parent" ]] || fail "export destination directory does not exist: $parent"
  [[ -w "$parent" ]] || fail "export destination directory is not writable: $parent"

  say "Authorizing access to the NetworkManager profiles"
  sudo -v
  say "Encrypting profiles; enter a GPG passphrase when prompted"
  trap 'rm -f -- "$partial_destination"' EXIT
  if ! sudo -- "$SCRIPT_PATH" archive-stream |
    gpg --symmetric --cipher-algo AES256 --output "$partial_destination"; then
    fail "encrypted export failed"
  fi

  mv -- "$partial_destination" "$destination"
  trap - EXIT
  ok "exported encrypted profiles to $destination"
}

backup_profiles() {
  local destination="$1"
  local source="$CONNECTION_DIR"
  local profile
  local count=0

  [[ ! -e "$destination" ]] || fail "backup destination already exists: $destination"
  validate_profile_directory "$source"

  install -d -m 700 -- "$destination"
  while IFS= read -r -d '' profile; do
    install -o root -g root -m 600 -- "$profile" "$destination/$(basename -- "$profile")"
    ((count += 1))
  done < <(profile_files "$source")

  ok "backed up $count profile(s) to $destination"
}

resolve_restore_source() {
  local path="${1%/}"
  local nested="$path/etc/NetworkManager/system-connections"

  if [[ -d "$nested" ]]; then
    printf '%s\n' "$nested"
  else
    printf '%s\n' "$path"
  fi
}

restore_profiles() {
  local requested_source="$1"
  local source
  local safety_backup
  local profile
  local count=0
  local -a profiles=()

  source="$(resolve_restore_source "$requested_source")"
  validate_profile_directory "$source"

  mapfile -d '' -t profiles < <(profile_files "$source")
  [[ ${#profiles[@]} -gt 0 ]] || fail "no connection profiles found in: $source"

  require_command nmcli
  safety_backup="/root/networkmanager-backup-$(date +%Y%m%d-%H%M%S)"
  say "Saving the current profiles before restore"
  backup_profiles "$safety_backup"

  install -d -o root -g root -m 700 -- "$CONNECTION_DIR"
  for profile in "${profiles[@]}"; do
    install -o root -g root -m 600 -- \
      "$profile" "$CONNECTION_DIR/$(basename -- "$profile")"
    ((count += 1))
  done

  nmcli connection reload
  ok "restored $count profile(s); previous profiles are in $safety_backup"
  nmcli --colors no connection show
}

restore_archive() {
  local archive="$1"
  local status=0
  local temporary_directory

  require_unprivileged_user
  require_command gpg
  require_command mktemp
  require_command sudo
  require_command tar
  [[ -f "$archive" ]] || fail "encrypted archive does not exist: $archive"

  say "Authorizing access to restore the NetworkManager profiles"
  sudo -v
  temporary_directory="$(mktemp -d -t networkmanager-restore-XXXXXXXX)"
  chmod 700 -- "$temporary_directory"
  trap 'rm -rf -- "$temporary_directory"' EXIT

  say "Decrypting profiles; enter the GPG passphrase when prompted"
  if ! gpg --decrypt -- "$archive" |
    tar --extract --file=- --directory="$temporary_directory" \
      --no-same-owner --no-same-permissions; then
    fail "could not decrypt or unpack the archive"
  fi

  sudo -- "$SCRIPT_PATH" restore "$temporary_directory" || status=$?
  rm -rf -- "$temporary_directory"
  trap - EXIT
  return "$status"
}

main() {
  local command="${1:-help}"
  shift || true

  case "$command" in
  backup)
    [[ $# -le 1 ]] || fail "backup accepts at most one directory"
    become_root "$command" "$@"
    backup_profiles "${1:-/root/networkmanager-connections-$(date +%Y%m%d-%H%M%S)}"
    ;;
  export)
    [[ $# -eq 1 ]] || fail "export requires exactly one archive path"
    export_profiles "$1"
    ;;
  restore)
    [[ $# -eq 1 ]] || fail "restore requires exactly one source path"
    if [[ -f "$1" ]]; then
      restore_archive "$1"
    else
      become_root "$command" "$@"
      restore_profiles "$1"
    fi
    ;;
  archive-stream)
    [[ $# -eq 0 ]] || fail "archive-stream does not accept arguments"
    stream_profile_archive
    ;;
  list)
    [[ $# -eq 0 ]] || fail "list does not accept arguments"
    require_command nmcli
    nmcli --colors no connection show
    ;;
  help | --help | -h)
    usage
    ;;
  *)
    usage >&2
    fail "unknown command: $command"
    ;;
  esac
}

main "$@"

#!/usr/bin/env bash
# Download, verify, and write the latest 64-bit LMDE Cinnamon ISO to USB.
set -Eeuo pipefail
IFS=$'\n\t'

readonly MIRROR_URL="${LMDE_MIRROR_URL:-https://mirrors.kernel.org/linuxmint/debian}"
readonly DOWNLOAD_DIR="${LMDE_DOWNLOAD_DIR:-$HOME/Downloads/lmde}"
readonly MINT_ISO_SIGNING_FINGERPRINT="27DEB15644C6B3CF3BD7D291300F846BA25BAE09"
readonly MINT_ISO_SIGNING_KEY_URL="https://keys.openpgp.org/vks/v1/by-fingerprint/$MINT_ISO_SIGNING_FINGERPRINT"

ROOT_DISK=""
ISO_PATH=""
TARGET_DEVICE=""
TEMP_DIR=""
ISO_KEYRING=""
USB_DEVICES=()
USB_DESCRIPTIONS=()

say() {
  printf '\n%s\n' "$*"
}

ok() {
  printf 'OK: %s\n' "$*"
}

warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf -- "$TEMP_DIR"
  fi
}

trap cleanup EXIT

require_commands() {
  local command_name
  local -a missing_commands=()
  local -a required_commands=(
    awk
    blockdev
    cmp
    curl
    dd
    findmnt
    grep
    gpg
    lsblk
    mktemp
    readlink
    sed
    sha256sum
    sort
    stat
    sudo
    sync
    tail
    umount
    wget
  )

  for command_name in "${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      missing_commands+=("$command_name")
    fi
  done

  if [[ ${#missing_commands[@]} -gt 0 ]]; then
    printf 'Missing commands:\n' >&2
    printf '  %s\n' "${missing_commands[@]}" >&2
    fail "install the missing commands and run this script again"
  fi
}

verify_iso() {
  local checksum_file="$TEMP_DIR/sha256sum.txt"
  local signature_file="$TEMP_DIR/sha256sum.txt.gpg"
  local expected_checksum
  local actual_checksum
  local verification_status
  local signer_fingerprint

  if [[ -z "$ISO_KEYRING" || ! -f "$ISO_KEYRING" ]]; then
    warn "the temporary Linux Mint ISO keyring is unavailable"
    return 1
  fi

  if ! verification_status="$(
    gpg --batch --no-options --homedir "$TEMP_DIR/gnupg" \
      --no-default-keyring --keyring "$ISO_KEYRING" \
      --status-fd 1 \
      --verify "$signature_file" "$checksum_file" 2>/dev/null
  )"; then
    warn "the LMDE checksum signature could not be verified"
    return 1
  fi

  signer_fingerprint="$(awk '$2 == "VALIDSIG" { print $3; exit }' <<<"$verification_status")"

  case "$signer_fingerprint" in
    "$MINT_ISO_SIGNING_FINGERPRINT")
      ;;
    *)
      warn "the checksum file was not signed by a trusted Linux Mint key"
      return 1
      ;;
  esac

  expected_checksum="$(
    awk -v name="$(basename -- "$ISO_PATH")" \
      '$2 == "*" name || $2 == name { print $1; exit }' \
      "$checksum_file"
  )"

  if [[ -z "$expected_checksum" ]]; then
    warn "the checksum file does not contain $(basename -- "$ISO_PATH")"
    return 1
  fi

  actual_checksum="$(sha256sum --binary -- "$ISO_PATH" | awk '{ print $1 }')"

  if [[ "$actual_checksum" != "$expected_checksum" ]]; then
    warn "SHA-256 verification failed for $ISO_PATH"
    return 1
  fi
}

prepare_iso_signing_key() {
  local key_file="$TEMP_DIR/linuxmint-iso-signing-key.asc"
  local downloaded_fingerprint

  mkdir -m 700 -- "$TEMP_DIR/gnupg"

  say "Downloading the Linux Mint ISO signing key"
  curl --fail --location --show-error \
    --output "$key_file" \
    "$MINT_ISO_SIGNING_KEY_URL"

  downloaded_fingerprint="$(
    gpg --batch --no-options --homedir "$TEMP_DIR/gnupg" \
      --show-keys --with-colons "$key_file" 2>/dev/null |
      awk -F: '$1 == "fpr" { print $10; exit }'
  )"

  if [[ "$downloaded_fingerprint" != "$MINT_ISO_SIGNING_FINGERPRINT" ]]; then
    fail "the downloaded Linux Mint ISO signing key has an unexpected fingerprint"
  fi

  ISO_KEYRING="$TEMP_DIR/gnupg/linuxmint-iso-signing-key.gpg"
  gpg --batch --no-options --homedir "$TEMP_DIR/gnupg" \
    --no-default-keyring --keyring "$ISO_KEYRING" \
    --import-options import-minimal --import "$key_file" >/dev/null 2>&1
}

top_level_disk() {
  local device="$1"
  local resolved_device
  local parent_name

  resolved_device="$(readlink -f -- "$device")"

  while true; do
    parent_name="$(lsblk -ndo PKNAME "$resolved_device" 2>/dev/null || true)"

    if [[ -z "$parent_name" ]]; then
      break
    fi

    resolved_device="/dev/$parent_name"
  done

  printf '%s\n' "$resolved_device"
}

find_root_disk() {
  local root_source

  root_source="$(findmnt -nro SOURCE /)"

  if [[ "$root_source" != /dev/* ]]; then
    fail "could not identify the disk containing /"
  fi

  ROOT_DISK="$(top_level_disk "$root_source")"
}

find_latest_iso_name() {
  local checksum_file="$1"
  local iso_name

  iso_name="$(
    {
      awk '{ name = $2; sub(/^\*/, "", name); print name }' "$checksum_file" |
        grep -E '^lmde-[0-9]+-cinnamon-64bit\.iso$' |
        sort -V |
        tail -n 1
    } || true
  )"

  if [[ -z "$iso_name" ]]; then
    fail "no 64-bit LMDE Cinnamon ISO was found"
  fi

  printf '%s\n' "$iso_name"
}

download_and_verify_iso() {
  local iso_name

  TEMP_DIR="$(mktemp -d)"
  prepare_iso_signing_key

  say "Checking the current LMDE image"

  curl --fail --location --show-error \
    --output "$TEMP_DIR/sha256sum.txt" \
    "$MIRROR_URL/sha256sum.txt"

  curl --fail --location --show-error \
    --output "$TEMP_DIR/sha256sum.txt.gpg" \
    "$MIRROR_URL/sha256sum.txt.gpg"

  ISO_PATH="$DOWNLOAD_DIR/$(find_latest_iso_name "$TEMP_DIR/sha256sum.txt")"
  iso_name="$(basename -- "$ISO_PATH")"

  mkdir -p -- "$DOWNLOAD_DIR"

  say "Latest image: $iso_name"

  if [[ ! -f "$ISO_PATH" ]]; then
    say "Downloading $iso_name"
  else
    say "Checking the existing download before resuming"

    if verify_iso; then
      ok "existing ISO is valid"
      return
    fi

    warn "the existing ISO is incomplete or invalid; attempting to resume it"
  fi

  (
    cd -- "$DOWNLOAD_DIR"
    wget --continue "$MIRROR_URL/$iso_name"
  )

  say "Verifying ISO integrity and authenticity"

  if ! verify_iso; then
    fail "ISO verification failed; remove $ISO_PATH and run the script again"
  fi

  ok "ISO verification passed"
}

scan_usb_disks() {
  local device
  local transport
  local removable
  local size
  local model

  USB_DEVICES=()
  USB_DESCRIPTIONS=()

  while IFS= read -r device; do
    if [[ -z "$device" || "$device" == "$ROOT_DISK" ]]; then
      continue
    fi

    transport="$(lsblk -dnro TRAN "$device" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    removable="$(lsblk -dnro RM "$device" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

    if [[ "$transport" != "usb" && "$removable" != "1" ]]; then
      continue
    fi

    size="$(lsblk -dnro SIZE "$device" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    model="$(lsblk -dnro MODEL "$device" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

    USB_DEVICES+=("$device")
    USB_DESCRIPTIONS+=("$size  ${model:-unknown model}")
  done < <(lsblk -dnpo NAME,TYPE | awk '$2 == "disk" { print $1 }')
}

choose_usb_disk() {
  local answer
  local selected_index
  local index

  while true; do
    scan_usb_disks

    if [[ ${#USB_DEVICES[@]} -gt 0 ]]; then
      break
    fi

    say "No removable USB disk was detected."
    read -r -p "Insert the USB stick and press Enter, or type q to quit: " answer

    if [[ "$answer" == "q" || "$answer" == "Q" ]]; then
      exit 0
    fi
  done

  say "Detected removable disks"

  for index in "${!USB_DEVICES[@]}"; do
    printf '  %d) %-12s %s\n' \
      "$((index + 1))" \
      "${USB_DEVICES[$index]}" \
      "${USB_DESCRIPTIONS[$index]}"
  done

  while true; do
    read -r -p "Select the USB disk number: " answer

    if [[ ! "$answer" =~ ^[0-9]+$ ]]; then
      warn "enter a number from the list"
      continue
    fi

    selected_index=$((10#$answer - 1))

    if ((selected_index < 0 || selected_index >= ${#USB_DEVICES[@]})); then
      warn "enter a number from the list"
      continue
    fi

    TARGET_DEVICE="${USB_DEVICES[$selected_index]}"
    return
  done
}

assert_safe_target() {
  local target_type
  local current_root_disk
  local iso_source
  local iso_source_disk

  if [[ ! -b "$TARGET_DEVICE" ]]; then
    fail "$TARGET_DEVICE is no longer available"
  fi

  target_type="$(lsblk -dnro TYPE "$TARGET_DEVICE")"

  if [[ "$target_type" != "disk" ]]; then
    fail "$TARGET_DEVICE is not a whole disk"
  fi

  current_root_disk="$(top_level_disk "$(findmnt -nro SOURCE /)")"

  if [[ "$TARGET_DEVICE" == "$current_root_disk" ]]; then
    fail "refusing to overwrite the system disk"
  fi

  iso_source="$(findmnt -nro SOURCE --target "$ISO_PATH")"

  if [[ "$iso_source" == /dev/* ]]; then
    iso_source_disk="$(top_level_disk "$iso_source")"

    if [[ "$TARGET_DEVICE" == "$iso_source_disk" ]]; then
      fail "refusing to overwrite the disk containing the ISO"
    fi
  fi
}

confirm_target() {
  local confirmation

  say "Selected target"
  lsblk -o NAME,SIZE,TYPE,TRAN,RM,FSTYPE,LABEL,MODEL,SERIAL,MOUNTPOINTS \
    "$TARGET_DEVICE"

  printf '\nEVERYTHING ON %s WILL BE LOST.\n' "$TARGET_DEVICE"
  printf 'Disconnect backup drives before continuing.\n\n'

  read -r -p "Type ERASE $TARGET_DEVICE to continue: " confirmation

  if [[ "$confirmation" != "ERASE $TARGET_DEVICE" ]]; then
    fail "confirmation did not match; nothing was written"
  fi
}

unmount_target() {
  local node
  local index
  local -a nodes=()

  mapfile -t nodes < <(lsblk -nrpo NAME "$TARGET_DEVICE")

  for ((index = ${#nodes[@]} - 1; index >= 0; index--)); do
    node="${nodes[$index]}"

    while findmnt -rn -S "$node" >/dev/null 2>&1; do
      say "Unmounting $node"
      sudo umount -- "$node"
    done
  done
}

write_and_verify_usb() {
  local iso_size
  local target_size
  local selected_identity
  local current_identity

  sudo -v
  assert_safe_target

  iso_size="$(stat -c %s -- "$ISO_PATH")"
  target_size="$(sudo blockdev --getsize64 "$TARGET_DEVICE")"

  if ((target_size < iso_size)); then
    fail "$TARGET_DEVICE is smaller than the ISO"
  fi

  selected_identity="$(lsblk -dnro MAJ:MIN,SIZE,MODEL,SERIAL "$TARGET_DEVICE")"

  unmount_target
  assert_safe_target

  current_identity="$(lsblk -dnro MAJ:MIN,SIZE,MODEL,SERIAL "$TARGET_DEVICE")"

  if [[ "$current_identity" != "$selected_identity" ]]; then
    fail "the selected USB device changed before writing"
  fi

  say "Writing $ISO_PATH to $TARGET_DEVICE"

  sudo dd \
    if="$ISO_PATH" \
    of="$TARGET_DEVICE" \
    bs=4M \
    status=progress \
    conv=fsync

  sync
  unmount_target
  ok "ISO write completed"

  say "Comparing the USB contents with the ISO"

  if ! sudo cmp --silent --bytes="$iso_size" -- "$ISO_PATH" "$TARGET_DEVICE"; then
    fail "USB verification failed; do not boot from this USB"
  fi

  ok "USB contents match the ISO"
}

power_off_usb() {
  if command -v udisksctl >/dev/null 2>&1; then
    if udisksctl power-off --block-device "$TARGET_DEVICE"; then
      ok "USB device powered off safely"
      return
    fi
  fi

  warn "eject the USB through the desktop before removing it"
}

main() {
  if [[ ! -t 0 || ! -t 1 ]]; then
    fail "run this script from an interactive terminal"
  fi

  if [[ $EUID -eq 0 ]]; then
    fail "run this script as your normal user, not with sudo"
  fi

  require_commands
  find_root_disk

  say "LMDE USB writer"
  printf 'Mirror:       %s\n' "$MIRROR_URL"
  printf 'Download dir: %s\n' "$DOWNLOAD_DIR"
  printf 'System disk:  %s (protected)\n' "$ROOT_DISK"

  download_and_verify_iso
  choose_usb_disk
  assert_safe_target
  confirm_target
  write_and_verify_usb
  power_off_usb

  say "The LMDE installer USB is ready."
}

main "$@"

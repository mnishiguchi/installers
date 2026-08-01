#!/usr/bin/env bash
# Back up portable Chrome and Brave settings without copying complete profiles.
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

include_extension_settings=false
backup_root=""
copied_items=0
found_browser=false

usage() {
  cat <<'EOF'
Usage: browser-settings-backup.sh [options] [destination]

Back up settings and bookmarks from Google Chrome and Brave profiles. The
destination must not already exist.

Options:
  --include-extension-settings  Also copy extension code and settings.
  -h, --help                    Show this help.

If destination is omitted, a timestamped directory is created under
~/browser-settings-backup.
EOF
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --include-extension-settings)
        include_extension_settings=true
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      --*)
        fail "unknown option: $1"
        ;;
      *)
        [[ -z "$backup_root" ]] || fail "only one destination may be specified"
        backup_root="$1"
        shift
        ;;
    esac
  done

  if [[ -z "$backup_root" ]]; then
    backup_root="$HOME/browser-settings-backup/$(date +%Y%m%d-%H%M%S)"
  fi
}

browser_is_running() {
  local process_name
  local -a process_names=(chrome google-chrome brave brave-browser)

  for process_name in "${process_names[@]}"; do
    pgrep -x "$process_name" >/dev/null && return 0
  done
  return 1
}

copy_setting_file() {
  local source_file="$1"
  local destination_file="$2"

  [[ -f "$source_file" ]] || return 0
  install -m 600 -- "$source_file" "$destination_file"
  ((copied_items += 1))
}

copy_extension_directory() {
  local source_directory="$1"
  local destination_directory="$2"

  [[ -d "$source_directory" ]] || return 0
  if [[ -L "$source_directory" ]]; then
    printf 'Skipping symlinked extension directory: %s\n' "$source_directory" >&2
    return
  fi

  cp -a -- "$source_directory" "$destination_directory"
  chmod -R u+rwX,go-rwx -- "$destination_directory"
  ((copied_items += 1))
}

backup_browser_settings() {
  local browser_name="$1"
  local source_root="$2"
  local destination_root="$backup_root/$browser_name"
  local profile_directory
  local profile_name
  local profile_destination
  local item
  local -a extension_directories=(
    Extensions
    'Local Extension Settings'
    'Sync Extension Settings'
    'Extension State'
  )

  if [[ ! -d "$source_root" ]]; then
    printf 'Skipping missing browser directory: %s\n' "$source_root"
    return
  fi

  found_browser=true
  mkdir -p -- "$destination_root"
  chmod 700 -- "$destination_root"
  copy_setting_file "$source_root/Local State" "$destination_root/Local State"

  while IFS= read -r -d '' profile_directory; do
    profile_name="${profile_directory##*/}"
    profile_destination="$destination_root/$profile_name"
    mkdir -p -- "$profile_destination"
    chmod 700 -- "$profile_destination"

    for item in Preferences 'Secure Preferences' Bookmarks Bookmarks.bak; do
      copy_setting_file "$profile_directory/$item" "$profile_destination/$item"
    done

    if [[ "$include_extension_settings" == true ]]; then
      for item in "${extension_directories[@]}"; do
        copy_extension_directory \
          "$profile_directory/$item" \
          "$profile_destination/$item"
      done
    fi
  done < <(
    find -H "$source_root" -xdev -maxdepth 1 -type d \
      \( -name Default -o -name 'Profile *' \) -print0
  )
}

main() {
  local config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  local chrome_root="$config_home/google-chrome"
  local brave_root="$config_home/BraveSoftware/Brave-Browser"

  parse_args "$@"
  command -v pgrep >/dev/null 2>&1 || fail "pgrep is required"
  browser_is_running && fail "close Google Chrome and Brave before creating the backup"
  [[ ! -e "$backup_root" && ! -L "$backup_root" ]] \
    || fail "destination already exists: $backup_root"

  if [[ ! -d "$chrome_root" && ! -d "$brave_root" ]]; then
    fail "no Chrome or Brave browser data found under $config_home"
  fi

  mkdir -p -- "$backup_root"
  chmod 700 -- "$backup_root"
  backup_browser_settings google-chrome "$chrome_root"
  backup_browser_settings brave "$brave_root"

  [[ "$found_browser" == true && $copied_items -gt 0 ]] \
    || fail "no matching browser settings found; empty backup left at $backup_root"

  printf 'Browser settings backup created: %s\n' "$backup_root"
  printf 'Copied settings items: %d\n' "$copied_items"
}

main "$@"

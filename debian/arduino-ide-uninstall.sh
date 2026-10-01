#!/bin/sh
#
# Uninstall Arduino IDE installations created by arduino-ide-install.sh.
#
set -eu

readonly MANAGED_MARKER=".installed-by-mnishiguchi-installers"

dry_run=false
purge_settings=false
purge_packages=false
purge_sketchbook=false

usage() {
  cat <<'USAGE'
Usage: arduino-ide-uninstall.sh [OPTIONS]

Remove Arduino IDE installations and launchers created by the companion
installer. User data is kept unless an explicit purge option is supplied.

Options:
  --dry-run           Print what would be removed without changing anything
  --purge-settings    Remove IDE settings and caches
  --purge-packages    Remove downloaded board packages and tools (~/.arduino15)
  --purge-sketchbook  Remove sketches (~/Arduino)
  -h, --help          Show this help

Environment:
  ARDUINO_IDE_INSTALL_ROOT  Installation root (default: ~/.local/opt)
  ARDUINO_IDE_BIN_DIR       Command directory (default: ~/.local/bin)
  XDG_DATA_HOME             XDG data directory (default: ~/.local/share)
  XDG_CONFIG_HOME           XDG config directory (default: ~/.config)
  XDG_CACHE_HOME            XDG cache directory (default: ~/.cache)
USAGE
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'Warning: %s\n' "$*" >&2
}

require_absolute_path() {
  case "$2" in
    /*) ;;
    *) die "$1 must be an absolute path: $2" ;;
  esac
}

remove_path() {
  path=$1

  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    return
  fi

  if [ "$dry_run" = true ]; then
    printf 'Would remove: %s\n' "$path"
  else
    rm -rf -- "$path"
    printf 'Removed: %s\n' "$path"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run=true
      ;;
    --purge-settings)
      purge_settings=true
      ;;
    --purge-packages)
      purge_packages=true
      ;;
    --purge-sketchbook)
      purge_sketchbook=true
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
  shift
done

[ "$(id -u)" -ne 0 ] ||
  die "do not run this per-user uninstaller as root or with sudo"

: "${HOME:?HOME must be set}"

data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
install_root=${ARDUINO_IDE_INSTALL_ROOT:-"$HOME/.local/opt"}
bin_dir=${ARDUINO_IDE_BIN_DIR:-"$HOME/.local/bin"}
config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
cache_home=${XDG_CACHE_HOME:-"$HOME/.cache"}

require_absolute_path ARDUINO_IDE_INSTALL_ROOT "$install_root"
require_absolute_path ARDUINO_IDE_BIN_DIR "$bin_dir"
require_absolute_path XDG_DATA_HOME "$data_home"
require_absolute_path XDG_CONFIG_HOME "$config_home"
require_absolute_path XDG_CACHE_HOME "$cache_home"

stable_link="$install_root/arduino-ide"
command_link="$bin_dir/arduino-ide"
desktop_file="$data_home/applications/arduino-ide.desktop"
icon_file="$data_home/icons/hicolor/512x512/apps/arduino-ide.png"

printf '%s\n' \
  "Install root: $install_root" \
  "Stable link: $stable_link" \
  "Command link: $command_link" \
  "App launcher: $desktop_file" \
  "App icon: $icon_file"

# A marked desktop file or install directory proves that the integration links
# belong to this installer. Without that evidence, leave unmarked/user paths
# untouched and tell the user what was skipped.
managed_integration=false

if [ -f "$desktop_file" ] && [ ! -L "$desktop_file" ]; then
  if grep -Fqx 'X-Mnishiguchi-Installer=arduino-ide' "$desktop_file"; then
    managed_integration=true
  fi
fi

if [ -L "$stable_link" ]; then
  stable_target=$(readlink "$stable_link")
  case "$stable_target" in
    "$install_root"/arduino-ide-*)
      if [ -f "$stable_target/$MANAGED_MARKER" ]; then
        managed_integration=true
      fi
      ;;
    *) ;;
  esac
fi

if [ "$managed_integration" = true ]; then
  if [ -L "$command_link" ]; then
    command_target=$(readlink "$command_link")
    if [ "$command_target" = "$stable_link/arduino-ide" ]; then
      remove_path "$command_link"
    else
      warn "leaving command link with an unexpected target: $command_link"
    fi
  elif [ -e "$command_link" ]; then
    warn "leaving non-symlink command path: $command_link"
  fi

  if [ -f "$desktop_file" ] && [ ! -L "$desktop_file" ]; then
    if grep -Fqx 'X-Mnishiguchi-Installer=arduino-ide' "$desktop_file"; then
      remove_path "$desktop_file"
    else
      warn "leaving launcher not created by this installer: $desktop_file"
    fi
  elif [ -e "$desktop_file" ] || [ -L "$desktop_file" ]; then
    warn "leaving non-regular launcher: $desktop_file"
  fi

  if [ -f "$icon_file" ] && [ ! -L "$icon_file" ]; then
    remove_path "$icon_file"
  elif [ -e "$icon_file" ] || [ -L "$icon_file" ]; then
    warn "leaving non-regular icon: $icon_file"
  fi

  if [ -L "$stable_link" ]; then
    stable_target=$(readlink "$stable_link")
    case "$stable_target" in
      "$install_root"/arduino-ide-*) remove_path "$stable_link" ;;
      *) warn "leaving stable link with an unexpected target: $stable_link" ;;
    esac
  elif [ -e "$stable_link" ]; then
    warn "leaving non-symlink install path: $stable_link"
  fi
else
  if [ -e "$command_link" ] || [ -L "$command_link" ]; then
    warn "leaving unmarked command path: $command_link"
  fi
  if [ -e "$desktop_file" ] || [ -L "$desktop_file" ]; then
    warn "leaving launcher not created by this installer: $desktop_file"
  fi
  if [ -e "$icon_file" ] || [ -L "$icon_file" ]; then
    warn "leaving unmarked icon: $icon_file"
  fi
  if [ -e "$stable_link" ] || [ -L "$stable_link" ]; then
    warn "leaving unmarked stable path: $stable_link"
  fi
fi

# Globbing is intentionally constrained to direct children of install_root,
# and each directory must carry the installer's ownership marker.
for install_dir in "$install_root"/arduino-ide-*; do
  [ -d "$install_dir" ] || continue
  [ ! -L "$install_dir" ] || continue

  if [ -f "$install_dir/$MANAGED_MARKER" ]; then
    remove_path "$install_dir"
  else
    warn "leaving unmarked installation directory: $install_dir"
  fi
done

if [ "$purge_settings" = true ]; then
  remove_path "$HOME/.arduinoIDE"
  remove_path "$config_home/arduino-ide"
  remove_path "$config_home/Arduino IDE"
  remove_path "$cache_home/arduino-ide"
  remove_path "$cache_home/arduino"
fi

if [ "$purge_packages" = true ]; then
  remove_path "$HOME/.arduino15"
fi

if [ "$purge_sketchbook" = true ]; then
  remove_path "$HOME/Arduino"
fi

if [ "$managed_integration" = true ] && [ "$dry_run" = false ] &&
  command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${desktop_file%/*}" ||
    warn "could not refresh the desktop MIME cache"
fi

if [ "$dry_run" = true ]; then
  printf '\nDry run complete; nothing was removed.\n'
else
  printf '\nArduino IDE uninstalled.\n'
fi

[ "$purge_settings" = true ] ||
  printf 'Settings and caches were kept (use --purge-settings to remove them).\n'
[ "$purge_packages" = true ] ||
  printf 'Board packages were kept (use --purge-packages to remove them).\n'
[ "$purge_sketchbook" = true ] ||
  printf 'Sketches were kept (use --purge-sketchbook to remove them).\n'

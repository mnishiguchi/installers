#!/usr/bin/env bash
#
# Uninstall Android Studio on LMDE7 (Debian-based)
# - Removes /opt/android-studio
# - Removes /usr/local/bin/android-studio launcher
# - Removes /usr/share/applications/android-studio.desktop
# - Optional: purge user settings and SDK under ~/Android
#
set -euo pipefail

INSTALL_DIR="/opt/android-studio"
LAUNCHER_SCRIPT="/usr/local/bin/android-studio"
DESKTOP_FILE="/usr/share/applications/android-studio.desktop"
SDK_DIR="${HOME}/Android"

PURGE_SETTINGS=0
PURGE_SDK=0

SUDO=""

echo_heading() { echo -e "\n\033[34m$1\033[0m"; }
echo_success() { echo -e " \033[32m✔ $1\033[0m"; }
echo_warn() { echo -e " \033[33m▲ $1\033[0m"; }
echo_failure() { echo -e " \033[31m✖ $1\033[0m"; }

require_sudo() {
  if [ "${EUID}" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      SUDO="sudo"
    else
      echo_failure "This script needs root privileges (sudo or run as root)."
      exit 1
    fi
  else
    SUDO=""
  fi
}

print_help() {
  cat <<EOF
Usage: $0 [--purge-settings] [--purge-sdk] [-h|--help]

  --purge-settings   Remove user settings/cache:
                     ~/.config/Google/AndroidStudio*
                     ~/.cache/Google/AndroidStudio*
                     ~/.android

  --purge-sdk        Remove Android SDK and related under:
                     \$HOME/Android

  -h, --help         Show this help and exit.
EOF
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
    --purge-settings)
      PURGE_SETTINGS=1
      ;;
    --purge-sdk)
      PURGE_SDK=1
      ;;
    -h | --help)
      print_help
      exit 0
      ;;
    *)
      echo_warn "Unknown option: $1"
      ;;
    esac
    shift
  done
}

remove_install_dir() {
  echo_heading "Removing Android Studio installation..."

  if [ -d "$INSTALL_DIR" ]; then
    $SUDO rm -rf "$INSTALL_DIR"
    echo_success "Removed directory: $INSTALL_DIR"
  else
    echo_success "No directory at: $INSTALL_DIR"
  fi
}

remove_launcher_and_desktop() {
  echo_heading "Removing launcher and desktop entry..."

  if [ -e "$LAUNCHER_SCRIPT" ]; then
    $SUDO rm -f "$LAUNCHER_SCRIPT"
    echo_success "Removed launcher: $LAUNCHER_SCRIPT"
  else
    echo_success "No launcher at: $LAUNCHER_SCRIPT"
  fi

  if [ -e "$DESKTOP_FILE" ]; then
    $SUDO rm -f "$DESKTOP_FILE"
    echo_success "Removed desktop file: $DESKTOP_FILE"
  else
    echo_success "No desktop file at: $DESKTOP_FILE"
  fi
}

purge_user_settings() {
  echo_heading "User settings and cache cleanup..."

  if [ "$PURGE_SETTINGS" -ne 1 ]; then
    echo_warn "Skipping user settings removal. Pass --purge-settings to delete:"
    echo "  ~/.config/Google/AndroidStudio*"
    echo "  ~/.cache/Google/AndroidStudio*"
    echo "  ~/.android"
    return
  fi

  local paths_removed=0
  local path

  for path in \
    "${HOME}/.config/Google/AndroidStudio"* \
    "${HOME}/.cache/Google/AndroidStudio"* \
    "${HOME}/.android"; do
    if [ -e "$path" ]; then
      rm -rf "$path"
      echo_success "Removed: $path"
      paths_removed=1
    fi
  done

  if [ "$paths_removed" -eq 0 ]; then
    echo_success "No Android Studio settings/cache paths found under \$HOME."
  fi
}

purge_sdk_dir() {
  echo_heading "SDK directory cleanup..."

  if [ "$PURGE_SDK" -ne 1 ]; then
    echo_warn "Skipping SDK removal. Pass --purge-sdk to delete:"
    echo "  $SDK_DIR"
    return
  fi

  if [ -d "$SDK_DIR" ]; then
    rm -rf "$SDK_DIR"
    echo_success "Removed SDK directory: $SDK_DIR"
  else
    echo_success "No SDK directory at: $SDK_DIR"
  fi
}

summary() {
  echo_heading "Uninstall summary"
  echo "  Android Studio dir removed:    $INSTALL_DIR"
  echo "  Launcher removed:             $LAUNCHER_SCRIPT"
  echo "  Desktop entry removed:        $DESKTOP_FILE"
  echo "  Purged settings/cache:        $([ "$PURGE_SETTINGS" -eq 1 ] && echo yes || echo no)"
  echo "  Purged SDK directory:         $([ "$PURGE_SDK" -eq 1 ] && echo yes || echo no)"
}

main() {
  require_sudo
  parse_args "$@"

  remove_install_dir
  remove_launcher_and_desktop
  purge_user_settings
  purge_sdk_dir
  summary
}

main "$@"

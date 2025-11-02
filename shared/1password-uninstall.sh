#!/usr/bin/env bash
#
# Uninstall 1Password on LMDE7 (Debian-based)
# - Removes package (use --purge for full system purge)
# - Removes apt repo, keyring, and debsig policy
# - Optional: --purge-user-data to delete ~/.config/1Password etc.
#
# Usage:
#   ./1password-uninstall.sh [--purge] [--purge-user-data] [--keep-repo]
#
set -euo pipefail

PKG="1password"
REPO_LIST="/etc/apt/sources.list.d/1password.list"
KEYRING="/usr/share/keyrings/1password-archive-keyring.gpg"
DEBSIG_DIR="/etc/debsig/policies/AC2D62742012EA22"
DEBSIG_KEYRING="/usr/share/debsig/keyrings/AC2D62742012EA22"

PURGE_SYSTEM=0
PURGE_USER_DATA=0
KEEP_REPO=0

echo_heading() { echo -e "\n\033[34m$1\033[0m"; }
echo_success() { echo -e  " \033[32m✔ $1\033[0m"; }
echo_warn()    { echo -e  " \033[33m▲ $1\033[0m"; }
echo_failure() { echo -e  " \033[31m✖ $1\033[0m"; }

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

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --purge) PURGE_SYSTEM=1 ;;
      --purge-user-data) PURGE_USER_DATA=1 ;;
      --keep-repo) KEEP_REPO=1 ;;
      -h|--help)
        echo "Usage: $0 [--purge] [--purge-user-data] [--keep-repo]"
        exit 0
        ;;
      *)
        echo_warn "Unknown option: $1"
        ;;
    esac
    shift
  done
}

pkg_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

remove_package() {
  echo_heading "Removing 1Password package..."
  if pkg_installed "$PKG"; then
    if [ "$PURGE_SYSTEM" -eq 1 ]; then
      $SUDO apt-get remove --purge -y "$PKG"
      echo_success "Purged package: $PKG"
    else
      $SUDO apt-get remove -y "$PKG"
      echo_success "Removed package: $PKG"
    fi
    $SUDO apt-get autoremove -y >/dev/null || true
  } else {
    echo_success "Package not installed: $PKG"
  fi
}

remove_repo_and_keys() {
  if [ "$KEEP_REPO" -eq 1 ]; then
    echo_heading "Keeping apt repo and keys (per --keep-repo)."
    return
  fi

  echo_heading "Removing apt repo, keyring, and debsig policy..."
  if [ -f "$REPO_LIST" ]; then
    $SUDO rm -f "$REPO_LIST"
    echo_success "Removed repo list: $REPO_LIST"
  else
    echo_success "Repo list not found: $REPO_LIST"
  fi

  if [ -f "$KEYRING" ]; then
    $SUDO rm -f "$KEYRING"
    echo_success "Removed keyring: $KEYRING"
  else
    echo_success "Keyring not found: $KEYRING"
  fi

  # Remove debsig policy + keyring (ignore if already gone)
  if [ -d "$DEBSIG_DIR" ]; then
    $SUDO rm -rf "$DEBSIG_DIR"
    echo_success "Removed debsig policy dir: $DEBSIG_DIR"
  else
    echo_success "Debsig policy dir not found: $DEBSIG_DIR"
  fi

  if [ -d "$DEBSIG_KEYRING" ]; then
    $SUDO rm -rf "$DEBSIG_KEYRING"
    echo_success "Removed debsig keyring dir: $DEBSIG_KEYRING"
  else
    echo_success "Debsig keyring dir not found: $DEBSIG_KEYRING"
  fi

  $SUDO apt-get update -yqq || true
}

purge_user_data() {
  echo_heading "User data cleanup..."
  if [ "$PURGE_USER_DATA" -ne 1 ]; then
    echo_warn "Skipping user data removal. Pass --purge-user-data to delete:"
    echo "  ~/.config/1Password  ~/.cache/1Password  ~/.local/share/1Password"
    return
  fi

  # Remove common 1Password user data locations (current user only)
  local removed_any=0
  for p in \
    "${HOME}/.config/1Password" \
    "${HOME}/.cache/1Password" \
    "${HOME}/.local/share/1Password"
  do
    if [ -e "$p" ]; then
      rm -rf "$p"
      echo_success "Removed: $p"
      removed_any=1
    fi
  done

  if [ "$removed_any" -eq 0 ]; then
    echo_success "No 1Password user data directories found under \$HOME."
  fi
}

summary() {
  echo_heading "Summary"
  echo "  Package removed:        ${PKG}"
  echo "  System purge:           $([ $PURGE_SYSTEM -eq 1 ] && echo yes || echo no)"
  echo "  Purged user data:       $([ $PURGE_USER_DATA -eq 1 ] && echo yes || echo no)"
  echo "  Kept apt repo & keys:   $([ $KEEP_REPO -eq 1 ] && echo yes || echo no)"
  echo_heading "Uninstall complete."
}

main() {
  require_sudo
  parse_args "$@"
  remove_package
  remove_repo_and_keys
  purge_user_data
  summary
}

main "$@"

#!/usr/bin/env bash
#
# Install or update 1Password on LMDE7 (Debian-based)
# - Configures the official apt repo, signing key, and debsig policy
# - Installs or updates the package through apt
# - Idempotent: safe to re-run
#
set -euo pipefail

REPO_LIST="/etc/apt/sources.list.d/1password.list"
KEY_URL="https://downloads.1password.com/linux/keys/1password.asc"
KEY_FINGERPRINT="3FEF9748469ADBE15DA7CA80AC2D62742012EA22"
KEYRING="/usr/share/keyrings/1password-archive-keyring.gpg"
DEBSIG_DIR="/etc/debsig/policies/AC2D62742012EA22"
DEBSIG_KEYRING="/usr/share/debsig/keyrings/AC2D62742012EA22"
PKG="1password"
TEMP_KEY=""

echo_heading() { echo -e "\n\033[34m$1\033[0m"; }
echo_success() { echo -e " \033[32m✔ $1\033[0m"; }
echo_warn() { echo -e " \033[33m▲ $1\033[0m"; }
echo_failure() { echo -e " \033[31m✖ $1\033[0m"; }

cleanup() {
  if [ -n "$TEMP_KEY" ]; then
    rm -f -- "$TEMP_KEY"
  fi
}

trap cleanup EXIT

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

pkg_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

repo_is_configured() {
  [ -f "$REPO_LIST" ] && grep -q "downloads.1password.com" "$REPO_LIST"
}

ensure_prereqs() {
  if [ "$(dpkg --print-architecture)" != "amd64" ]; then
    echo_failure "This installer currently supports amd64 only."
    exit 1
  fi

  echo_heading "Preparing prerequisites..."
  $SUDO apt-get update -yqq
  $SUDO apt-get install -y curl gnupg ca-certificates >/dev/null
  echo_success "Prerequisites installed."
}

ensure_repo_and_policy() {
  local downloaded_fingerprint

  echo_heading "Configuring apt repo and debsig policy..."
  TEMP_KEY="$(mktemp -t 1password-key-XXXXXX.asc)"
  curl -fsSL "$KEY_URL" -o "$TEMP_KEY"
  downloaded_fingerprint="$(
    gpg --batch --show-keys --with-colons "$TEMP_KEY" 2>/dev/null |
      awk -F: '$1 == "fpr" { print $10; exit }'
  )"

  if [ "$downloaded_fingerprint" != "$KEY_FINGERPRINT" ]; then
    echo_failure "The downloaded 1Password signing key has an unexpected fingerprint."
    exit 1
  fi

  $SUDO gpg --batch --yes --dearmor --output "$KEYRING" "$TEMP_KEY"
  echo "deb [arch=amd64 signed-by=$KEYRING] https://downloads.1password.com/linux/debian/amd64 stable main" |
    $SUDO tee "$REPO_LIST" >/dev/null

  $SUDO mkdir -p "$DEBSIG_DIR" "$DEBSIG_KEYRING"
  curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol |
    $SUDO tee "$DEBSIG_DIR/1password.pol" >/dev/null
  $SUDO gpg --batch --yes --dearmor --output "$DEBSIG_KEYRING/debsig.gpg" "$TEMP_KEY"

  $SUDO apt-get update -yqq
  echo_success "Repo and signature policy configured."
}

post_checks() {
  echo_heading "Verifying installation and repo..."
  if pkg_installed "$PKG"; then
    echo_success "Package present: $PKG"
  else
    echo_failure "Package not detected after install."
    exit 1
  fi

  if repo_is_configured; then
    echo_success "Apt repo configured for automatic updates."
  else
    echo_failure "Apt repo was not configured."
    exit 1
  fi
}

install_or_update() {
  echo_heading "Installing or updating 1Password..."
  $SUDO apt-get install -y "$PKG"
  echo_success "Installed the latest available $PKG package."
}

main() {
  require_sudo
  ensure_prereqs
  ensure_repo_and_policy
  install_or_update
  post_checks

  echo_heading "Done."
  echo "Launch from your menu or run: 1password"
}

main "$@"

#!/usr/bin/env bash
#
# Install or update 1Password on LMDE7 (Debian-based)
# - Installs from the official .deb (resolves deps via apt)
# - Ensures the apt repo + signing key are configured for updates
# - Idempotent: safe to re-run
#
set -euo pipefail

DEB_URL="https://downloads.1password.com/linux/debian/amd64/stable/1password-latest.deb"
REPO_LIST="/etc/apt/sources.list.d/1password.list"
KEY_URL="https://downloads.1password.com/linux/keys/1password.asc"
KEYRING="/usr/share/keyrings/1password-archive-keyring.gpg"
DEBSIG_DIR="/etc/debsig/policies/AC2D62742012EA22"
DEBSIG_KEYRING="/usr/share/debsig/keyrings/AC2D62742012EA22"
PKG="1password"

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

pkg_installed() {
  dpkg -s "$1" >/dev/null 2>&1
}

repo_is_configured() {
  [ -f "$REPO_LIST" ] && grep -q "downloads.1password.com" "$REPO_LIST"
}

ensure_prereqs() {
  echo_heading "Preparing prerequisites..."
  $SUDO apt-get update -yqq
  $SUDO apt-get install -y curl gnupg ca-certificates >/dev/null
  echo_success "Prerequisites installed."
}

install_from_deb() {
  echo_heading "Downloading official .deb..."
  local deb
  deb="$(mktemp -t 1password-XXXXXX.deb)"
  curl -fsSL "$DEB_URL" -o "$deb"
  echo_success "Downloaded to: $deb"

  echo_heading "Installing 1Password (.deb via apt for deps)..."
  $SUDO apt-get install -y "$deb"
  echo_success "1Password installed via .deb"
}

ensure_repo_manually() {
  # Only used if the automatic repo setup didn't happen for some reason
  echo_heading "Ensuring apt repo + debsig policy (manual fallback)..."
  curl -fsSL "$KEY_URL" | $SUDO gpg --dearmor --output "$KEYRING"
  echo "deb [arch=amd64 signed-by=$KEYRING] https://downloads.1password.com/linux/debian/amd64 stable main" |
    $SUDO tee "$REPO_LIST" >/dev/null

  $SUDO mkdir -p "$DEBSIG_DIR" "$DEBSIG_KEYRING"
  curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol |
    $SUDO tee "$DEBSIG_DIR/1password.pol" >/dev/null
  curl -fsSL "$KEY_URL" | $SUDO gpg --dearmor --output "$DEBSIG_KEYRING/debsig.gpg"

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
    echo_warn "Apt repo not found; applying manual fallback."
    ensure_repo_manually
  fi
}

update_if_present() {
  echo_heading "Updating existing installation..."
  $SUDO apt-get update -yqq
  $SUDO apt-get install -y "$PKG"
  echo_success "Updated $PKG to latest."
}

main() {
  require_sudo
  ensure_prereqs

  if pkg_installed "$PKG"; then
    update_if_present
  else
    install_from_deb
    post_checks
  fi

  echo_heading "Done."
  echo "Launch from your menu or run: 1password"
}

main "$@"

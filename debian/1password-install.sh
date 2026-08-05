#!/usr/bin/env bash
#
# Install or update 1Password on LMDE7 (Debian-based)
# - Configures the official apt repo, signing key, and debsig policy
# - Installs or updates the package through apt
# - Idempotent: safe to re-run
#
set -euo pipefail

REPO_LIST="/etc/apt/sources.list.d/1password.list"
REPO_ENTRY="deb [arch=amd64 signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/amd64 stable main"
KEY_URL="https://downloads.1password.com/linux/keys/1password.asc"
KEY_FINGERPRINT="3FEF9748469ADBE15DA7CA80AC2D62742012EA22"
KEYRING="/usr/share/keyrings/1password-archive-keyring.gpg"
DEBSIG_DIR="/etc/debsig/policies/AC2D62742012EA22"
DEBSIG_KEYRING="/usr/share/debsig/keyrings/AC2D62742012EA22"
DEBSIG_POLICY="$DEBSIG_DIR/1password.pol"
DEBSIG_KEY="$DEBSIG_KEYRING/debsig.gpg"
PTRACE_SCOPE="/proc/sys/kernel/yama/ptrace_scope"
YAMA_SYSCTL_CONFIG="/etc/sysctl.d/99-yama.conf"
YAMA_SYSCTL_SETTING="kernel.yama.ptrace_scope = 1"
PKG="1password"
TEMP_KEY=""
CHECK=false

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

usage() {
  cat <<EOF
Usage: $0 [--check]

Install or update 1Password, or check that its complete managed state is present.

Options:
  --check  Verify state without changing the system. Exits 1 when drift is found.
  -h, --help
           Show this help.
EOF
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --check) CHECK=true ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo_failure "Unknown option: $1"
        usage >&2
        exit 2
        ;;
    esac
    shift
  done
}

pkg_installed() {
  dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null | grep -q '^ii '
}

repo_is_configured() {
  [ -f "$REPO_LIST" ] && grep -Fxq "$REPO_ENTRY" "$REPO_LIST"
}

sysctl_setting_is_persistent() {
  [ -f "$YAMA_SYSCTL_CONFIG" ] &&
    grep -Eq '^[[:space:]]*kernel\.yama\.ptrace_scope[[:space:]]*=[[:space:]]*1[[:space:]]*(#.*)?$' "$YAMA_SYSCTL_CONFIG"
}

check_state() {
  local current_ptrace_scope=""
  local state=0

  echo_heading "Checking 1Password configuration..."

  if pkg_installed "$PKG"; then
    echo_success "Package present: $PKG"
  else
    echo_failure "Package is not installed: $PKG"
    state=1
  fi

  if repo_is_configured; then
    echo_success "Official stable apt repository is configured."
  else
    echo_failure "Expected stable apt repository entry is missing from $REPO_LIST."
    state=1
  fi

  if [ -f "$KEYRING" ]; then
    echo_success "APT signing keyring exists: $KEYRING"
  else
    echo_failure "APT signing keyring is missing: $KEYRING"
    state=1
  fi

  if [ -f "$DEBSIG_POLICY" ]; then
    echo_success "debsig policy exists: $DEBSIG_POLICY"
  else
    echo_failure "debsig policy is missing: $DEBSIG_POLICY"
    state=1
  fi

  if [ -f "$DEBSIG_KEY" ]; then
    echo_success "debsig keyring exists: $DEBSIG_KEY"
  else
    echo_failure "debsig keyring is missing: $DEBSIG_KEY"
    state=1
  fi

  if [ ! -e "$PTRACE_SCOPE" ]; then
    echo_failure "$PTRACE_SCOPE does not exist. Yama ptrace support is unavailable; load or enable Yama before using 1Password file operations."
    state=1
  else
    current_ptrace_scope="$(<"$PTRACE_SCOPE")"
    if [ "$current_ptrace_scope" = "1" ]; then
      echo_success "Yama ptrace_scope is 1."
    else
      echo_failure "Yama ptrace_scope is $current_ptrace_scope; expected 1 for 1Password file operations."
      state=1
    fi
  fi

  if sysctl_setting_is_persistent; then
    echo_success "Persistent Yama setting is configured: $YAMA_SYSCTL_CONFIG"
  else
    echo_failure "Persistent Yama setting is missing or incorrect: $YAMA_SYSCTL_CONFIG"
    state=1
  fi

  return "$state"
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
  echo "$REPO_ENTRY" |
    $SUDO tee "$REPO_LIST" >/dev/null

  $SUDO mkdir -p "$DEBSIG_DIR" "$DEBSIG_KEYRING"
  curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol |
    $SUDO tee "$DEBSIG_POLICY" >/dev/null
  $SUDO gpg --batch --yes --dearmor --output "$DEBSIG_KEY" "$TEMP_KEY"

  $SUDO apt-get update -yqq
  echo_success "Repo and signature policy configured."
}

ensure_yama_ptrace_scope() {
  echo_heading "Configuring Yama ptrace scope..."

  if [ ! -e "$PTRACE_SCOPE" ]; then
    echo_failure "$PTRACE_SCOPE does not exist. Yama ptrace support is unavailable; load or enable Yama before using 1Password file operations."
    exit 1
  fi

  echo "$YAMA_SYSCTL_SETTING" | $SUDO tee "$YAMA_SYSCTL_CONFIG" >/dev/null
  $SUDO sysctl -w kernel.yama.ptrace_scope=1 >/dev/null
  echo_success "Yama ptrace_scope set to 1 and persisted in $YAMA_SYSCTL_CONFIG."
}

install_or_update() {
  echo_heading "Installing or updating 1Password..."
  $SUDO apt-get install -y "$PKG"
  echo_success "Installed the latest available $PKG package."
}

main() {
  parse_args "$@"

  if [ "$CHECK" = true ]; then
    if check_state; then
      echo_success "1Password is installed and configured."
      return
    fi
    echo_failure "1Password configuration is incomplete. Run $0 to repair it."
    exit 1
  fi

  require_sudo
  ensure_prereqs
  ensure_repo_and_policy
  install_or_update
  ensure_yama_ptrace_scope

  if ! check_state; then
    echo_failure "1Password installation completed with incomplete configuration."
    exit 1
  fi

  echo_heading "Done."
  echo "Launch from your menu or run: 1password"
}

main "$@"

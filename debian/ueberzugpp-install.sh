#!/usr/bin/env bash
# Install or update ueberzugpp from its Open Build Service repository.
set -Eeuo pipefail
IFS=$'\n\t'

readonly PACKAGE="ueberzugpp"
readonly REPOSITORY_URL="https://download.opensuse.org/repositories/home:/justkidding/Debian_13/"
readonly KEY_URL="${REPOSITORY_URL}Release.key"
readonly KEY_FINGERPRINT="7627D0F8F60FBA35371A29E1AA6B2752759F9361"
readonly KEYRING="/usr/share/keyrings/ueberzugpp-archive-keyring.gpg"
readonly SOURCE_LIST="/etc/apt/sources.list.d/ueberzugpp.list"
readonly SOURCE_ENTRY="deb [arch=amd64 signed-by=${KEYRING}] ${REPOSITORY_URL} /"
readonly LEGACY_KEYRING="/etc/apt/trusted.gpg.d/home_justkidding.gpg"
readonly LEGACY_SOURCE_LIST="/etc/apt/sources.list.d/home:justkidding.list"

CHECK=false
TEMP_DIR=""

say() { printf '\n\033[34m%s\033[0m\n' "$*"; }
ok() { printf ' \033[32m✔ %s\033[0m\n' "$*"; }
warn() { printf ' \033[33m⚠ %s\033[0m\n' "$*" >&2; }
fail() {
  printf ' \033[31m✖ %s\033[0m\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$TEMP_DIR" ]]; then
    rm -rf -- "$TEMP_DIR"
  fi
}

trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage: ueberzugpp-install.sh [--check]

Install or update ueberzugpp on an amd64 Debian 13 or LMDE 7 system.

Options:
  --check     Verify the package, repository, and signing key without changing them.
  -h, --help  Show this help.
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      --check) CHECK=true ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        fail "unknown option: $1"
        ;;
    esac
    shift
  done
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

package_installed() {
  dpkg-query -W -f='${db:Status-Abbrev}' "$PACKAGE" 2>/dev/null | grep -q '^ii '
}

repo_configured() {
  [[ -f "$SOURCE_LIST" ]] && grep -Fxq "$SOURCE_ENTRY" "$SOURCE_LIST"
}

key_fingerprint() {
  gpg --batch --show-keys --with-colons "$1" 2>/dev/null |
    awk -F: '$1 == "fpr" { print $10; exit }'
}

check_state() {
  local actual_fingerprint=""
  local state=0

  say "Checking ueberzugpp"

  if package_installed; then
    ok "$PACKAGE is installed"
  else
    warn "$PACKAGE is not installed"
    state=1
  fi

  if repo_configured; then
    ok "APT source is configured with a repository-scoped signing key"
  else
    warn "expected APT source is missing from $SOURCE_LIST"
    state=1
  fi

  if [[ ! -f "$KEYRING" ]]; then
    warn "APT signing key is missing: $KEYRING"
    state=1
  elif ! command -v gpg >/dev/null 2>&1; then
    warn "gpg is unavailable; cannot verify $KEYRING"
    state=1
  else
    actual_fingerprint="$(key_fingerprint "$KEYRING")"
    if [[ "$actual_fingerprint" == "$KEY_FINGERPRINT" ]]; then
      ok "APT signing key fingerprint is verified"
    else
      warn "APT signing key has an unexpected fingerprint: ${actual_fingerprint:-unknown}"
      state=1
    fi
  fi

  if [[ -e "$LEGACY_SOURCE_LIST" || -e "$LEGACY_KEYRING" ]]; then
    warn "legacy globally trusted repository configuration is still present"
    state=1
  fi

  return "$state"
}

validate_host() {
  local architecture

  [[ $EUID -ne 0 ]] || fail "run this script as your normal user, not with sudo"
  require_command apt-get
  require_command dpkg
  require_command dpkg-query
  require_command sudo
  [[ -r /etc/os-release ]] || fail "/etc/os-release is required"

  # shellcheck source=/dev/null
  source /etc/os-release
  if [[ "${ID:-}" != "debian" && " ${ID_LIKE:-} " != *" debian "* ]]; then
    fail "this installer supports Debian-based systems only"
  fi
  if [[ "${VERSION_CODENAME:-}" != "trixie" && "${DEBIAN_CODENAME:-}" != "trixie" ]]; then
    fail "this installer requires Debian 13 (trixie) or LMDE 7"
  fi

  architecture="$(dpkg --print-architecture)"
  [[ "$architecture" == "amd64" ]] || fail "the Open Build Service package supports amd64 only (found $architecture)"
}

ensure_prerequisites() {
  local -a packages=()

  command -v curl >/dev/null 2>&1 || packages+=(curl)
  command -v gpg >/dev/null 2>&1 || packages+=(gnupg)
  dpkg-query -W -f='${db:Status-Abbrev}' ca-certificates 2>/dev/null | grep -q '^ii ' ||
    packages+=(ca-certificates)

  if ((${#packages[@]} == 0)); then
    return
  fi

  say "Installing prerequisites"
  sudo apt-get update
  sudo apt-get install --yes "${packages[@]}"
  ok "Prerequisites installed"
}

configure_repository() {
  local downloaded_fingerprint
  local downloaded_key
  local downloaded_keyring

  say "Configuring the ueberzugpp APT repository"
  TEMP_DIR="$(mktemp -d)"
  downloaded_key="$TEMP_DIR/Release.key"
  downloaded_keyring="$TEMP_DIR/ueberzugpp-archive-keyring.gpg"

  curl -fsSL "$KEY_URL" -o "$downloaded_key"
  downloaded_fingerprint="$(key_fingerprint "$downloaded_key")"
  if [[ "$downloaded_fingerprint" != "$KEY_FINGERPRINT" ]]; then
    fail "downloaded signing key has an unexpected fingerprint: ${downloaded_fingerprint:-unknown}"
  fi

  gpg --batch --yes --dearmor --output "$downloaded_keyring" "$downloaded_key"
  sudo install -d -m 0755 "$(dirname "$KEYRING")"
  sudo install -m 0644 "$downloaded_keyring" "$KEYRING"
  printf '%s\n' "$SOURCE_ENTRY" | sudo tee "$SOURCE_LIST" >/dev/null

  # Migrate files created by the upstream instructions away from global trust.
  sudo rm -f -- "$LEGACY_SOURCE_LIST" "$LEGACY_KEYRING"
  ok "APT repository configured"
}

install_package() {
  say "Installing or updating ueberzugpp"
  sudo apt-get update
  sudo apt-get install --yes "$PACKAGE"
  ok "$PACKAGE is installed"
}

main() {
  parse_args "$@"

  if [[ "$CHECK" == true ]]; then
    check_state
    return
  fi

  validate_host
  ensure_prerequisites
  configure_repository
  install_package
  check_state || fail "ueberzugpp installation completed with incomplete configuration"
}

main "$@"

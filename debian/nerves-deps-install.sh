#!/usr/bin/env bash
# Install Debian/Ubuntu system dependencies for Nerves development.
set -Eeuo pipefail
IFS=$'\n\t'

readonly -a PACKAGES=(
  autoconf
  automake
  bc
  build-essential
  cmake
  curl
  cvs
  gawk
  git
  jq
  libncurses5-dev
  libssl-dev
  mercurial
  pkg-config
  python3
  python3-aiohttp
  python3-flake8
  python3-ijson
  python3-nose2
  python3-pexpect
  python3-requests
  rsync
  squashfs-tools
  ssh-askpass
  subversion
  unzip
  wget
)

say() { printf '\n\033[34m%s\033[0m\n' "$*"; }
ok() { printf ' \033[32m✔ %s\033[0m\n' "$*"; }
fail() {
  printf ' \033[31m✖ %s\033[0m\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

validate_host() {
  case "$(uname -m)" in
  x86_64 | aarch64 | arm64) ;;
  *) fail "Nerves systems builds require an x86_64 or aarch64 Linux host" ;;
  esac
}

verify_python_dependencies() {
  python3 - <<'PY'
import importlib

for module in ("aiohttp", "flake8", "ijson", "nose2", "pexpect", "requests"):
    importlib.import_module(module)
PY
}

main() {
  [[ $# -eq 0 ]] || fail "this script does not accept arguments"
  [[ $EUID -ne 0 ]] || fail "run as your normal user, not with sudo"
  require_command sudo
  require_command apt-get
  validate_host

  say "Installing Nerves system dependencies"
  sudo apt-get update
  sudo apt-get install --yes "${PACKAGES[@]}"
  ok "Nerves system packages installed"

  say "Verifying Python dependencies"
  verify_python_dependencies || fail "one or more Python dependencies cannot be imported"
  ok "Python dependencies verified"
}

main "$@"

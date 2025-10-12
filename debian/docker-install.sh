#!/bin/bash
#
# debian/docker_install.sh — Install Docker Engine & (optionally) compose plugin,
# and add the current user to the "docker" group.
#
set -Eeuo pipefail

# ----------------------------
# Printing helpers
# ----------------------------
echo_heading() { echo -e "\n\033[34m$1\033[0m"; }
echo_success() { echo -e " \033[32m✔ $1\033[0m"; }
echo_failure() { echo -e " \033[31m✖ $1\033[0m"; }
die() {
  echo_failure "$*"
  exit 1
}

# Ensure bash
if [ -z "${BASH_VERSION:-}" ]; then
  exec /usr/bin/env bash "$0" "$@"
fi

# ----------------------------
# Options
# ----------------------------
DO_GROUP=1   # add current user to "docker" group
DO_COMPOSE=1 # install docker-compose-plugin
APT_UPDATED=0

usage() {
  cat <<'EOF'
Usage: docker_install.sh [--no-group[=true|false]] [--no-compose[=true|false]] [-h|--help]

Installs Docker Engine using the official convenience script.
Optionally adds the current user to the "docker" group and installs the compose plugin.

Examples:
  ./docker_install.sh
  ./docker_install.sh --no-group
  ./docker_install.sh --no-compose=false
EOF
}

parse_args() {
  while (("$#")); do
    case "$1" in
    --no-group | --no-group=true) DO_GROUP=0 ;;
    --no-group=false) DO_GROUP=1 ;;
    --no-compose | --no-compose=true) DO_COMPOSE=0 ;;
    --no-compose=false) DO_COMPOSE=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *) die "Unknown option: $1" ;;
    esac
    shift
  done
}

# ----------------------------
# Preflight / helpers
# ----------------------------
export DEBIAN_FRONTEND=noninteractive
APT_FLAGS=(-y -o Dpkg::Use-Pty=0 -o Acquire::Retries=3)

apt_update_once() {
  if [ "${APT_UPDATED}" -eq 0 ]; then
    echo_heading "Refreshing APT metadata..."
    sudo apt-get update "${APT_FLAGS[@]}" >/dev/null || true
    APT_UPDATED=1
    echo_success "APT updated."
  fi
}

pkg_installed() { dpkg -s "$1" >/dev/null 2>&1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

retry() {
  # retry <tries> <sleep> -- <cmd...>
  local tries="${1:-2}" sleep_s="${2:-3}"
  shift 2
  [ "$1" = "--" ] && shift || die "retry usage: retry <tries> <sleep> -- <cmd...>"
  local n=1
  while true; do
    if "$@"; then return 0; fi
    if [ "$n" -ge "$tries" ]; then return 1; fi
    echo " ... transient failure; retrying in ${sleep_s}s (attempt $((n + 1))/$tries) ..."
    sleep "$sleep_s"
    # helpful nudge for APT-related commands between attempts
    sudo apt-get update -yqq >/dev/null 2>&1 || true
    n=$((n + 1))
  done
}

# ----------------------------
# Steps
# ----------------------------
install_engine() {
  echo_heading "Installing Docker Engine (if needed)..."
  if command -v docker >/dev/null 2>&1; then
    echo_success "Docker already installed: $(docker --version)"
    return
  fi

  # https://docs.docker.com/engine/install/debian/#install-using-the-convenience-script
  require_cmd curl
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  # Try the official convenience script, but allow a quick second chance.
  retry 2 3 -- curl -fsSL https://get.docker.com -o "$tmp/get-docker.sh" ||
    die "Failed to download get.docker.com script."
  retry 2 3 -- sudo sh "$tmp/get-docker.sh" ||
    die "Docker install script failed after retries."
  echo_success "Docker Engine installed."
}

ensure_group() {
  echo_heading "Adding current user to 'docker' group (optional)..."
  if [ "$DO_GROUP" -eq 0 ]; then
    echo_success "Skipping docker group membership (--no-group)."
    return
  fi

  # If invoked via sudo, add the invoking user (not root).
  local TARGET_USER="${SUDO_USER:-$USER}"

  if groups "$TARGET_USER" | grep -qw docker; then
    echo_success "User '$TARGET_USER' already in docker group."
  else
    sudo groupadd -f docker
    sudo usermod -aG docker "$TARGET_USER"
    ADDED_TO_GROUP=1
    echo_success "Added '$TARGET_USER' to docker group."
  fi
}

install_compose_plugin() {
  echo_heading "Installing docker compose plugin (optional)..."
  if [ "$DO_COMPOSE" -eq 0 ]; then
    echo_success "Skipping compose plugin (--no-compose)."
    return
  fi

  if pkg_installed docker-compose-plugin; then
    echo_success "docker-compose-plugin already installed."
    return
  fi

  apt_update_once
  # A tiny bit more forgiving: try with --fix-missing once if needed.
  if ! retry 2 3 -- sudo apt-get install "${APT_FLAGS[@]}" -qq docker-compose-plugin >/dev/null; then
    echo "Trying again with --fix-missing ..."
    retry 2 5 -- sudo apt-get install "${APT_FLAGS[@]}" --fix-missing -qq docker-compose-plugin >/dev/null ||
      die "Failed to install docker-compose-plugin."
  fi
  echo_success "docker-compose-plugin installed."
}

sanity_check() {
  echo_heading "Sanity check..."
  docker --version >/dev/null
  echo_success "$(docker --version)"
  if [ "$DO_COMPOSE" -ne 0 ]; then
    docker compose version >/dev/null
    echo_success "$(docker compose version)"
  fi
}

post_notes() {
  if [ "${ADDED_TO_GROUP:-0}" -eq 1 ]; then
    echo_heading "Final note"
    echo "You were added to the 'docker' group."
    echo "Log out and back in (or reboot) to use docker without sudo."
  fi
}

# ----------------------------
# Main
# ----------------------------
main() {
  parse_args "$@"
  require_cmd sudo

  install_engine
  ensure_group
  install_compose_plugin
  sanity_check
  echo_heading "Docker setup complete."
  post_notes
}

main "$@"

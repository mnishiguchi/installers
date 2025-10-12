#!/bin/bash
#
# debian/docker_uninstall.sh — Stop/disable and purge Docker Engine & (optionally) data
# Style aligned with yazi-uninstall.sh (echo_* helpers + simple main()).
#
set -eu

# ----------------------------
# Printing helpers (aligned)
# ----------------------------
echo_heading() { echo -e "\n\033[34m$1\033[0m"; }
echo_success() { echo -e " \033[32m✔ $1\033[0m"; }
echo_failure() { echo -e " \033[31m✖ $1\033[0m"; }
die() {
  echo_failure "$*"
  exit 1
}

# Ensure we’re running under bash (not sh/dash)
if [ -z "${BASH_VERSION:-}" ]; then
  exec /usr/bin/env bash "$0" "$@"
fi

# ----------------------------
# Options (defaults)
# ----------------------------
REMOVE_DATA=1            # remove /var/lib/docker & /var/lib/containerd by default
REMOVE_GROUP=0           # remove the 'docker' group
REMOVE_USER_FROM_GROUP=0 # remove current user from 'docker' group

usage() {
  cat <<'EOF'
Usage: docker_uninstall.sh [--keep-data[=true|false]]
                           [--remove-group[=true|false]]
                           [--remove-user-from-group[=true|false]]
                           [-h|--help]

Stops and disables Docker services, purges Docker Engine packages,
and removes data at /var/lib/docker and /var/lib/containerd (default behavior).

Examples:
  ./docker_uninstall.sh
  ./docker_uninstall.sh --keep-data
  ./docker_uninstall.sh --remove-group --remove-user-from-group
EOF
}

parse_args() {
  while (("$#")); do
    case "$1" in
    --keep-data | --keep-data=true) REMOVE_DATA=0 ;;
    --keep-data=false) REMOVE_DATA=1 ;;
    --remove-group | --remove-group=true) REMOVE_GROUP=1 ;;
    --remove-group=false) REMOVE_GROUP=0 ;;
    --remove-user-from-group | --remove-user-from-group=true)
      REMOVE_USER_FROM_GROUP=1
      ;;
    --remove-user-from-group=false) REMOVE_USER_FROM_GROUP=0 ;;
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

require_cmd() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

# ----------------------------
# Steps
# ----------------------------
stop_services() {
  echo_heading "Stopping and disabling Docker services (if present)..."
  sudo systemctl disable --now docker.service docker.socket 2>/dev/null || true
  sudo systemctl disable --now containerd.service 2>/dev/null || true
  echo_success "Services stopped/disabled (if they were present)."
}

purge_packages() {
  echo_heading "Purging Docker Engine packages..."
  # Try both upstream and Debian package names; ignore missing ones
  sudo apt purge "${APT_FLAGS[@]}" \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras \
    docker.io 2>/dev/null || true
  sudo apt autoremove "${APT_FLAGS[@]}" || true
  echo_success "Packages purged (or were already absent)."
}

remove_data_dirs() {
  if [ "$REMOVE_DATA" -eq 1 ]; then
    echo_heading "Removing Docker data directories..."
    sudo rm -rf /var/lib/docker /var/lib/containerd 2>/dev/null || true
    # Clean up a few stragglers if they exist
    sudo rm -rf /etc/docker 2>/dev/null || true
    sudo rm -f /var/run/docker.sock 2>/dev/null || true
    echo_success "Data directories removed."
  else
    echo_heading "Keeping data directories (--keep-data)."
    echo_success "Left /var/lib/docker and /var/lib/containerd intact."
  fi
}

group_cleanup() {
  # Remove user from group (optional)
  if [ "$REMOVE_USER_FROM_GROUP" -eq 1 ]; then
    echo_heading "Removing current user from 'docker' group..."
    if getent group docker >/dev/null; then
      sudo gpasswd -d "$USER" docker 2>/dev/null || true
      echo_success "User '$USER' removed from 'docker' group (if present)."
    else
      echo_success "Group 'docker' does not exist; nothing to do."
    fi
  fi

  # Remove group (optional)
  if [ "$REMOVE_GROUP" -eq 1 ]; then
    echo_heading "Removing 'docker' group..."
    sudo groupdel docker 2>/dev/null || true
    echo_success "'docker' group removed (if it existed)."
  fi
}

sanity_note() {
  echo_heading "Final check"
  if command -v docker >/dev/null 2>&1; then
    echo_failure "docker command still present: $(command -v docker)"
    echo "You may have another Docker installation method in place; remove it manually."
  else
    echo_success "docker command not found — uninstallation looks good."
  fi
}

# ----------------------------
# Main
# ----------------------------
main() {
  parse_args "$@"
  require_cmd sudo

  stop_services
  purge_packages
  remove_data_dirs
  group_cleanup
  sanity_note
  echo_heading "Docker uninstallation complete."
}

main "$@"

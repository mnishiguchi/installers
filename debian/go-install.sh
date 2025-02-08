#!/usr/bin/env bash

# -----------------------------------------------------------------------------
# Go Installer Script
# -----------------------------------------------------------------------------
# Installs a user-selected Go version from the latest 5 releases.
#
# Requirements: git, wget
#
# Usage:
#   ./install-go.sh        # Interactive installation
#   ./install-go.sh --help # Show help message
# -----------------------------------------------------------------------------

set -eu

INSTALL_DIR="/usr/local"
GO_PATH="${INSTALL_DIR}/go"
GO_REPO="https://go.googlesource.com/go"

echo_heading() { echo -e "\n\033[34m$1\033[0m"; }
echo_success() { echo -e " \033[32m✔ $1\033[0m"; }
echo_warning() { echo -e " \033[33m⚠ $1\033[0m"; }
echo_failure() { echo -e " \033[31m✖ $1\033[0m"; }

fetch_latest_versions() {
  echo_heading "Fetching latest Go versions..."
  AVAILABLE_VERSIONS=$(git ls-remote --tags --refs "$GO_REPO" | awk -F'/' '{print $3}' | grep -E '^go[0-9]+\.[0-9]+\.[0-9]+$' | sort -Vr | head -n 5)

  if [[ -z "$AVAILABLE_VERSIONS" ]]; then
    echo_failure "Failed to fetch versions from Git repository."
    exit 1
  fi

  echo "Available Go versions:"
  echo "$AVAILABLE_VERSIONS" | nl
}

prompt_go_version() {
  fetch_latest_versions

  read -p "Enter the number of the version you want to install: " VERSION_INDEX
  GO_VERSION=$(echo "$AVAILABLE_VERSIONS" | sed -n "${VERSION_INDEX}p")

  if [[ -z "$GO_VERSION" ]]; then
    echo_failure "Invalid selection. Exiting."
    exit 1
  fi

  GO_VERSION=${GO_VERSION#go}  # Remove "go" prefix
  GO_TARBALL="go${GO_VERSION}.linux-amd64.tar.gz"
  GO_URL="https://go.dev/dl/${GO_TARBALL}"

  echo_success "Selected Go version: ${GO_VERSION}"
}

check_existing_go() {
  if command -v go &>/dev/null; then
    INSTALLED_VERSION=$(go version | awk '{print $3}')
    echo_warning "Go is already installed: $INSTALLED_VERSION"
    if [[ "$INSTALLED_VERSION" == "go${GO_VERSION}" ]]; then
      echo_success "You already have the latest version of Go (${GO_VERSION}). No need to install."
      exit 0
    else
      echo_heading "Removing old Go version..."
      sudo rm -rf "${GO_PATH}"
      echo_success "Old Go version removed."
    fi
  fi
}

download_go() {
  echo_heading "Downloading Go ${GO_VERSION}..."
  wget -q --show-progress "${GO_URL}"
  echo_success "Downloaded ${GO_TARBALL}."
}

install_go() {
  echo_heading "Installing Go..."
  sudo tar -C "${INSTALL_DIR}" -xzf "${GO_TARBALL}"
  echo_success "Go installed at ${GO_PATH}."

  # Clean up
  rm -f "${GO_TARBALL}"
}

print_manual_path_instructions() {
  echo_heading "Manual PATH Setup Required"

  # Check if another Go version exists
  if command -v go &>/dev/null && [[ "$(which go)" != "/usr/local/go/bin/go" ]]; then
    EXISTING_GO_PATH=$(which go)
    EXISTING_GO_VERSION=$(go version 2>/dev/null || echo "Unknown version")
    echo_warning "Another Go version is already installed at:"
    echo -e "   \033[36m$EXISTING_GO_PATH\033[0m ($EXISTING_GO_VERSION)"
  fi

  echo -e "\nTo use Go, add the following line to your shell configuration file:"
  echo -e "\n\033[36m    export PATH=/usr/local/go/bin:\$PATH\033[0m\n"
  echo "Then apply the changes with:"
  echo -e "\n\033[36m    source ~/.bashrc  # or source ~/.profile\033[0m\n"
}

verify_installation() {
  echo_heading "Verifying Go installation..."
  if command -v go &>/dev/null; then
    go version
    echo_success "Go ${GO_VERSION} installed successfully!"
  else
    echo_failure "Go installation failed. Please check the script output."
    exit 1
  fi
}

help_text() {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  --help     Show this help message"
}

main() {
  if [[ "${1:-}" == "--help" ]]; then
    help_text
    exit 0
  fi

  prompt_go_version
  check_existing_go
  download_go
  install_go
  print_manual_path_instructions
  verify_installation
}

main "$@"

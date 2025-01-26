#!/bin/bash
#
# This script automates the installation of the latest version of Lazygit from GitHub Releases.
#
# Requirements:
# - OS: Linux (x86_64 architecture)
# - Dependencies: curl, tar

set -eu

# Print headings
echo_heading() {
  echo -e "\n\033[34m$1\033[0m"
}

# Print success message
echo_success() {
  echo -e " \033[32m✔ $1\033[0m"
}

# Print failure message
echo_failure() {
  echo -e " \033[31m✖ $1\033[0m"
}

main() {
  BINARY_DEST="$HOME/.local/bin"
  TMP_DIR="/tmp/lazygit_install"
  ARCH="Linux_x86_64"

  echo_heading "Preparing environment..."
  mkdir -p "$BINARY_DEST" "$TMP_DIR"

  echo_heading "Fetching latest Lazygit release information..."
  LATEST_TAG=$(curl -sL -o /dev/null -w "%{url_effective}" https://github.com/jesseduffield/lazygit/releases/latest | grep -oP 'v[0-9]+\.[0-9]+\.[0-9]+')
  if [[ -z "$LATEST_TAG" ]]; then
    echo_failure "Failed to fetch the latest Lazygit release. Please check your internet connection."
    exit 1
  fi

  echo_heading "Checking installed Lazygit version..."
  INSTALLED_VERSION=$($BINARY_DEST/lazygit --version 2>/dev/null | awk '{print $2}' || echo "none")
  if [[ "$INSTALLED_VERSION" == "$LATEST_TAG" ]]; then
    echo_success "Lazygit $INSTALLED_VERSION is already installed. Skipping installation."
    exit 0
  fi

  echo_heading "Downloading Lazygit $LATEST_TAG..."
  DOWNLOAD_URL="https://github.com/jesseduffield/lazygit/releases/download/$LATEST_TAG/lazygit_${LATEST_TAG#v}_${ARCH}.tar.gz"
  TARBALL="$TMP_DIR/lazygit.tar.gz"
  if curl -Lo "$TARBALL" "$DOWNLOAD_URL"; then
    echo_success "Lazygit $LATEST_TAG downloaded successfully."
  else
    echo_failure "Failed to download Lazygit $LATEST_TAG."
    exit 1
  fi

  echo_heading "Extracting Lazygit binary..."
  if tar -xzf "$TARBALL" -C "$TMP_DIR"; then
    echo_success "Lazygit binary extracted."
  else
    echo_failure "Failed to extract Lazygit tarball."
    exit 1
  fi

  echo_heading "Installing Lazygit..."
  if mv "$TMP_DIR/lazygit" "$BINARY_DEST" && chmod +x "$BINARY_DEST/lazygit"; then
    echo_success "Lazygit installed to $BINARY_DEST."
  else
    echo_failure "Failed to install Lazygit."
    exit 1
  fi

  echo_heading "Cleaning up temporary files..."
  rm -rf "$TMP_DIR"
  echo_success "Temporary files cleaned up."

  echo_heading "Verifying Lazygit installation..."
  if command -v lazygit &>/dev/null; then
    echo_success "Lazygit installed successfully and is available in PATH."
  else
    echo_failure "Lazygit installation verification failed. Ensure $BINARY_DEST is in your PATH."
    exit 1
  fi

  echo_heading "Installation complete."
  if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo_heading "Note: $HOME/.local/bin is not in your PATH."
    echo -e "To add it, run the following command:\n"
    echo "    echo 'export PATH=\"$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
    echo -e "\nRestart your terminal or source your shell configuration to apply changes."
  else
    echo_success "$HOME/.local/bin is already in your PATH."
  fi
}

main "$@"

#!/bin/bash
#
# This script automates the installation and setup of Ghostty terminal from source.
#
# Requirements:
# - OS: Debian-based Linux distributions
# - Dependencies: Zig, Git and GTK libraries (libgtk-4-dev, libadwaita-1-dev)

set -eu

GHOSTTY_REPO="https://github.com/ghostty-org/ghostty"
INSTALL_PREFIX="$HOME/.local"
INSTALL_DIR="$HOME/.config/ghostty/ghostty"
CONFIG_FILE="$HOME/.config/ghostty/config"
DEFAULT_THEME="Dracula+"
DEFAULT_FONT="FiraCode Nerd Font"

echo_heading() { echo -e "\n\033[34m$1\033[0m"; }
echo_success() { echo -e " \033[32m✔ $1\033[0m"; }
echo_failure() { echo -e " \033[31m✖ $1\033[0m"; }

fetch_versions() {
  echo_heading "Fetching available Ghostty versions..."
  AVAILABLE_VERSIONS=$(git ls-remote --tags --refs "$GHOSTTY_REPO" | awk -F'/' '{print $3}' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -Vr | head -n 10)

  echo "Available Ghostty versions:"
  printf "  0) main (latest)\n"
  echo "$AVAILABLE_VERSIONS" | nl -w 3 -s ") "

  read -p "Enter the number of the version you want to install (default: latest): " VERSION_INDEX
  if [[ -z "$VERSION_INDEX" || "$VERSION_INDEX" == "0" ]]; then
    GHOSTTY_VERSION="main"
  else
    GHOSTTY_VERSION=$(echo "$AVAILABLE_VERSIONS" | sed -n "${VERSION_INDEX}p")
    if [[ -z "$GHOSTTY_VERSION" ]]; then
      echo_failure "Invalid selection. Defaulting to latest (main)."
      GHOSTTY_VERSION="main"
    fi
  fi

  echo_success "Selected Ghostty version: ${GHOSTTY_VERSION}"
}

install_dependencies() {
  echo_heading "Installing dependencies..."
  if sudo apt update && sudo apt install -y libgtk-4-dev libadwaita-1-dev git; then
    echo_success "Dependencies installed."
  else
    echo_failure "Failed to install dependencies."
    exit 1
  fi
}

setup_source() {
  echo_heading "Setting up Ghostty source code..."
  mkdir -p "$(dirname "$INSTALL_DIR")"

  if [[ -d "$INSTALL_DIR" ]]; then
    echo_heading "Ghostty source exists. Checking out selected version."
    cd "$INSTALL_DIR"
    git fetch --tags
  else
    if git clone "$GHOSTTY_REPO" "$INSTALL_DIR"; then
      echo_success "Cloned Ghostty repository."
    else
      echo_failure "Failed to clone Ghostty repository."
      exit 1
    fi
    cd "$INSTALL_DIR"
  fi

  git checkout "$GHOSTTY_VERSION"
}

build_and_install() {
  echo_heading "Building and installing Ghostty..."
  if zig build -p "$INSTALL_PREFIX" -Doptimize=ReleaseFast; then
    echo_success "Ghostty built and installed at $INSTALL_PREFIX."
  else
    echo_failure "Failed to build Ghostty."
    exit 1
  fi
}

verify_installation() {
  echo_heading "Verifying Ghostty binary..."
  if "$INSTALL_PREFIX/bin/ghostty" --help >/dev/null 2>&1; then
    echo_success "Ghostty binary verified."
  else
    echo_failure "Error: Ghostty binary did not build or run correctly."
    exit 1
  fi
}

setup_configuration() {
  echo_heading "Creating default configuration..."
  if [[ -f "$CONFIG_FILE" ]]; then
    echo_success "Configuration file already exists at $CONFIG_FILE. Skipping configuration setup."
  else
    mkdir -p "$(dirname "$CONFIG_FILE")"
    cat >"$CONFIG_FILE" <<EOL
theme = $DEFAULT_THEME
font-size = 10
font-family = $DEFAULT_FONT
EOL
    echo_success "Default configuration created at $CONFIG_FILE."
  fi
  echo_heading "Current configuration:"
  cat "$CONFIG_FILE"
}

setup_desktop_entry() {
  echo_heading "Installing and renaming desktop entry..."
  ORIGINAL_DESKTOP_FILE="$INSTALL_PREFIX/share/applications/com.mitchellh.ghostty.desktop"
  TARGET_DESKTOP_FILE="$HOME/.local/share/applications/Ghostty.desktop"

  if [[ -f "$ORIGINAL_DESKTOP_FILE" ]]; then
    mkdir -p "$(dirname "$TARGET_DESKTOP_FILE")"
    mv "$ORIGINAL_DESKTOP_FILE" "$TARGET_DESKTOP_FILE"
    echo_success "Desktop entry installed and renamed to: $TARGET_DESKTOP_FILE"
  else
    echo_failure "Original desktop entry not found: $ORIGINAL_DESKTOP_FILE"
    exit 1
  fi
}

refresh_menu() {
  echo_heading "Refreshing application menu..."
  if update-desktop-database "$HOME/.local/share/applications/"; then
    echo_success "Application menu refreshed."
  else
    echo_failure "Failed to refresh application menu."
  fi
}

main() {
  fetch_versions
  install_dependencies
  setup_source
  build_and_install
  verify_installation
  setup_configuration
  setup_desktop_entry
  refresh_menu

  echo_heading "Installation complete."
  if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo_heading "Note: $HOME/.local/bin is not in your PATH."
    echo -e "To add it, you can run the following command:\n"
    echo "    echo 'export PATH=\"$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
    echo -e "\nRestart your terminal or source your shell configuration to apply changes."
  else
    echo_success "$HOME/.local/bin is already in your PATH."
  fi

  echo_heading "Ghostty is ready to use."
}

main "$@"

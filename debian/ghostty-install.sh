#!/bin/bash
#
# This script automates the installation and setup of Ghostty terminal from source.
#
# Requirements:
# - OS: Debian-based Linux distributions
# - Dependencies: Zig, Git and GTK libraries (libgtk-4-dev, libadwaita-1-dev)

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
  GHOSTTY_REPO="https://github.com/ghostty-org/ghostty"
  INSTALL_PREFIX="$HOME/.local"
  INSTALL_DIR="$HOME/.config/ghostty/ghostty"
  CONFIG_FILE="$HOME/.config/ghostty/config"
  DEFAULT_THEME="Dracula+"
  DEFAULT_FONT="FiraCode Nerd Font"

  echo_heading "Installing dependencies..."
  if sudo apt update && sudo apt install -y libgtk-4-dev libadwaita-1-dev git; then
    echo_success "Dependencies installed."
  else
    echo_failure "Failed to install dependencies."
    exit 1
  fi

  echo_heading "Setting up Ghostty source code..."
  mkdir -p "$(dirname "$INSTALL_DIR")"
  if [[ -d "$INSTALL_DIR" ]]; then
    echo_heading "Ghostty source exists. Pulling latest changes."
    cd "$INSTALL_DIR"
    if git pull; then
      echo_success "Updated Ghostty source."
    else
      echo_failure "Failed to update Ghostty source."
      exit 1
    fi
  else
    if git clone "$GHOSTTY_REPO" "$INSTALL_DIR"; then
      echo_success "Cloned Ghostty repository."
    else
      echo_failure "Failed to clone Ghostty repository."
      exit 1
    fi
    cd "$INSTALL_DIR"
  fi

  echo_heading "Building and installing Ghostty..."
  if zig build -p "$INSTALL_PREFIX" -Doptimize=ReleaseFast; then
    echo_success "Ghostty built and installed at $INSTALL_PREFIX."
  else
    echo_failure "Failed to build Ghostty."
    exit 1
  fi

  echo_heading "Verifying Ghostty binary..."
  if "$INSTALL_PREFIX/bin/ghostty" --help >/dev/null 2>&1; then
    echo_success "Ghostty binary verified."
  else
    echo_failure "Error: Ghostty binary did not build or run correctly."
    exit 1
  fi

  echo_heading "Creating default configuration..."
  if [[ -f "$CONFIG_FILE" ]]; then
    echo_success "Configuration file already exists at $CONFIG_FILE. Skipping configuration setup."
  else
    mkdir -p "$(dirname "$CONFIG_FILE")"
    if cat > "$CONFIG_FILE" <<EOL
theme = $DEFAULT_THEME
font-size = 10
font-family = $DEFAULT_FONT
EOL
    then
      echo_success "Default configuration created at $CONFIG_FILE."
    else
      echo_failure "Failed to create configuration file."
      exit 1
    fi
  fi

  echo_heading "Current configuration:"
  cat "$CONFIG_FILE"

  echo_heading "Installing and renaming desktop entry..."
  ORIGINAL_DESKTOP_FILE="$INSTALL_PREFIX/share/applications/com.mitchellh.ghostty.desktop"
  TARGET_DESKTOP_FILE="$HOME/.local/share/applications/Ghostty.desktop"

  # Renaming the desktop entry aligns with naming conventions your application
  # menu might expect and avoids potential conflicts. This approach ensures the
  # app launcher works consistently.
  if [[ -f "$ORIGINAL_DESKTOP_FILE" ]]; then
    mkdir -p "$(dirname "$TARGET_DESKTOP_FILE")"
    if mv "$ORIGINAL_DESKTOP_FILE" "$TARGET_DESKTOP_FILE"; then
      echo_success "Desktop entry installed and renamed to: $TARGET_DESKTOP_FILE"
    else
      echo_failure "Failed to rename desktop entry."
      exit 1
    fi
  else
    echo_failure "Original desktop entry not found: $ORIGINAL_DESKTOP_FILE"
    exit 1
  fi

  echo_heading "Refreshing application menu..."
  if update-desktop-database "$HOME/.local/share/applications/"; then
    echo_success "Application menu refreshed."
  else
    echo_failure "Failed to refresh application menu."
  fi

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

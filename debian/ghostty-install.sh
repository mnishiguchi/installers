#!/bin/bash
#
# This script automates the installation and setup of Ghostty terminal from source.
#
# Prerequisites: Zig, Git, and required GTK libraries.

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
  INSTALL_DIR="$HOME/.config/ghostty/ghostty"
  CONFIG_FILE="$HOME/.config/ghostty/config"
  THEMES_SRC="$INSTALL_DIR/zig-out/share/ghostty/themes"
  THEMES_DEST="$HOME/.config/ghostty/themes"
  EXEC_PATH="$HOME/.local/bin/ghostty"
  DESKTOP_FILE_SRC="$INSTALL_DIR/zig-out/share/applications/com.mitchellh.ghostty.desktop"
  DESKTOP_FILE_DEST="$HOME/.local/share/applications/Ghostty.desktop"
  ICON_SRC="$INSTALL_DIR/zig-out/share/icons/hicolor/128x128/apps/com.mitchellh.ghostty.png"
  ICON_DEST="$HOME/.local/share/icons/hicolor/128x128/apps/com.mitchellh.ghostty.png"
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

  echo_heading "Building Ghostty..."
  if zig build -Doptimize=ReleaseFast; then
    echo_success "Ghostty built successfully."
  else
    echo_failure "Failed to build Ghostty."
    exit 1
  fi

  echo_heading "Verifying Ghostty binary..."
  if "$INSTALL_DIR/zig-out/bin/ghostty" --help >/dev/null 2>&1; then
    echo_success "Ghostty binary verified."
  else
    echo_failure "Error: Ghostty binary did not build or run correctly."
    exit 1
  fi

  echo_heading "Installing Ghostty binary..."
  mkdir -p "$HOME/.local/bin"
  if cp "$INSTALL_DIR/zig-out/bin/ghostty" "$EXEC_PATH"; then
    echo_success "Binary installed at $EXEC_PATH."
  else
    echo_failure "Failed to install binary."
    exit 1
  fi

  echo_heading "Installing desktop entry..."
  mkdir -p "$(dirname "$DESKTOP_FILE_DEST")"
  if cp "$DESKTOP_FILE_SRC" "$DESKTOP_FILE_DEST"; then
    echo_success "Desktop entry installed at $DESKTOP_FILE_DEST."
  else
    echo_failure "Failed to install desktop entry."
    exit 1
  fi

  echo_heading "Installing icon..."
  mkdir -p "$(dirname "$ICON_DEST")"
  if cp "$ICON_SRC" "$ICON_DEST"; then
    echo_success "Icon installed at $ICON_DEST."
  else
    echo_failure "Failed to install icon."
    exit 1
  fi

  echo_heading "Refreshing application menu..."
  if update-desktop-database "$HOME/.local/share/applications/"; then
    echo_success "Application menu refreshed."
  else
    echo_failure "Failed to refresh application menu."
  fi

  echo_heading "Setting up Ghostty themes..."
  mkdir -p "$THEMES_DEST"
  if [[ -d "$THEMES_SRC" ]]; then
    if cp -r "$THEMES_SRC"/* "$THEMES_DEST/"; then
      echo_success "Themes copied to $THEMES_DEST."
    else
      echo_failure "Failed to copy themes."
      exit 1
    fi
  else
    echo_heading "Warning: Themes source directory not found. Skipping theme setup."
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

  echo_heading "Cleaning up build directory..."
  if rm -rf "$INSTALL_DIR/zig-out"; then
    echo_success "Build directory removed."
  else
    echo_failure "Failed to remove build directory."
  fi

  echo_heading "Installation complete. Ghostty is ready to use."
}

main "$@"

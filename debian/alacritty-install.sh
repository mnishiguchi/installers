#!/bin/bash
#
# This script automates the installation and setup of Alacritty terminal from source.
# It also clones and sets up the alacritty-theme repository for easy theme management.
#
# Prerequisites: Rust, Git, and required dependencies.

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
  ALACRITTY_REPO="https://github.com/alacritty/alacritty"
  ALACRITTY_THEME_REPO="https://github.com/alacritty/alacritty-theme"
  INSTALL_DIR="$HOME/.config/alacritty/alacritty"
  THEME_DIR="$HOME/.config/alacritty/themes"
  DESKTOP_FILE="$HOME/.local/share/applications/Alacritty.desktop"
  EXEC_PATH="$HOME/.local/bin/alacritty"
  ICON_PATH="$HOME/.local/share/icons/Alacritty.svg"
  DEFAULT_THEME="dracula_plus"
  DEFAULT_FONT="FiraCode Nerd Font"

  # Ensure Rust is installed
  echo_heading "Checking Rust installation..."
  if command -v cargo >/dev/null 2>&1; then
    echo_success "Rust is installed."
  else
    echo_failure "Rust is not installed. Please install Rust and retry."
    exit 1
  fi

  # Install dependencies
  echo_heading "Installing dependencies..."
  if sudo apt update && sudo apt install -y cmake g++ pkg-config libfreetype6-dev libfontconfig1-dev libxcb-xfixes0-dev libxkbcommon-dev python3; then
    echo_success "Dependencies installed."
  else
    echo_failure "Failed to install dependencies."
    exit 1
  fi

  # Clone or update Alacritty repository
  echo_heading "Setting up Alacritty source code..."
  mkdir -p "$(dirname "$INSTALL_DIR")"
  if [[ -d "$INSTALL_DIR" ]]; then
    echo_heading "Alacritty source exists. Pulling latest changes."
    cd "$INSTALL_DIR"
    if git pull; then
      echo_success "Updated Alacritty source."
    else
      echo_failure "Failed to update Alacritty source."
      exit 1
    fi
  else
    if git clone "$ALACRITTY_REPO" "$INSTALL_DIR"; then
      echo_success "Cloned Alacritty repository."
    else
      echo_failure "Failed to clone Alacritty repository."
      exit 1
    fi
    cd "$INSTALL_DIR"
  fi

  # Build Alacritty
  echo_heading "Building Alacritty..."
  if cargo build --release; then
    echo_success "Alacritty built successfully."
  else
    echo_failure "Failed to build Alacritty."
    exit 1
  fi

  # Verify the build
  echo_heading "Verifying Alacritty binary..."
  if "$INSTALL_DIR/target/release/alacritty" --help >/dev/null 2>&1; then
    echo_success "Alacritty binary verified."
  else
    echo_failure "Error: Alacritty binary did not build or run correctly."
    exit 1
  fi

  # Move binary to ~/.local/bin
  echo_heading "Installing Alacritty binary..."
  mkdir -p "$HOME/.local/bin"
  if cp "$INSTALL_DIR/target/release/alacritty" "$EXEC_PATH"; then
    echo_success "Binary installed at $EXEC_PATH."
  else
    echo_failure "Failed to install binary."
    exit 1
  fi

  # Install terminfo
  echo_heading "Installing terminfo..."
  if tic -xe alacritty,alacritty-direct "$INSTALL_DIR/extra/alacritty.info"; then
    echo_success "Terminfo installed."
  else
    echo_failure "Failed to install terminfo."
  fi

  # Copy desktop file
  echo_heading "Installing desktop entry..."
  mkdir -p "$HOME/.local/share/applications"
  if cp "$INSTALL_DIR/extra/linux/Alacritty.desktop" "$DESKTOP_FILE"; then
    echo_success "Desktop entry installed at $DESKTOP_FILE."
  else
    echo_failure "Failed to install desktop entry."
    exit 1
  fi

  # Install icon
  echo_heading "Installing icon..."
  mkdir -p "$(dirname "$ICON_PATH")"
  if cp "$INSTALL_DIR/extra/logo/alacritty-term.svg" "$ICON_PATH"; then
    echo_success "Icon installed at $ICON_PATH."
  else
    echo_failure "Failed to install icon."
    exit 1
  fi

  # Refresh application menu
  echo_heading "Refreshing application menu..."
  if update-desktop-database "$HOME/.local/share/applications/"; then
    echo_success "Application menu refreshed."
  else
    echo_failure "Failed to refresh application menu."
  fi

  # Clone or update alacritty-theme repository
  echo_heading "Setting up Alacritty themes..."
  mkdir -p "$(dirname "$THEME_DIR")"
  if [[ -d "$THEME_DIR" ]]; then
    echo_heading "Themes directory exists. Pulling latest changes."
    cd "$THEME_DIR"
    if git pull; then
      echo_success "Updated themes."
    else
      echo_failure "Failed to update themes."
      exit 1
    fi
  else
    if git clone "$ALACRITTY_THEME_REPO" "$THEME_DIR"; then
      echo_success "Cloned themes repository."
    else
      echo_failure "Failed to clone themes repository."
      exit 1
    fi
  fi

  # Set default theme
  echo_heading "Creating default configuration..."
  CONFIG_FILE="$HOME/.config/alacritty/alacritty.toml"
  if [[ -f "$CONFIG_FILE" ]]; then
    echo_success "Configuration file already exists at $CONFIG_FILE. Skipping configuration setup."
  else
    mkdir -p "$(dirname "$CONFIG_FILE")"
    if cat > "$CONFIG_FILE" <<EOL
[general]
import = ["$THEME_DIR/themes/$DEFAULT_THEME.toml"]

[font]
size = 10

[font.normal]
family = "$DEFAULT_FONT"
style = "Regular"

[font.bold]
family = "$DEFAULT_FONT"
style = "Bold"

[[keyboard.bindings]]
key = "C"
mods = "Control|Shift"
action = "Copy"

[[keyboard.bindings]]
key = "V"
mods = "Control|Shift"
action = "Paste"
EOL
    then
      echo_success "Default configuration created at $CONFIG_FILE."
    else
      echo_failure "Failed to create configuration file."
      exit 1
    fi
  fi

  echo_heading "Current configuration (located at $CONFIG_FILE):"
  cat "$CONFIG_FILE"

  echo_heading "Cleaning up build directory..."
  if rm -rf "$INSTALL_DIR/target"; then
    echo_success "Build directory removed."
  else
    echo_failure "Failed to remove build directory."
  fi

  echo_heading "Installation complete. Alacritty is ready to use with the '$DEFAULT_THEME' theme and '$DEFAULT_FONT' font."
}

main "$@"

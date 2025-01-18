#!/bin/bash
#
# This script uninstalls Alacritty and removes all related files.
# It also checks and removes Alacritty if installed via `apt`.
#
# Removes the Alacritty binary, themes, configuration, terminfo, desktop entry, and icons.

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
  INSTALL_DIR="$HOME/.config/alacritty/alacritty"
  THEME_DIR="$HOME/.config/alacritty/themes"
  CONFIG_FILE="$HOME/.config/alacritty/alacritty.toml"
  DESKTOP_FILE="$HOME/.local/share/applications/Alacritty.desktop"
  EXEC_PATH="$HOME/.local/bin/alacritty"
  ICON_PATH="$HOME/.local/share/icons/Alacritty.svg"
  TERMINFOS=( "alacritty" "alacritty-direct" )

  echo_heading "Uninstalling Alacritty..."

  # Check and remove Alacritty if installed via apt
  if dpkg -l | grep -q "^ii.*alacritty"; then
    echo_heading "Removing Alacritty installed via apt..."
    if sudo apt purge -y alacritty && sudo apt autoremove -y; then
      echo_success "Alacritty removed via apt."
    else
      echo_failure "Failed to remove Alacritty via apt."
    fi
  else
    echo_success "Alacritty is not installed via apt."
  fi

  # Remove Alacritty binary
  if [[ -f "$EXEC_PATH" ]]; then
    rm -f "$EXEC_PATH" && echo_success "Removed binary: $EXEC_PATH"
  else
    echo_success "Binary not found: $EXEC_PATH"
  fi

  # Remove source and build directory
  if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR" && echo_success "Removed source directory: $INSTALL_DIR"
  else
    echo_success "Source directory not found: $INSTALL_DIR"
  fi

  # Remove themes
  if [[ -d "$THEME_DIR" ]]; then
    rm -rf "$THEME_DIR" && echo_success "Removed themes directory: $THEME_DIR"
  else
    echo_success "Themes directory not found: $THEME_DIR"
  fi

  # Remove desktop entry
  if [[ -f "$DESKTOP_FILE" ]]; then
    rm -f "$DESKTOP_FILE" && echo_success "Removed desktop entry: $DESKTOP_FILE"
  else
    echo_success "Desktop entry not found: $DESKTOP_FILE"
  fi

  # Remove icon
  if [[ -f "$ICON_PATH" ]]; then
    rm -f "$ICON_PATH" && echo_success "Removed icon: $ICON_PATH"
  else
    echo_success "Icon not found: $ICON_PATH"
  fi

  # Remove terminfo
  echo_heading "Removing terminfo entries..."
  for TERMINFO in "${TERMINFOS[@]}"; do
    if infocmp "$TERMINFO" >/dev/null 2>&1; then
      tic -xe "$TERMINFO" /dev/null && echo_success "Removed terminfo: $TERMINFO"
    else
      echo_success "Terminfo not found: $TERMINFO"
    fi
  done

  echo_heading "Refreshing application menu..."
  if update-desktop-database "$HOME/.local/share/applications/"; then
    echo_success "Application menu refreshed."
  else
    echo_failure "Failed to refresh application menu."
  fi

  echo_heading "Uninstallation complete."
}

main "$@"

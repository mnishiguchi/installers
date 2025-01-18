#!/bin/bash
#
# This script uninstalls Ghostty and removes all related files.
#
# Removes the Ghostty binary, configuration, desktop entry, and icons.

set -eu

# Print headings
echo_heading() {
  echo -e "\n\033[34m$1\033[0m"
}

# Print success message
echo_success() {
  echo -e " \033[32m\u2714 $1\033[0m"
}

# Print failure message
echo_failure() {
  echo -e " \033[31m\u2718 $1\033[0m"
}

main() {
  INSTALL_DIR="$HOME/.config/ghostty/ghostty"
  DESKTOP_FILE="$HOME/.local/share/applications/Ghostty.desktop"
  EXEC_PATH="$HOME/.local/bin/ghostty"
  ICON_PATH="$HOME/.local/share/icons/hicolor/128x128/apps/com.mitchellh.ghostty.png"

  echo_heading "Uninstalling Ghostty..."

  # Check and remove Ghostty if installed via apt
  if dpkg -l | grep -q "^ii.*ghostty"; then
    echo_heading "Removing Ghostty installed via apt..."
    if sudo apt purge -y ghostty && sudo apt autoremove -y; then
      echo_success "Ghostty removed via apt."
    else
      echo_failure "Failed to remove Ghostty via apt."
    fi
  else
    echo_success "Ghostty is not installed via apt."
  fi

  # Remove Ghostty binary
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

  # Refresh application menu
  echo_heading "Refreshing application menu..."
  if update-desktop-database "$HOME/.local/share/applications/"; then
    echo_success "Application menu refreshed."
  else
    echo_failure "Failed to refresh application menu."
  fi

  echo_heading "Uninstallation complete."
}

main "$@"

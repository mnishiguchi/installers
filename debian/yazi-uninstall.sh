#!/bin/bash
#
# This script uninstalls Yazi and removes all related files.
# It deletes the Yazi binary, configuration files, and source directory.

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
  INSTALL_DIR="$HOME/.config/yazi/yazi"
  BIN_DIR="$HOME/.local/bin"
  EXEC_PATH_YAZI="$BIN_DIR/yazi"
  EXEC_PATH_YA="$BIN_DIR/ya"
  CONFIG_DIR="$HOME/.config/yazi"

  echo_heading "Uninstalling Yazi..."

  # Remove Yazi binaries
  if [[ -f "$EXEC_PATH_YAZI" ]]; then
    rm -f "$EXEC_PATH_YAZI" && echo_success "Removed binary: $EXEC_PATH_YAZI"
  else
    echo_success "Binary not found: $EXEC_PATH_YAZI"
  fi

  if [[ -f "$EXEC_PATH_YA" ]]; then
    rm -f "$EXEC_PATH_YA" && echo_success "Removed binary: $EXEC_PATH_YA"
  else
    echo_success "Binary not found: $EXEC_PATH_YA"
  fi

  # Remove Yazi source directory
  if [[ -d "$INSTALL_DIR" ]]; then
    rm -rf "$INSTALL_DIR" && echo_success "Removed source directory: $INSTALL_DIR"
  else
    echo_success "Source directory not found: $INSTALL_DIR"
  fi

  # Remove Yazi configuration files
  if [[ -d "$CONFIG_DIR" ]]; then
    rm -rf "$CONFIG_DIR" && echo_success "Removed configuration directory: $CONFIG_DIR"
  else
    echo_success "Configuration directory not found: $CONFIG_DIR"
  fi

  echo_heading "Uninstallation complete. If you installed Yazi using other methods, remove it manually."
}

main "$@"

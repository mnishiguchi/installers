#!/bin/bash
#
# Uninstall fzf by removing its cloned repository and configuration files.

set -eu

INSTALL_DIR="$HOME/.config/fzf"

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
  echo_heading "Uninstalling fzf..."

  # Remove the installation directory
  if [[ -d "$INSTALL_DIR" ]]; then
    if rm -rf "$INSTALL_DIR"; then
      echo_success "Removed fzf directory: $INSTALL_DIR"
    else
      echo_failure "Failed to remove fzf directory: $INSTALL_DIR"
      exit 1
    fi
  else
    echo_success "fzf directory not found: $INSTALL_DIR"
  fi

  echo_heading "Verifying fzf removal..."
  if command -v fzf &>/dev/null; then
    echo_failure "fzf is still available in PATH. You may need to remove other instances manually."
  else
    echo_success "fzf has been successfully uninstalled."
  fi
}

main "$@"

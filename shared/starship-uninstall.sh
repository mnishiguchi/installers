#!/bin/bash
#
# Uninstall Starship by removing its binary and configuration files.

set -eu

STARSHIP_BINARY_PATH="$(command -v starship || true)"
STARSHIP_CONFIG_FILE="$HOME/.config/starship.toml"

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
  echo_heading "Uninstalling Starship..."

  # Remove Starship binary
  if [[ -n "$STARSHIP_BINARY_PATH" ]]; then
    if rm -f "$STARSHIP_BINARY_PATH"; then
      echo_success "Removed Starship binary: $STARSHIP_BINARY_PATH"
    else
      echo_failure "Failed to remove Starship binary: $STARSHIP_BINARY_PATH"
      exit 1
    fi
  else
    echo_success "Starship binary not found. Skipping."
  fi

  # Remove Starship config file
  if [[ -f "$STARSHIP_CONFIG_FILE" ]]; then
    if rm -f "$STARSHIP_CONFIG_FILE"; then
      echo_success "Removed Starship config file: $STARSHIP_CONFIG_FILE"
    else
      echo_failure "Failed to remove Starship config file: $STARSHIP_CONFIG_FILE"
      exit 1
    fi
  else
    echo_success "Starship config file not found. Skipping."
  fi

  echo_heading "Verifying Starship removal..."
  if command -v starship &>/dev/null; then
    echo_failure "Starship is still available in PATH. You may need to remove other instances manually."
  else
    echo_success "Starship has been successfully uninstalled."
  fi
}

main "$@"

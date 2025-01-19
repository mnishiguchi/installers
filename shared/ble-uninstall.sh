#!/bin/bash
#
# Uninstall ble.sh by removing its repository, build files, and configuration.

set -eu

BLE_CONFIG_DIR="$HOME/.config/blesh"
BLE_DATA_DIR="$HOME/.local/share/blesh"
BLE_RC="$BLE_CONFIG_DIR/init.sh"

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
  echo_heading "Uninstalling ble.sh..."

  # Remove the repository directory
  if [[ -d "$BLE_CONFIG_DIR" ]]; then
    if rm -rf "$BLE_CONFIG_DIR"; then
      echo_success "Removed ble.sh config directory: $BLE_CONFIG_DIR"
    else
      echo_failure "Failed to remove ble.sh config directory: $BLE_CONFIG_DIR"
      exit 1
    fi
  else
    echo_success "ble.sh config directory not found: $BLE_CONFIG_DIR"
  fi

  # Remove the build directory
  if [[ -d "$BLE_DATA_DIR" ]]; then
    if rm -rf "$BLE_DATA_DIR"; then
      echo_success "Removed ble.sh data directory: $BLE_DATA_DIR"
    else
      echo_failure "Failed to remove ble.sh data directory: $BLE_DATA_DIR"
      exit 1
    fi
  else
    echo_success "ble.sh data directory not found: $BLE_DATA_DIR"
  fi

  # Remove the ble.rc file
  if [[ -f "$BLE_RC" ]]; then
    if rm "$BLE_RC"; then
      echo_success "Removed ble.rc file: $BLE_RC"
    else
      echo_failure "Failed to remove ble.rc file: $BLE_RC"
      exit 1
    fi
  else
    echo_success "ble.rc file not found: $BLE_RC"
  fi

  echo_heading "Verifying ble.sh removal..."
  if [[ -f "$BLE_SCRIPT" ]]; then
    echo_failure "ble.sh script still exists. You may need to manually remove it."
  else
    echo_success "ble.sh has been successfully uninstalled."
  fi
}

main "$@"

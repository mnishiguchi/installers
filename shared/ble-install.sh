#!/bin/bash
#
# Install ble.sh by cloning its repository and building it.

set -eu

BLE_REPO="https://github.com/akinomyoga/ble.sh.git"
BLE_CONFIG_DIR="$HOME/.config/blesh"
BLE_DATA_DIR="$HOME/.local/share/blesh"
BLE_SCRIPT="$BLE_DATA_DIR/ble.sh"
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
  echo_heading "Installing ble.sh..."

  # Clone the repository if not already cloned
  if [[ -d "$BLE_CONFIG_DIR" ]]; then
    echo_success "ble.sh is already cloned in $BLE_CONFIG_DIR."
  else
    if git clone --recursive --depth 1 --shallow-submodules "$BLE_REPO" "$BLE_CONFIG_DIR"; then
      echo_success "Cloned ble.sh repository."
    else
      echo_failure "Failed to clone ble.sh repository."
      exit 1
    fi
  fi

  # Build and install
  if [[ -d "$BLE_DATA_DIR" ]]; then
    echo_success "ble.sh is already built in $BLE_DATA_DIR."
  else
    if make --directory "$BLE_CONFIG_DIR" install; then
      echo_success "Built and installed ble.sh."
    else
      echo_failure "Failed to build and install ble.sh."
      exit 1
    fi
  fi

  # Create the ble.rc file if missing
  if [[ -f "$BLE_RC" ]]; then
    echo_success "ble.rc already exists at $BLE_RC."
  else
    echo "Creating ble.rc at $BLE_RC..."
    cat <<EOF >"$BLE_RC"
# https://github.com/akinomyoga/ble.sh/blob/master/blerc.template
# fzf integration
ble-import -d integration/fzf-completion
ble-import -d integration/fzf-key-bindings

# disable the bell
bleopt edit_abell=
bleopt edit_vbell=

# delay to start auto-completion after last input
bleopt complete_auto_delay=300

# timeout for pathname expansions in auto-complete
bleopt complete_timeout_auto=500

# limit data structures in completion process
bleopt complete_limit=2000
bleopt complete_limit_auto=2000
EOF
    echo_success "Created ble.rc."
  fi

  echo_heading "Verifying ble.sh installation..."
  if [[ -f "$BLE_SCRIPT" ]]; then
    echo_success "ble.sh is ready to use!"
  else
    echo_failure "Something went wrong: ble.sh script not found."
    exit 1
  fi
}

main "$@"

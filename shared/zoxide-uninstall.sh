#!/bin/bash
#
# Uninstall zoxide by removing its binary and related files.

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
  echo_heading "Uninstalling zoxide..."

  # Locate zoxide binary
  ZOXIDE_PATH="$(command -v zoxide || true)"
  if [[ -n "$ZOXIDE_PATH" ]]; then
    if rm -f "$ZOXIDE_PATH"; then
      echo_success "Removed zoxide binary: $ZOXIDE_PATH"
    else
      echo_failure "Failed to remove zoxide binary: $ZOXIDE_PATH"
      exit 1
    fi
  else
    echo_success "zoxide binary not found. Skipping."
  fi

  # Remove configuration files if any (e.g., ~/.zoxide.zsh)
  CONFIG_FILES=("$HOME/.zoxide.zsh")
  for config in "${CONFIG_FILES[@]}"; do
    if [[ -f "$config" ]]; then
      if rm "$config"; then
        echo_success "Removed config file: $config"
      else
        echo_failure "Failed to remove config file: $config"
      fi
    else
      echo_success "Config file not found: $config"
    fi
  done

  echo_heading "Verifying zoxide removal..."
  if command -v zoxide &>/dev/null; then
    echo_failure "zoxide is still available in PATH. You may need to manually remove other instances."
  else
    echo_success "zoxide has been successfully uninstalled."
  fi

  echo_heading "Uninstallation complete."
}

main "$@"

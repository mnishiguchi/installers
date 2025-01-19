#!/bin/bash
#
# Install zoxide from its official installation script.

set -eu

ZOXIDE_INSTALL_URL="https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh"

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
  echo_heading "Installing zoxide..."

  if command -v zoxide &>/dev/null; then
    echo_success "zoxide is already installed."
  else
    # Use curl to fetch and execute the installation script
    if curl -sS "$ZOXIDE_INSTALL_URL" | bash; then
      echo_success "zoxide installation completed successfully."
    else
      echo_failure "Failed to install zoxide."
      exit 1
    fi
  fi

  echo_heading "Verifying zoxide installation..."
  if command -v zoxide &>/dev/null; then
    echo_success "zoxide is ready to use!"
  else
    echo_failure "Something went wrong: zoxide is not available."
    exit 1
  fi
}

main "$@"

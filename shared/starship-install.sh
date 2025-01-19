#!/bin/bash
#
# Install Starship by downloading its installation script and running it.

set -eu

STARSHIP_INSTALL_URL="https://starship.rs/install.sh"

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
  echo_heading "Installing Starship..."

  if command -v starship &>/dev/null; then
    echo_success "Starship is already installed."
  else
    # Use curl to fetch and execute the installation script
    if curl -sS "$STARSHIP_INSTALL_URL" | sh; then
      echo_success "Starship installation completed successfully."
    else
      echo_failure "Failed to install Starship."
      exit 1
    fi
  fi

  echo_heading "Verifying Starship installation..."
  if command -v starship &>/dev/null; then
    echo_success "Starship is ready to use!"
  else
    echo_failure "Something went wrong: Starship is not available."
    exit 1
  fi
}

main "$@"

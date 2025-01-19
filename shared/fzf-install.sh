#!/bin/bash
#
# Install fzf by cloning its repository and running the installation script.

set -eu

FZF_REPO="https://github.com/junegunn/fzf.git"
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
  echo_heading "Installing fzf..."

  if [[ -d "$INSTALL_DIR" ]]; then
    echo_success "fzf is already installed in $INSTALL_DIR."
  else
    mkdir -p "$(dirname "$INSTALL_DIR")"
    if git clone --depth 1 "$FZF_REPO" "$INSTALL_DIR"; then
      echo_success "Cloned fzf repository."
      if "$INSTALL_DIR/install" --xdg; then
        echo_success "fzf installation completed successfully."
      else
        echo_failure "Failed to run the fzf installation script."
        exit 1
      fi
    else
      echo_failure "Failed to clone fzf repository."
      exit 1
    fi
  fi

  echo_heading "Verifying fzf installation..."
  if command -v fzf &>/dev/null; then
    echo_success "fzf is ready to use!"
  else
    echo_failure "Something went wrong: fzf is not available."
    exit 1
  fi
}

main "$@"

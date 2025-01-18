#!/bin/bash
#
# Install diff-so-fancy from source and symlink to ~/.local/bin
#

set -eu

DSF_REPO="https://github.com/so-fancy/diff-so-fancy.git"
INSTALL_DIR="$HOME/.config/diff-so-fancy"
EXEC_PATH="$HOME/.local/bin/diff-so-fancy"

echo_heading() {
  echo -e "\n\033[34m$1\033[0m"
}
echo_success() {
  echo -e " \033[32m✔ $1\033[0m"
}
echo_failure() {
  echo -e " \033[31m✖ $1\033[0m"
}

main() {
  echo_heading "Cloning or updating diff-so-fancy..."
  mkdir -p "$(dirname "$INSTALL_DIR")"
  if [[ -d "$INSTALL_DIR" ]]; then
    cd "$INSTALL_DIR"
    if git pull; then
      echo_success "Updated diff-so-fancy source."
    else
      echo_failure "Failed to update diff-so-fancy."
      exit 1
    fi
  else
    if git clone "$DSF_REPO" "$INSTALL_DIR"; then
      echo_success "Cloned diff-so-fancy repository."
    else
      echo_failure "Failed to clone diff-so-fancy."
      exit 1
    fi
  fi

  echo_heading "Setting up symlink in ~/.local/bin..."
  mkdir -p "$HOME/.local/bin"
  # Remove existing symlink if present
  if [[ -L "$EXEC_PATH" ]]; then
    rm "$EXEC_PATH"
  fi
  # Symlink the script so it can find lib/ relatively
  if ln -s "$INSTALL_DIR/diff-so-fancy" "$EXEC_PATH"; then
    chmod +x "$INSTALL_DIR/diff-so-fancy"
    echo_success "Symlinked diff-so-fancy to $EXEC_PATH."
  else
    echo_failure "Failed to symlink diff-so-fancy."
    exit 1
  fi

  echo_heading "Validating diff-so-fancy..."
  if command -v diff-so-fancy >/dev/null 2>&1; then
    echo_success "diff-so-fancy is ready to use!"
  else
    echo_failure "Something went wrong: can't run diff-so-fancy."
    exit 1
  fi
}

main "$@"

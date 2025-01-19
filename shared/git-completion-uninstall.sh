#!/bin/bash
#
# Uninstall Git Completion by removing the script from its directory.

set -eu

INSTALL_DIR="$HOME/.config/git"
GIT_COMPLETION_SCRIPT="$INSTALL_DIR/git-completion.bash"

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
  echo_heading "Uninstalling Git Completion..."

  if [[ -f "$GIT_COMPLETION_SCRIPT" ]]; then
    if rm -f "$GIT_COMPLETION_SCRIPT"; then
      echo_success "Removed Git Completion script: $GIT_COMPLETION_SCRIPT"
    else
      echo_failure "Failed to remove Git Completion script: $GIT_COMPLETION_SCRIPT"
      exit 1
    fi
  else
    echo_success "Git Completion script not found: $GIT_COMPLETION_SCRIPT"
  fi

  # Remove the directory if empty
  if [[ -d "$INSTALL_DIR" && -z "$(ls -A "$INSTALL_DIR")" ]]; then
    if rmdir "$INSTALL_DIR"; then
      echo_success "Removed empty directory: $INSTALL_DIR"
    else
      echo_failure "Failed to remove directory: $INSTALL_DIR"
      exit 1
    fi
  else
    echo_success "Directory not empty or already removed: $INSTALL_DIR"
  fi

  echo_heading "Verifying Git Completion removal..."
  if [[ -f "$GIT_COMPLETION_SCRIPT" ]]; then
    echo_failure "Git Completion script still exists. You may need to remove it manually."
  else
    echo_success "Git Completion has been successfully uninstalled."
  fi
}

main "$@"

#!/bin/bash
#
# This script uninstalls diff-so-fancy by removing the symlink in ~/.local/bin
# and the cloned repo in ~/.config/diff-so-fancy.
# It also shows the current Git config for core.pager and interactive.diffFilter
# and verifies that the `diff-so-fancy` command is no longer found in $PATH.

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
  INSTALL_DIR="$HOME/.config/diff-so-fancy"
  EXEC_PATH="$HOME/.local/bin/diff-so-fancy"

  echo_heading "Uninstalling diff-so-fancy..."

  # Remove symlink in ~/.local/bin
  if [[ -L "$EXEC_PATH" ]]; then
    if rm "$EXEC_PATH"; then
      echo_success "Removed symlink: $EXEC_PATH"
    else
      echo_failure "Failed to remove symlink: $EXEC_PATH"
    fi
  else
    echo_success "Symlink not found: $EXEC_PATH"
  fi

  # Remove the cloned repo from ~/.config/diff-so-fancy
  if [[ -d "$INSTALL_DIR" ]]; then
    if rm -rf "$INSTALL_DIR"; then
      echo_success "Removed directory: $INSTALL_DIR"
    else
      echo_failure "Failed to remove directory: $INSTALL_DIR"
    fi
  else
    echo_success "Directory not found: $INSTALL_DIR"
  fi

  # Check if diff-so-fancy still exists in $PATH
  echo_heading "Verifying command availability..."
  if command -v diff-so-fancy &>/dev/null; then
    echo_failure "diff-so-fancy is still found in your PATH!"
    echo "There may be another installation or leftover symlink. You may need to remove it manually."
  else
    echo_success "diff-so-fancy is no longer on your PATH."
  fi

  # Show current Git config (if user wants to remove references manually)
  echo_heading "Checking Git config (if configured for diff-so-fancy):"
  current_pager="$(git config --global core.pager 2>/dev/null || true)"
  current_diff_filter="$(git config --global interactive.diffFilter 2>/dev/null || true)"

  echo "  - Git core.pager:             '${current_pager}'"
  echo "  - Git interactive.diffFilter: '${current_diff_filter}'"

  echo_heading "If these entries reference diff-so-fancy, you may want to remove them manually, e.g.:"
  echo "  git config --global --unset core.pager"
  echo "  git config --global --unset interactive.diffFilter"

  echo_heading "Uninstallation complete."
}

main "$@"

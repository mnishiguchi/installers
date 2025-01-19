#!/bin/bash
#
# Install Git Completion by downloading the script from the official Git repository.

set -eu

GIT_COMPLETION_URL="https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash"
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
  echo_heading "Installing Git Completion..."

  mkdir -p "$INSTALL_DIR"
  if curl -L "$GIT_COMPLETION_URL" -o "$GIT_COMPLETION_SCRIPT"; then
    echo_success "Downloaded git-completion script to $GIT_COMPLETION_SCRIPT."
  else
    echo_failure "Failed to download git-completion script."
    exit 1
  fi

  echo_heading "Verifying Git Completion installation..."
  if [[ -f "$GIT_COMPLETION_SCRIPT" ]]; then
    echo_success "Git Completion script is ready to use!"
  else
    echo_failure "Something went wrong: Git Completion script is not available."
    exit 1
  fi
}

main "$@"

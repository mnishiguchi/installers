#!/bin/bash
#
# Interactive Git Configuration Script
# Sets up essential Git global defaults with optional customization.

set -eu

# Print headings
# Usage: echo_heading "Your heading text"
echo_heading() {
  echo -e "\n\033[34m$1\033[0m"
}

# Print success messages
# Usage: echo_success "Your success message"
echo_success() {
  echo -e " \033[32m✔ $1\033[0m"
}

# Print warning messages
# Usage: echo_warning "Your warning message"
echo_warning() {
  echo -e " \033[33m⚠ $1\033[0m"
}

# Prompt user input with a default value
# Usage: prompt_input "Prompt message" "Default value"
prompt_input() {
  local prompt_message="$1"
  local default_value="$2"
  local user_input

  read -r -p "$prompt_message [$default_value]: " user_input
  echo "${user_input:-$default_value}"
}

# Generate Git configuration
# Configures essential settings and provides interactive prompts for customization.
generate_git_config() {
  echo_heading "Configuring Git settings..."

  if ! command -v git >/dev/null 2>&1; then
    echo_warning "git is not installed."
    exit 1
  fi

  # Prompt for user information
  current_name="$(git config --global user.name 2>/dev/null || true)"
  current_email="$(git config --global user.email 2>/dev/null || true)"
  GIT_USER_NAME=$(prompt_input "Enter your Git user.name" "${current_name:-$USER}")
  GIT_USER_EMAIL=$(prompt_input "Enter your Git user.email" "${current_email:-$USER@$(hostname -s)}")

  # Apply essential Git configurations
  git config --global user.name "$GIT_USER_NAME"
  git config --global user.email "$GIT_USER_EMAIL"
  git config --global init.defaultBranch "main"
  git config --global fetch.prune true
  git config --global advice.detachedHead false
  git config --global core.ignorecase false
  git config --global core.longpaths true

  # Prompt for core.editor
  GIT_EDITOR=$(prompt_input "Enter your preferred editor for Git (e.g., nano, vim)" "nano")
  git config --global core.editor "$GIT_EDITOR"
  echo_success "Set core.editor to $GIT_EDITOR."

  echo_success "Basic Git settings configured."

  # Configure Git credential helper
  echo_heading "Configuring Git credential helper..."

  if [[ "$(uname)" == "Darwin" ]]; then
    git config --global credential.helper "osxkeychain"
    echo_success "Set credential.helper to osxkeychain for macOS."
  elif [[ "$(uname)" == "Linux" ]]; then
    if command -v git-credential-manager >/dev/null; then
      git config --global credential.helper "manager"
      echo_success "Set credential.helper to manager for Linux."
    elif command -v git-credential-libsecret >/dev/null; then
      git config --global credential.helper "libsecret"
      echo_success "Set credential.helper to libsecret for Linux."
    else
      echo_warning "No secure Git credential helper found; left credential.helper unchanged."
    fi
  elif [[ "$(uname)" =~ MINGW|CYGWIN|MSYS ]]; then
    git config --global credential.helper "manager"
    echo_success "Set credential.helper to manager for Windows."
  else
    echo_warning "No credential helper configured for this platform."
  fi
}

# Main function
# Starts the Git configuration process.
main() {
  echo_heading "Starting Git configuration script..."
  generate_git_config
  echo_heading "Git configuration completed successfully."
}

# Run the script
main "$@"

#!/usr/bin/env bash
#
# Uninstall Visual Studio Code from a Debian-based system.
#
# - Removes the "code" package via apt-get purge
# - Optionally removes leftover user config/cache/extension directories
# - Optionally cleans up the VS Code APT repository files (if present)
#
set -euo pipefail

echo_heading() { echo -e "\n\033[34m$1\033[0m"; }
echo_success() { echo -e " \033[32m✔ $1\033[0m"; }
echo_warn() { echo -e " \033[33m▲ $1\033[0m"; }
echo_failure() { echo -e " \033[31m✖ $1\033[0m"; }

prompt_yes_no() {
  # Usage: prompt_yes_no "Question [y/N] "
  local prompt="${1:-Continue? [y/N] }"
  local reply

  read -r -p "${prompt}" reply
  case "${reply}" in
  [Yy]*)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

is_code_installed() {
  if dpkg -s code >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

remove_package() {
  echo_heading "Removing VS Code package (code)..."

  if ! command -v apt-get >/dev/null 2>&1; then
    echo_failure "apt-get not found. This script assumes a Debian-based system."
    exit 1
  fi

  if sudo apt-get -y purge code; then
    echo_success "Removed package 'code'."
  else
    echo_failure "Failed to purge package 'code'."
    exit 1
  fi

  echo_heading "Autoremoving unused dependencies..."
  if sudo apt-get -y autoremove; then
    echo_success "apt-get autoremove completed."
  else
    echo_warn "apt-get autoremove reported issues. You may want to check manually."
  fi
}

remove_user_data() {
  echo_heading "Removing user-level VS Code data..."

  # Common directories used by VS Code / code-server variants.
  paths_to_remove=(
    "${HOME}/.config/Code"
    "${HOME}/.cache/Code"
    "${HOME}/.local/share/Code"
    "${HOME}/.vscode"
    "${HOME}/.vscode-server"
  )

  for path in "${paths_to_remove[@]}"; do
    if [ -e "${path}" ]; then
      echo_warn "Removing: ${path}"
      rm -rf "${path}"
    fi
  done

  echo_success "User-level data removal complete (where present)."
}

remove_repo_files() {
  echo_heading "Checking for VS Code APT repository files..."

  local repo_list="/etc/apt/sources.list.d/vscode.list"
  local keyring="/etc/apt/keyrings/packages.microsoft.gpg"
  local old_keyring="/etc/apt/trusted.gpg.d/microsoft.gpg"

  local changed="no"

  if [ -f "${repo_list}" ]; then
    echo_warn "Removing APT source: ${repo_list}"
    sudo rm -f "${repo_list}"
    changed="yes"
  fi

  if [ -f "${keyring}" ]; then
    echo_warn "Removing keyring: ${keyring}"
    sudo rm -f "${keyring}"
    changed="yes"
  fi

  if [ -f "${old_keyring}" ]; then
    echo_warn "Removing legacy keyring: ${old_keyring}"
    sudo rm -f "${old_keyring}"
    changed="yes"
  fi

  if [ "${changed}" = "yes" ]; then
    echo_heading "Updating APT package lists..."
    if sudo apt-get update; then
      echo_success "APT lists updated."
    else
      echo_warn "Failed to update APT lists. You may want to run 'sudo apt-get update' manually."
    fi
  else
    echo_success "No VS Code-specific APT repo files found."
  fi
}

verify_uninstall() {
  echo_heading "Verifying uninstallation..."

  if is_code_installed; then
    echo_warn "Package 'code' still appears to be installed."
  else
    echo_success "Package 'code' is no longer installed."
  fi

  if command -v code >/dev/null 2>&1; then
    echo_warn "'code' command is still on PATH (maybe another installation or leftover symlink)."
  else
    echo_success "'code' command is no longer found on PATH in this shell."
  fi
}

main() {
  echo_heading "VS Code uninstall helper"

  echo_heading "Checking current installation status..."
  if is_code_installed; then
    echo_success "Package 'code' is currently installed."

    if prompt_yes_no "Purge the 'code' package via apt-get? [y/N] "; then
      remove_package
    else
      echo_heading "Skipping package removal as requested."
    fi
  else
    echo_warn "Package 'code' does not appear to be installed."
  fi

  if prompt_yes_no "Remove user-level VS Code settings, caches, and extensions? [y/N] "; then
    remove_user_data
  else
    echo_heading "Keeping user-level data."
  fi

  if prompt_yes_no "Remove VS Code APT repository entries and keys (if present)? [y/N] "; then
    remove_repo_files
  else
    echo_heading "Keeping any existing VS Code APT repository configuration."
  fi

  verify_uninstall

  echo_heading "Done."
}

main "$@"

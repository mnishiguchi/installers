#!/usr/bin/env bash
#
# Install or update Visual Studio Code (.deb) on Debian-based systems.
#
# - Detects architecture (amd64/arm64/armhf)
# - Downloads the right .deb from the official VS Code site
# - Installs via dpkg and fixes dependencies with apt-get if needed
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

ensure_package_manager_free() {
  echo_heading "Checking package manager status..."

  # Look for common package-manager processes.
  if pgrep -x apt-get >/dev/null 2>&1 ||
    pgrep -x apt >/dev/null 2>&1 ||
    pgrep -x dpkg >/dev/null 2>&1 ||
    pgrep -x unattended-upgrade >/dev/null 2>&1; then
    echo_failure "Another package manager process (apt/dpkg) appears to be running."
    echo "Please let that finish (or close any GUI updater), then rerun this script."
    exit 1
  fi

  echo_success "No conflicting apt/dpkg processes detected."
}

detect_vscode_os_arch() {
  # Returns the os parameter segment used by VS Code download URLs
  #   linux-deb-x64 / linux-deb-arm64 / linux-deb-armhf
  local arch

  if command -v dpkg >/dev/null 2>&1; then
    arch="$(dpkg --print-architecture)"
  else
    arch="$(uname -m)"
  fi

  case "${arch}" in
  amd64 | x86_64)
    echo "linux-deb-x64"
    ;;
  arm64 | aarch64)
    echo "linux-deb-arm64"
    ;;
  armhf | armv7l)
    echo "linux-deb-armhf"
    ;;
  *)
    echo_failure "Unsupported architecture: ${arch}"
    echo "This script currently supports: amd64, arm64, armhf."
    exit 1
    ;;
  esac
}

download_deb() {
  local url="$1"
  local dest="$2"

  echo_heading "Downloading VS Code package..."
  echo "URL: ${url}"

  if command -v curl >/dev/null 2>&1; then
    if curl -L --fail -o "${dest}" "${url}"; then
      echo_success "Downloaded to: ${dest}"
    else
      echo_failure "Failed to download VS Code via curl."
      exit 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if wget -O "${dest}" "${url}"; then
      echo_success "Downloaded to: ${dest}"
    else
      echo_failure "Failed to download VS Code via wget."
      exit 1
    fi
  else
    echo_failure "Neither curl nor wget found. Please install one of them and retry."
    exit 1
  fi
}

install_deb() {
  local deb_path="$1"

  echo_heading "Installing VS Code with dpkg..."
  if ! command -v dpkg >/dev/null 2>&1; then
    echo_failure "dpkg not found. This script assumes a Debian-based system."
    exit 1
  fi

  # Double-check no package manager is running right before dpkg.
  ensure_package_manager_free

  if sudo dpkg -i "${deb_path}"; then
    echo_success "dpkg install completed."
    return
  fi

  echo_warn "dpkg reported issues (possibly missing dependencies)."

  if ! command -v apt-get >/dev/null 2>&1; then
    echo_failure "apt-get not found. Cannot automatically fix dependencies."
    exit 1
  fi

  echo_heading "Fixing dependencies with apt-get..."
  # Check again before using apt-get in case something started meanwhile.
  ensure_package_manager_free

  if sudo apt-get -y -f install; then
    echo_success "Dependencies installed successfully."
  else
    echo_failure "Failed to fix dependencies with apt-get."
    echo "You may need to inspect the situation manually."
    exit 1
  fi
}

verify_install() {
  echo_heading "Verifying 'code' command..."
  if command -v code >/dev/null 2>&1; then
    local version
    version="$(code --version | head -n 1 || true)"
    echo_success "VS Code is available as 'code' (version: ${version})."
    echo "Try:  code ."
  else
    echo_warn "VS Code seems installed, but 'code' is not on PATH in this shell."
    echo "You may need to open a new terminal or log out/in."
  fi
}

main() {
  echo_heading "Checking existing VS Code installation..."
  if command -v code >/dev/null 2>&1; then
    installed_version="$(code --version | head -n 1)"
    echo_warn "VS Code already installed (version: ${installed_version})."

    if ! prompt_yes_no "Reinstall / update from official .deb? [y/N] "; then
      echo_heading "Nothing to do."
      exit 0
    fi
  fi

  # Before doing anything heavy, ensure apt/dpkg is idle.
  ensure_package_manager_free

  echo_heading "Detecting architecture..."
  os_arch="$(detect_vscode_os_arch)"
  echo_success "Detected VS Code build: ${os_arch}"

  download_url="https://code.visualstudio.com/sha/download?build=stable&os=${os_arch}"

  tmp_dir="$(mktemp -d)"
  deb_path="${tmp_dir}/code.deb"

  download_deb "${download_url}" "${deb_path}"
  install_deb "${deb_path}"

  echo_heading "Cleaning up temporary files..."
  rm -rf "${tmp_dir}"
  echo_success "Temporary files removed."

  verify_install

  echo_heading "Done."
}

main "$@"

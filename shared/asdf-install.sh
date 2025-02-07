#!/usr/bin/env bash

set -euo pipefail

ASDF_REPO="https://github.com/asdf-vm/asdf.git"
ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"
ASDF_BIN_DIR="$ASDF_DATA_DIR/bin"
TOOL_VERSIONS_FILE="$HOME/.tool-versions"

echo_heading() { echo -e "\n\033[34m$1\033[0m"; }
echo_success() { echo -e " \033[32m✔ $1\033[0m"; }
echo_warning() { echo -e " \033[33m⚠ $1\033[0m"; }
echo_failure() { echo -e " \033[31m✖ $1\033[0m"; }

install_asdf() {
  echo_heading "Installing asdf"
  if [[ -d "$ASDF_DATA_DIR"/.git ]]; then
    cd "$ASDF_DATA_DIR"
    git fetch --tags
    git reset --hard # Ensure no local changes interfere
    git clean -fd    # Remove untracked files
    git checkout "$ASDF_VERSION"
  else
    rm -rf "$ASDF_DATA_DIR"
    git clone "$ASDF_REPO" "$ASDF_DATA_DIR" --branch "$ASDF_VERSION"
    echo_success "asdf installed at $ASDF_DATA_DIR."
  fi

  case "$ASDF_VERSION" in
  v0.13.* | v0.14.* | v0.15.*) ;;
  *)
    echo_heading "Installing asdf binary version $ASDF_VERSION"
    DOWNLOAD_URL="https://github.com/asdf-vm/asdf/releases/download/$ASDF_VERSION/asdf-$ASDF_VERSION-linux-amd64.tar.gz"
    TEMP_DIR=$(mktemp -d)

    curl -fLo "$TEMP_DIR/asdf.tar.gz" "$DOWNLOAD_URL" || {
      echo_failure "Failed to download asdf binary. Please check the URL: $DOWNLOAD_URL"
      exit 1
    }

    tar -xzf "$TEMP_DIR/asdf.tar.gz" -C "$TEMP_DIR"
    if [[ ! -f "$TEMP_DIR/asdf" ]]; then
      echo_failure "Extracted asdf binary not found. Something went wrong."
      exit 1
    fi

    mv "$TEMP_DIR/asdf" "$ASDF_BIN_DIR/asdf"
    chmod +x "$ASDF_BIN_DIR/asdf"
    rm -rf "$TEMP_DIR"

    if ! file "$ASDF_BIN_DIR/asdf" | grep -q 'ELF\|Mach-O'; then
      echo_failure "Downloaded asdf binary is not valid. Please check the download URL: $DOWNLOAD_URL"
      exit 1
    fi

    echo_success "asdf binary installed at $ASDF_BIN_DIR/asdf"
    ;;
  esac
}

choose_asdf_version() {
  echo_heading "Fetching available asdf versions..."
  AVAILABLE_VERSIONS=$(git ls-remote --tags --refs "$ASDF_REPO" | awk -F'/' '{print $3}' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -Vr | head -n 10)

  if [[ -z "$AVAILABLE_VERSIONS" ]]; then
    echo_failure "Failed to fetch versions from Git repository."
    exit 1
  fi

  echo "Available asdf versions:"
  echo "$AVAILABLE_VERSIONS" | nl

  read -p "Enter the number of the version you want to install: " VERSION_INDEX
  ASDF_VERSION=$(echo "$AVAILABLE_VERSIONS" | sed -n "${VERSION_INDEX}p")

  if [[ -z "$ASDF_VERSION" ]]; then
    echo_failure "Invalid selection. Exiting."
    exit 1
  fi

  echo_success "Selected asdf version: ${ASDF_VERSION}"
}

get_installed_asdf_version() {
  if ! command -v asdf >/dev/null 2>&1; then
    echo "not_installed"
    return
  fi

  local version_output=$(asdf --version)
  if [[ "$version_output" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9]+)?$ ]]; then
    echo "$version_output"
  elif [[ "$version_output" =~ v([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    echo "v${BASH_REMATCH[1]}"
  else
    echo "unknown"
  fi
}

main() {
  choose_asdf_version

  if [[ "$(get_installed_asdf_version)" == "$ASDF_VERSION" ]]; then
    echo_success "asdf $ASDF_VERSION is already installed. Skipping installation."
    exit 0
  fi

  install_asdf

  echo_heading "Validating asdf installation..."
  if command -v asdf >/dev/null 2>&1; then
    echo_success "asdf is installed and ready to use!"
  else
    echo_failure "Something went wrong: can't run asdf."
    exit 1
  fi

  echo_heading "Final installed asdf"
  asdf info
  echo
  asdf list

  echo_heading "Setup Reminder"
  cat <<EOF
asdf is installed, but you need to configure your shell:

Add the following lines to your shell config (.bashrc, .zshrc, etc.):

  export PATH=\"$ASDF_BIN_DIR:\$PATH\""

Restart your shell or run: exec \$SHELL
EOF
}

main "$@"

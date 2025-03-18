#!/bin/bash
#
# This script automates the installation and setup of Yazi from source.
# It ensures Rust is installed, updates Rust, builds Yazi (if needed),
# installs the binaries, and downloads Yazi flavors.
#
# Prerequisites: Rust, Git, and required dependencies.
#
set -eu

echo_heading() {
  echo -e "\n\033[34m$1\033[0m"
}

echo_success() {
  echo -e " \033[32m✔ $1\033[0m"
}

echo_failure() {
  echo -e " \033[31m✖ $1\033[0m"
}

check_rust() {
  echo_heading "Checking Rust installation..."
  if command -v cargo >/dev/null 2>&1; then
    echo_success "Rust is installed."
  else
    echo_failure "Rust is not installed. Please install Rust and retry."
    exit 1
  fi
}

update_rust() {
  echo_heading "Updating Rust..."
  if rustup update; then
    echo_success "Rust updated."
  else
    echo_failure "Failed to update Rust."
    exit 1
  fi
}

install_dependencies() {
  echo_heading "Installing dependencies..."
  if sudo apt update && sudo apt install -y gcc cmake pkg-config libxcb-shape0-dev libxcb-xfixes0-dev; then
    echo_success "Dependencies installed."
  else
    echo_failure "Failed to install dependencies."
    exit 1
  fi
}

clone_minimally() {
  local repo_url=$1
  local dest_dir=$2

  if [[ -d "$dest_dir" ]]; then
    echo_heading "$dest_dir exists. Removing old version."
    rm -rf "$dest_dir"
  fi

  git clone --depth=1 --no-checkout "$repo_url" "$dest_dir"
  cd "$dest_dir"
  git checkout HEAD -- .
  rm -rf .git
}

install_yazi() {
  local install_dir="$HOME/.config/yazi/yazi"
  local bin_dir="$HOME/.local/bin"

  if command -v yazi >/dev/null 2>&1; then
    echo_success "Yazi is already installed. Skipping build step."
    return
  fi

  echo_heading "Setting up Yazi source code..."
  clone_minimally "https://github.com/sxyazi/yazi.git" "$install_dir"

  echo_heading "Building Yazi..."
  cd "$install_dir"
  if cargo build --release; then
    echo_success "Yazi built successfully."
  else
    echo_failure "Failed to build Yazi."
    exit 1
  fi

  echo_heading "Installing Yazi binaries..."
  mkdir -p "$bin_dir"
  if cp "$install_dir/target/release/yazi" "$install_dir/target/release/ya" "$bin_dir/"; then
    echo_success "Yazi binaries installed at $bin_dir."
  else
    echo_failure "Failed to install Yazi binaries."
    exit 1
  fi

  echo_heading "Cleaning up Yazi source..."
  if rm -rf "$install_dir"; then
    echo_success "Removed Yazi source directory: $install_dir"
  else
    echo_failure "Failed to remove Yazi source directory."
  fi
}

install_flavors() {
  echo_heading "Downloading Yazi Flavors..."
  clone_minimally "https://github.com/yazi-rs/flavors.git" "$HOME/.config/yazi/flavors"
  echo_success "Cloned Yazi Flavors minimally."
}

main() {
  check_rust
  update_rust
  install_dependencies
  install_yazi
  install_flavors
  echo_heading "Installation complete. You can now run Yazi using 'yazi' or 'ya'."
}

main "$@"

#!/usr/bin/env bash
set -eu

# Install ohmyzsh following the official documentation.
# https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH

need() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: need $1 (command not found)"
  fi
}

# Dependencies
need curl
need zsh

zsh_path="$(command -v zsh)"

echo "ZSH info"
echo "  path:    $zsh_path"
echo "  version: $("$zsh_path" --version)"

if ! grep "$zsh_path" /etc/shells &>/dev/null; then
  echo "Adding '$zsh_path' to /etc/shells"
  sudo bash -c "echo $zsh_path >> /etc/shells"
fi

echo "Changing your shell to zsh"
sudo chsh -s "$zsh_path" "$USER"

if [[ -d "$ZSH" ]]; then
  echo "ohmyzsh is already installed"
  exit 0
fi

echo "Installing ohmyzsh"
# https://ohmyz.sh/#install
# https://github.com/ohmyzsh/ohmyzsh/tree/master#unattended-install
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

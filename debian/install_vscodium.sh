#!/usr/bin/env bash
set -eu

if command -v codium &>/dev/null; then
  echo "warning: already installed -- skipping"
  exit 0
fi

# Add the GPG key of the repository
wget -qO - https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg |
  gpg --dearmor |
  sudo dd of=/usr/share/keyrings/vscodium-archive-keyring.gpg

# Add the repository
echo 'deb [ signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg ] https://download.vscodium.com/debs vscodium main' |
  sudo tee /etc/apt/sources.list.d/vscodium.list

# Update then install vscodium
sudo apt update && sudo apt install codium

#!/bin/sh
set -e

echo "==> Installing VS Code"

# install dependencies
sudo apt install wget -y

# find the code command binary
command -v code
exit_code=$?

if [ "$exit_code" -eq 0 ] ; then
  echo "vs code is already installed"
else
  wget -O code.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-arm64"
  sudo dpkg -i code.deb
  rm code.deb
fi

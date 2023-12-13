#!/bin/bash
set -e

if command -v code &>/dev/null; then
  echo "warning: already installed -- skipping"
  exit 0
fi

wget -O code.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-arm64"
sudo dpkg -i code.deb
rm code.deb

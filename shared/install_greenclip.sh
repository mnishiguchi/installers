#!/usr/bin/env bash
set -eu

if command -v greenclip &>/dev/null; then
  echo "greenclip already installed"
  exit 1
fi

LOCAL_BIN_DIR="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN_DIR"
wget https://github.com/erebe/greenclip/releases/download/v4.2/greenclip -P "$LOCAL_BIN_DIR"
chmod +x "$LOCAL_BIN_DIR/greenclip"

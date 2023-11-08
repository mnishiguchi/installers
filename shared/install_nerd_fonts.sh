#!/bin/bash
set -e

if fc-list | grep -q FiraCodeNerdFont; then
  echo "warning: already installed -- skipping"
else
  FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/FiraCode.zip"
  OUTPUT_DIR="$HOME/.local/share/fonts/firacode-nerd"

  if mkdir -p "$OUTPUT_DIR" && cd "$OUTPUT_DIR" &>/dev/null; then
    curl --fail --location "$FONT_URL" --output tmp.zip
    unzip tmp.zip
    rm -f tmp.zip
  else
    echo "warning: could not install"
  fi
fi

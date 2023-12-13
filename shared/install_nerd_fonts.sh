#!/bin/bash
set -e

FONT_NAME=FiraCodeNerdFont
FONT_SOURCE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/FiraCode.zip"
FONT_TARGET_DIR="$HOME/.local/share/fonts/$FONT_NAME"

if fc-list | grep -q "$FONT_NAME"; then
  echo "warning: already installed -- skipping"
  exit 0
fi

(
  mkdir -p "$FONT_TARGET_DIR" && cd "$FONT_TARGET_DIR"
  curl --fail --location "$FONT_SOURCE_URL" --output tmp.zip
  unzip tmp.zip
  rm -f tmp.zip
)

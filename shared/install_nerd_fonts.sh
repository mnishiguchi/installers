#!/usr/bin/env bash
set -eu

font_name=FiraCodeNerdFont
font_source_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/FiraCode.zip"
font_target_dir="$HOME/.local/share/fonts/$font_name"

if fc-list | grep -q "$font_name"; then
  echo "${font_name} is already installed"
  exit 0
fi

(
  mkdir -p "$font_target_dir" && cd "$font_target_dir"
  curl --fail --location "$font_source_url" --output tmp.zip
  unzip tmp.zip
  rm -f tmp.zip
)

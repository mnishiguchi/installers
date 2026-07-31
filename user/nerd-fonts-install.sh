#!/usr/bin/env bash
set -euo pipefail

font_name=FiraCodeNerdFont
font_source_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
font_target_dir="$HOME/.local/share/fonts/$font_name"
temp_dir=""

cleanup() {
  if [ -n "$temp_dir" ]; then
    rm -rf -- "$temp_dir"
  fi
}

trap cleanup EXIT

for command_name in curl fc-list mktemp unzip; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing dependency: %s\n' "$command_name" >&2
    exit 1
  fi
done

if fc-list | grep -F "$font_name" >/dev/null; then
  echo "${font_name} is already installed"
  exit 0
fi

temp_dir="$(mktemp -d)"
curl --fail --location --show-error "$font_source_url" --output "$temp_dir/FiraCode.zip"
mkdir -p -- "$font_target_dir"
unzip -o -q "$temp_dir/FiraCode.zip" -d "$font_target_dir"

if command -v fc-cache >/dev/null 2>&1; then
  fc-cache -f "$font_target_dir" >/dev/null
fi

echo "${font_name} installed in ${font_target_dir}"

#!/bin/bash
set -e

if [[ -d "$ASDF_DIR" ]]; then
  echo "warning: asdf is already installed -- skipping"
else
  git clone https://github.com/asdf-vm/asdf.git "$HOME/.asdf" --branch v0.13.0
fi

asdf update

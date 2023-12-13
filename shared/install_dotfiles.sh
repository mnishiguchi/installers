#!/bin/bash
set -e

CODE_DIR="$HOME/Code"

if [ -d "$CODE_DIR/dotfiles" ]; then
  echo "warning: dotfiles already installed -- skipping"
  exit 0
fi

(
  mkdir -p "$CODE_DIR"
  cd "$CODE_DIR"
  git clone https://github.com/mnishiguchi/dotfiles.git
  cd "$CODE_DIR/dotfiles"
  ./symlink-all.sh
)

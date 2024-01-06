#!/bin/bash
set -e

dotfiles="$HOME/.dotfiles"

if [ -d "$dotfiles" ]; then
  echo "warning: dotfiles already installed at $dotfiles"
  exit 0
fi

(
  git clone https://github.com/mnishiguchi/dotfiles.git "$dotfiles"
  cd "$dotfiles"
  ./symlink-all.sh
)

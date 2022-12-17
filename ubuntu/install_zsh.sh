#!/bin/sh
set -e

echo "==> Installing zsh"

# find the zsh command binary
command -v zsh
exit_code=$?

if [ "$exit_code" -eq 0 ] ; then
  echo "zsh is already installed"
  echo "current shell is $SHELL"
else
  # https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH
  sudo apt install zsh -y
fi

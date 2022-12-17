#!/bin/sh
set -e

echo "==> Installing asdf"

# install dependencies
# https://asdf-vm.com/guide/getting-started.html
sudo apt install curl git -y

# find the asdf command binary
command -v asdf
exit_code=$?

if [ "$exit_code" -eq 0 ] ; then
  echo "asdf is already installed"
  asdf update
  asdf plugin update --all
else
  git clone https://github.com/asdf-vm/asdf.git "$HOME/.asdf" --branch v0.11.0
  echo '. $HOME/.asdf/asdf.sh' >>~/.zshrc
  echo 'fpath=(${ASDF_DIR}/completions $fpath)' >>~/.zshrc
  echo 'autoload -Uz compinit && compinit' >>~/.zshrc
  . ~/.zshrc
fi

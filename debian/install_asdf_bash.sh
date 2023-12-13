#!/bin/bash
set -e

if command -v asdf &>/dev/null; then
  echo "asdf is already installed"
  asdf update
  asdf plugin update --all
else
  # https://asdf-vm.com/guide/getting-started.html
  sudo apt install curl git -y

  rm -rf $HOME/.asdf
  git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v0.11.0

  echo '. $HOME/.asdf/asdf.sh' >>$HOME/.bashrc
  echo '. $HOME/.asdf/completions/asdf.bash' >>$HOME/.bashrc
  . $HOME/.bashrc
fi

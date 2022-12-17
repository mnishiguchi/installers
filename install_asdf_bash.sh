#!/bin/sh
set -e

echo "==> Installing asdf"

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
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.11.0
  echo '. $HOME/.asdf/asdf.sh' >>~/.bashrc
  echo '. $HOME/.asdf/completions/asdf.bash' >>~/.bashrc
  . ~/.bashrc
fi

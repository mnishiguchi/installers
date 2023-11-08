#!/bin/bash
set -e

if [[ ! -d "$HOME/.vim/pack/jetpack" ]]; then
  curl -fLo ~/.vim/pack/jetpack/opt/vim-jetpack/plugin/jetpack.vim --create-dirs https://raw.githubusercontent.com/tani/vim-jetpack/master/plugin/jetpack.vim
else
  echo "warning: already installed -- skipping"
fi

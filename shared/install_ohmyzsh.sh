#!/bin/bash
set -e

if [[ -d "$ZSH" ]]; then
  echo "warning: ohmyzsh is already installed -- skipping"
else
  # https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH#install-and-set-up-zsh-as-default
  chsh -s "$(which zsh)"

  # https://ohmyz.sh/#install
  # https://github.com/ohmyzsh/ohmyzsh/tree/master#unattended-install
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

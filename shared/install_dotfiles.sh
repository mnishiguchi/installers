#!/usr/bin/env bash
set -eu

dotfiles_repo_url="${1:-"https://github.com/mnishiguchi/dotfiles.git"}"
dotfiles_dir="${2:-"$HOME/.dotfiles"}"

dotfiles_init_script_names=(
  install
  install.sh
  setup
  setup.sh
  bootstrap
  bootstrap.sh
)

if [[ ! -d "$dotfiles_dir" ]]; then
  git clone "$dotfiles_repo_url" "$dotfiles_dir"
fi

(
  cd "$dotfiles_dir"
  echo "dotfile location: $dotfiles_dir"

  for i in "${dotfiles_init_script_names[@]}"; do
    if [ -f "$i" ] && [ -x "$i" ]; then
      echo "Running $(pwd)/$i"
      echo
      bash "$i"
      break
    fi
  done
)

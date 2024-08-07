#!/bin/bash
set -e

main() {
  # https://stackoverflow.com/a/246128/3837223
  SCRIPT_PATH="$(
    cd -- "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
  )"

  echo "current dir: $(pwd)"
  echo "script path: $SCRIPT_PATH"
  echo

  echo '===> Install packages with apt'
  # to get possibly old but stable programs

  sudo apt update && sudo apt upgrade

  sudo apt install --yes \
    flatpak \
    neofetch \
    ranger \
    ripgrep \
    vim \
    zsh

  echo "==> Installing xubuntu desktop"

  sudo apt install --yes \
    xfce4 \
    xfce4-goodies \
    xubuntu-desktop

  (
    # just in case, ensure that we are in the right path
    cd "$SCRIPT_PATH"

    echo '===> Install dotfiles'
    ./shared/install_dotfiles.sh

    echo '===> Install asdf'
    source ./shared/install_asdf.sh

    echo '===> Install FiraCodeNerdFont'
    ./shared/install_nerd_fonts.sh
  )

  echo '===> Install packages with flatpak'
  # to get latest standalone apps

  # https://docs.flatpak.org/en/latest/using-flatpak.html
  sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

  flathub_packages=(
    org.chromium.Chromium
  )

  for pkg in "${flathub_packages[@]}"; do
    flatpak install -y --noninteractive flathub "$pkg"
  done
}

main "$@"

#!/bin/bash
set -eu

echo '===> Fetch the latest package info and upgrade all the packages'

sudo pacman -Syu --noconfirm

echo '===> Install microcode updates tools'

# https://wiki.archlinux.org/title/microcode
sudo pacman -S --needed --noconfirm intel-ucode

echo '===> Install package managers'

# https://docs.flatpak.org
sudo pacman -S --needed --noconfirm flatpak

# https://asdf-vm.com
source ./shared/install_asdf.sh

# https://github.com/Jguer/yay#installation
YAY_SRC_DIR="$HOME/Downloads/yay"

if [[ -d "$YAY_SRC_DIR" ]]; then
  echo "warning: yay is already installed -- skipping"
else
  sudo pacman -S --needed --noconfirm base-devel git

  git clone https://aur.archlinux.org/yay-bin.git "$YAY_SRC_DIR" &&
    cd "$YAY_SRC_DIR" && makepkg -si
fi

echo '===> Install must-have tools'

sudo pacman -S --needed --noconfirm \
  code \
  diff-so-fancy \
  direnv \
  docker \
  docker-compose \
  git \
  git-delta \
  github-cli \
  gnome-screenshot \
  grsync \
  htop \
  lazygit \
  man-db \
  ncdu \
  neofetch \
  neovim \
  net-tools \
  ranger \
  ripgrep \
  rofi \
  rsync \
  shfmt \
  timeshift \
  tmux \
  trash-cli \
  ufw \
  vim \
  virt-manager \
  virtualbox \
  virtualbox-host-dkms \
  xclip \
  xdotool \
  xsel

flathub_packages=(
  com.brave.Browser
  com.calibre_ebook.calibre
  com.discordapp.Discord
  com.slack.Slack
  com.transmissionbt.Transmission
  com.uploadedlobster.peek
  org.flameshot.Flameshot
  org.gimp.GIMP
  org.gnome.Calculator
  org.gnome.Evince
  org.gnome.Loupe
  org.gnome.Todo
  org.videolan.VLC
)

for pkg in "${flathub_packages[@]}"; do
  flatpak install -y --noninteractive flathub "$pkg"
done

yay -S --needed --noconfirm \
  1password \
  freetube-bin \
  git-open \
  webapp-manager \
  ytmdesktop-git

echo '===> Install input methods and fonts'

# https://wiki.archlinux.org/title/Localization/Japanese
sudo pacman -S --needed --noconfirm \
  fcitx5-im \
  fcitx5-mozc \
  noto-fonts \
  noto-fonts-cjk \
  noto-fonts-emoji \
  noto-fonts-extra \
  otf-ipaexfont \
  otf-ipafont \
  ttf-firacode-nerd

echo '===> Install greenclip'

./shared/install_greenclip.sh

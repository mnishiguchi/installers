#!/bin/bash
set -eu

# Check paths
# https://stackoverflow.com/a/246128/3837223
SCRIPT_PATH="$(
  cd -- "$(dirname "$0")" >/dev/null 2>&1
  pwd -P
)"

echo "current dir: $(pwd)"
echo "script path: $SCRIPT_PATH"
echo

echo '===> Add package repositories'
# some valuable packages are not found in the default Debian repositories

sudo apt install --yes software-properties-common
sudo add-apt-repository --yes contrib
sudo add-apt-repository --yes non-free

echo '===> Install packages with apt'
# to get possibly old but stable programs

sudo apt update && sudo apt upgrade

# https://kskroyal.com/thingsafterdebianlinux/
sudo apt install --yes \
  bpytop \
  cargo \
  clang \
  curl \
  default-jdk \
  delta \
  direnv \
  exfat-fuse \
  firmware-linux \
  firmware-linux-nonfree \
  flameshot \
  flatpak \
  fzf \
  git \
  grsync \
  gstreamer1.0-vaapi \
  htop \
  libavcodec-extra \
  libc6-i386 \
  libc6-x32 \
  libu2f-udev \
  linux-headers-"$(uname -r)" \
  ncdu \
  neofetch \
  ranger \
  ripgrep \
  rofi \
  rsync \
  samba-common-bin \
  shfmt \
  tmux \
  trash-cli \
  ufw \
  unrar \
  vim \
  virt-manager \
  vlc \
  vulkan-tools \
  vulkan-validationlayers \
  wget \
  xclip \
  xdotool \
  xfce4-clipman \
  xsel \
  zsh

(
  # just in case, ensure that we are in the right path
  cd "$SCRIPT_PATH"

  echo '===> Install ohmyzsh'
  ./shared/install_ohmyzsh.sh

  echo '===> Install dotfiles'
  ./shared/install_dotfiles.sh

  echo '===> Install asdf'
  ./shared/install_asdf.sh

  echo '===> Install FiraCodeNerdFont'
  ./shared/install_nerd_fonts.sh

  echo '===> Install elixir'
  ./debian/install_elixir.sh

  echo '===> Install nerves'
  ./debian/install_nerves_systems.sh

  echo '===> Install vscodium'
  ./debian/install_vscodium.sh

  echo '===> Install Docker'
  ./debian/docker/install_docker_engine.sh
  ./debian/docker/setup_docker_group.sh
  sudo apt install --yes docker-compose-plugin
  docker --version
  docker compose version

  echo '===> Install 1password'
  ./debian/install_1password.sh

  echo '===> Install auto-cpufreq'
  ./shared/install_auto_cpufreq.sh
)

echo '===> Install asdf plugins'
# to manage multiple runtime versions

ASDF_PLUGINS=(
  neovim
  nodejs
)

for plugin in "${ASDF_PLUGINS[@]}"; do
  asdf plugin add "$plugin" || true
  asdf install "$plugin" latest
  asdf global "$plugin" latest
done

asdf list

echo '===> Install packages with flatpak'
# to get latest standalone apps

# https://docs.flatpak.org/en/latest/using-flatpak.html
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flathub_packages=(
  com.calibre_ebook.calibre
  com.discordapp.Discord
  com.slack.Slack
  com.transmissionbt.Transmission
  com.uploadedlobster.peek
  org.chromium.Chromium
  org.flameshot.Flameshot
  org.gimp.GIMP
  org.gnome.Calculator
  org.gnome.Evince
  org.gnome.Loupe
  org.gnome.Rhythmbox3
  org.gnome.World.PikaBackup
  org.videolan.VLC
)

for pkg in "${flathub_packages[@]}"; do
  flatpak install -y --noninteractive flathub "$pkg"
done

echo '===> Install package with npm'

npm install -g diff-so-fancy
npm install -g git-open

echo '===> Install input methods and fonts'

# https://wiki.debian.org/I18n/Fcitx5
# https://wiki.archlinux.org/title/Localization/Japanese
sudo apt install --yes fcitx5 fcitx5-mozc
sudo apt remove --yes uim uim-mozc

echo '===> Set default web browser'

DEFAULT_WEB_BROWSER=org.chromium.Chromium.desktop

xdg-settings set default-web-browser "$DEFAULT_WEB_BROWSER"

if ! xdg-settings check default-web-browser "$DEFAULT_WEB_BROWSER"; then
  echo "warning: couldn't set default web browser to $DEFAULT_WEB_BROWSER"
fi

echo "default web browser: $(xdg-settings get default-web-browser)"

echo '===> Set desktop manager'

sudo apt install --yes lightdm slick-greeter lightdm-settings
sudo dpkg-reconfigure lightdm && echo 'ok'
sudo lightdm --show-config

echo ''
echo 'All set 🎉🎉🎉'

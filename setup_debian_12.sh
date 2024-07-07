#!/usr/bin/env bash
set -eu

# https://stackoverflow.com/a/246128/3837223
# this_name="$(basename "$0")"
this_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Make directories
# https://wiki.archlinux.org/title/XDG_Base_Directory
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}"
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/Code"
mkdir -p "$HOME/Documents"
mkdir -p "$HOME/Downloads"
mkdir -p "$HOME/Music"
mkdir -p "$HOME/Pictures"
mkdir -p "$HOME/Videos"

echo '===> Add package repositories'
# some valuable packages are not found in the default Debian repositories

sudo apt install --yes software-properties-common
sudo add-apt-repository --yes contrib
sudo add-apt-repository --yes non-free

echo '===> Install packages with apt'
# to get possibly old but stable programs

sudo apt update --yes
sudo apt upgrade --yes

# https://kskroyal.com/thingsafterdebianlinux/
sudo apt install \
  alacritty \
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
  flatpak \
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
  vulkan-tools \
  vulkan-validationlayers \
  wget \
  xclip \
  xdotool \
  xfce4-clipman \
  xsel \
  --yes

echo '===> Install dotfiles'

"$this_dir/shared/install_dotfiles.sh"

echo '===> Install asdf'

source "$this_dir/shared/install_asdf.sh"

echo '===> Install packages with flatpak'
# to get latest standalone apps

# https://docs.flatpak.org/en/latest/using-flatpak.html
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flathub_packages=(
  com.brave.Browser
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

echo '===> Install FiraCodeNerdFont'

"$this_dir/shared/install_nerd_fonts.sh"

echo '===> Install elixir'

"$this_dir/debian/install_elixir.sh"

echo '===> Install nerves'

"$this_dir/debian/install_nerves_systems.sh"

echo '===> Install vscodium'

"$this_dir/debian/install_vscodium.sh"

echo '===> Install Docker'

"$this_dir/debian/docker/install_docker_engine.sh"
"$this_dir/debian/docker/setup_docker_group.sh"
sudo apt install --yes docker-compose-plugin
docker --version
docker compose version

echo '===> Install 1password'

"$this_dir/debian/install_1password.sh"

echo '===> Install auto-cpufreq'

"$this_dir/shared/install_auto_cpufreq.sh"

echo '===> Install input methods and fonts'

# https://wiki.debian.org/I18n/Fcitx5
# https://wiki.archlinux.org/title/Localization/Japanese
sudo apt install --yes fcitx5 fcitx5-mozc
sudo apt remove --yes uim uim-mozc

echo '===> Use Brave as default web browser'

default_web_browser=com.brave.Browser
default_web_browser_desktop=com.brave.Browser.desktop

# https://wiki.debian.org/DefaultWebBrowser
xdg-settings set default-web-browser "$default_web_browser_desktop"
xdg-mime default "$default_web_browser_desktop" x-scheme-handler/https x-scheme-handler/http

if ! xdg-settings check default-web-browser "$default_web_browser_desktop"; then
  echo "warning: couldn't set default web browser to $default_web_browser_desktop"
fi

echo "default web browser: $(xdg-settings get default-web-browser)"

# Create a custom script that launches my desired web browser
default_web_browser_cmd="$HOME/.local/bin/default-www-browser"
touch "$default_web_browser_cmd" && chmod +x "$_"

cat <<-EOF >"$default_web_browser_cmd"
#!/bin/sh
"/var/lib/flatpak/exports/bin/$default_web_browser" "$@" &
EOF

# https://wiki.debian.org/DebianAlternatives
sudo update-alternatives --install /usr/bin/www-browser www-browser "$default_web_browser_cmd" 255
sudo update-alternatives --install /usr/bin/x-www-browser x-www-browser "$default_web_browser_cmd" 255
find /etc/alternatives -type l -ls | awk 'BEGIN{OFS="\t"} /browser/ {print $11,$13}'

echo '===> Use alacritty as default terminal emulator'

default_terminal_emulator=/usr/bin/alacritty

sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$default_terminal_emulator" 255
find /etc/alternatives -type l -ls | awk 'BEGIN{OFS="\t"} /terminal/ {print $11,$13}'

echo '===> Configure alacritty'

alacritty_themes_dir="$HOME/.config/alacritty/themes"
if [[ ! -d "$alacritty_themes_dir" ]]; then
  mkdir -p "$alacritty_themes_dir"
  git clone https://github.com/alacritty/alacritty-theme "$alacritty_themes_dir" --branch yaml
fi

# https://github.com/alacritty/alacritty/tree/v0.11.0#configuration
alacritty_config="$HOME/.config/alacritty/alacritty.yml"
if [[ ! -f "$alacritty_config" ]]; then
  cat <<EOF >"$alacritty_config"
import:
  - ~/.config/alacritty/themes/themes/dracula.yaml
font:
  size: 9
  normal:
    family: FiraCode Nerd Font
    style: Regular
  bold:
    family: FiraCode Nerd Font
    style: Bold
colors:
  primary:
    background: '#000000'
keyboard:
  bindings:
    - key: '['
      mods: Control
      action: ToggleViMode
    - key: C
      mods: Control|Shift
      action: Copy
    - key: V
      mods: Control|Shift
      action: Paste
EOF
fi

cat "$alacritty_config"

echo '===> Use lightdm as desktop manager'

sudo apt install --yes lightdm slick-greeter lightdm-settings
sudo dpkg-reconfigure lightdm && echo 'ok'
sudo lightdm --show-config

echo ''
echo 'All set 🎉🎉🎉'

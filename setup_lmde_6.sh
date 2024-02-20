#!/usr/bin/env bash
set -eu

# https://stackoverflow.com/a/246128/3837223
# this_name="$(basename "$0")"
this_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

say_sth() {
  local fmt="$1"
  shift

  # shellcheck disable=SC2059
  printf "\\n$fmt\\n" "$@"
}

say_ok() { say_sth "\e[1;32m✅ $1\e[0m"; }
say_err() { say_sth "\e[1;31m❌ $1\e[0m" >&2; }
say_warn() { say_sth "\e[1;33m⚠ $1\e[0m"; }

begin_step() { say_sth "\e[1;35m⟶ $1\e[0m"; }
ok_step() { say_ok "OK"; }
skip_step() { say_warn "SKIPPED\n$1"; }

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

begin_step 'Install packages with apt'
# to get possibly old but stable programs

sudo apt update --yes
sudo apt upgrade --yes

sudo apt install \
  bat \
  bitwise \
  delta \
  direnv \
  exa \
  fd-find \
  gnupg \
  htop \
  ncdu \
  neofetch \
  ripgrep \
  rofi \
  shfmt \
  tmux \
  vim \
  xclip \
  xdotool \
  xfce4-clipman \
  xsel \
  --yes

ok_step

begin_step 'Install dotfiles'

"$this_dir/shared/install_dotfiles.sh"

ok_step

begin_step 'Install asdf'

"$this_dir/shared/install_asdf.sh"
source "${ASDF_DIR}/asdf.sh"

ok_step

begin_step 'Install asdf plugins'
# to manage multiple runtime versions

asdf_plugins=(
  neovim
  nodejs
)

for plugin in "${asdf_plugins[@]}"; do
  asdf plugin add "$plugin" || true
  asdf install "$plugin" latest
  asdf global "$plugin" latest
done

asdf list

ok_step

begin_step 'Install apps with flatpak'
# to get latest standalone apps

# https://docs.flatpak.org/en/latest/using-flatpak.html
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

flathub_packages=(
  com.brave.Browser
  com.calibre_ebook.calibre
  com.discordapp.Discord
  com.slack.Slack
  com.uploadedlobster.peek
  org.chromium.Chromium
  org.flameshot.Flameshot
  org.gnome.World.PikaBackup
)

for pkg in "${flathub_packages[@]}"; do
  flatpak install -y --noninteractive flathub "$pkg"
done

ok_step

begin_step 'Install package with npm'

npm install -g diff-so-fancy
npm install -g git-open

ok_step

begin_step 'Install FiraCodeNerdFont'

"$this_dir/shared/install_nerd_fonts.sh"

ok_step

begin_step 'Install elixir'

"$this_dir/debian/install_elixir.sh"
"$this_dir/debian/install_nerves_systems.sh"

ok_step

begin_step 'Install vscodium'

"$this_dir/debian/install_vscodium.sh"

ok_step

begin_step 'Install Docker'

"$this_dir/debian/docker/install_docker_engine.sh"
"$this_dir/debian/docker/setup_docker_group.sh"
sudo apt install --yes docker-compose-plugin
docker --version
docker compose version

ok_step

begin_step 'Install 1password'

"$this_dir/debian/install_1password.sh"

ok_step

begin_step 'Install auto-cpufreq'

"$this_dir/shared/install_auto_cpufreq.sh"

ok_step

begin_step 'Use Brave as default web browser'

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
find /etc/alternatives -type l -ls | awk 'BEGIN{OFS="\t"} /www-browser/ {print $11,$13}'

ok_step

echo ''
echo 'All set 🎉🎉🎉'

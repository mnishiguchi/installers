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

# Make directories
mkdir -p "$HOME/.config"
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/Code"
mkdir -p "$HOME/Pictures/screenshots"
mkdir -p "$HOME/Movies/screen-recordings"
mkdir -p "$HOME/tmp"

echo '===> Install or update Homebrew'

if command -v brew; then
  brew update
  brew upgrade
else
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

echo '===> Install packages with Homebrew'
# to get possibly old but stable programs

brew install TheZoraiz/ascii-image-converter/ascii-image-converter
brew install bat
brew install cpufetch
brew install direnv
brew install fzf
brew install git-delta
brew install htop
brew install ncdu
brew install neofetch
brew install ranger
brew install rar
brew install ripgrep
brew install shfmt
brew install stats
brew install tmux
brew install tree
brew install --cask sol
brew install --cask vscodium

brew tap homebrew/cask-fonts
brew install --cask font-fira-code-nerd-font

# https://imagemagick.org/script/download.php
brew install imagemagick
brew install ghostscript

echo '===> Install ohmyzsh'
$SCRIPT_PATH/shared/install_ohmyzsh.sh

echo '===> Install dotfiles'
$SCRIPT_PATH/shared/install_dotfiles.sh

echo '===> Configure Git'
$SCRIPT_PATH/shared/configure_git.sh

echo '===> Check Github access'
$SCRIPT_PATH/shared/check_github_access.sh

echo '===> Install asdf'
$SCRIPT_PATH/shared/install_asdf.sh

echo '===> Install asdf plugins'
# to manage multiple runtime versions

# https://github.com/asdf-vm/asdf-erlang
brew install autoconf
brew install openssl
brew install wxwidgets
brew install libxslt fop

# https://hexdocs.pm/nerves/installation.html
brew install fwup squashfs coreutils xz pkg-config

# https://github.com/rbenv/ruby-build/discussions/2118
brew install libyaml

ASDF_PLUGINS=(
  erlang
  elixir
  neovim
  nodejs
  python
  ruby
)

for plugin in "${ASDF_PLUGINS[@]}"; do
  asdf plugin add "$plugin" || true
  asdf install "$plugin" latest
  asdf global "$plugin" latest
done

asdf list

echo '===> Install packages with npm'

npm install -g diff-so-fancy
npm install -g git-open

echo '===> Download apps with web browser'

find-app() {
  mdfind "kMDItemKind == 'Application'" | grep -iE "$1.*\.app"
}

# web browsers
[ -z "$(find-app brave)" ] && open https://brave.com/download || echo "Brave is already installed"
[ -z "$(find-app chrome)" ] && open https://www.google.com/chrome || echo "Chrome is already installed"
[ -z "$(find-app firefox)" ] && open https://www.mozilla.org/en-US/firefox/mac || echo "Firefox is already installed"

# other nice-to-have apps
[ -z "$(find-app 1password)" ] && open https://1password.com/product/mac || echo "1Password is already installed"
[ -z "$(find-app discord)" ] && open https://discord.com/download || echo "Discord is already installed"
[ -z "$(find-app docker)" ] && open https://docs.docker.com/desktop/install/mac-install || echo "Docker is already installed"
[ -z "$(find-app flux)" ] && open https://justgetflux.com/ || echo "f.lux is already installed"
[ -z "$(find-app gimp)" ] && open https://www.gimp.org/downloads/ || echo "GIMP is already installed"
[ -z "$(find-app iterm)" ] && open https://iterm2.com/downloads.html || echo "iTerm2 is already installed"
[ -z "$(find-app rectangle)" ] && open https://rectangleapp.com || echo "Rectangle is already installed"
[ -z "$(find-app slack)" ] && open https://slack.com/downloads/mac || echo "Slack is already installed"
[ -z "$(find-app transmission)" ] && open https://transmissionbt.com/download || echo "Transmission is already installed"
[ -z "$(find-app 'visual studio code')" ] && open https://code.visualstudio.com/docs/setup/mac || echo "Visual Studio Code is already installed"

cpufetch
neofetch
echo ''
echo 'All set 🎉🎉🎉'

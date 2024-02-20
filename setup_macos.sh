#!/usr/bin/env bash
set -eu

# https://stackoverflow.com/a/246128/3837223
# this_name="$(basename "$0")"
this_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

all_set=""
step_name=""

help() {
  cat <<'EOF'
Bootstrap your macOS development system.

Packages will be installed with Homebrew based on ~/.Brewfile. If ~/.Brewfile
does not exist, default packages will be installed instead. See source code for
a list of default packages.

Usage:
    setup_macos.sh [options]

Options:
    --help, -h      Display this message
    --debug         Display any debugging information
EOF
}

say_sth() {
  local fmt="$1"
  shift

  # shellcheck disable=SC2059
  printf "\\n$fmt\\n" "$@"
}

say_ok() { say_sth "\e[1;32m✅ $1\e[0m"; }
say_err() { say_sth "\e[1;31m❌ $1\e[0m" >&2; }
say_warn() { say_sth "\e[1;33m⚠ $1\e[0m"; }

begin_step() {
  step_name="$*"
  say_sth "\e[1;35m⟶ $1\e[0m"
}

ok_step() {
  step_name=""
  say_ok "OK"
}

skip_step() {
  step_name=""
  say_warn "SKIPPED\n$1"
}

## Parse options

debug=false
while test $# -gt 0; do
  case $1 in
  --help | -h)
    help
    exit 0
    ;;
  --debug)
    debug=true
    ;;
  *) ;;
  esac
  shift
done

cleanup() {
  set +e
  if [ -z "$all_set" ]; then
    if [ -n "$step_name" ]; then
      say_err "$step_name FAILED" >&2
    else
      say_err "FAILED" >&2
    fi

    if [ -z "$debug" ]; then
      say_err "Run '$0 --debug' for debugging output." >&2
    fi
  fi
}

trap "cleanup" EXIT

## Common directories

# https://wiki.archlinux.org/title/XDG_Base_Directory
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

mkdir -p "$XDG_CONFIG_HOME"
mkdir -p "$XDG_CACHE_HOME"
mkdir -p "$XDG_DATA_HOME"
mkdir -p "$XDG_STATE_HOME"
mkdir -p "$HOME/.local/bin"

## Strap

begin_step 'Bootstrapping your macOS development system...'

strap_dir="$XDG_CONFIG_HOME/strap"

if ! [ -d "$strap_dir" ]; then
  git clone https://github.com/MikeMcQuaid/strap "$strap_dir"
fi

if [[ "$debug" = true ]]; then
  STRAP_DEBUG="1" "$strap_dir/bin/strap.sh"
else
  "$strap_dir/bin/strap.sh"
fi

ok_step

begin_step 'Installing packages with Homebrew...'

# https://formulae.brew.sh
HOMEBREW_BUNDLE_FILE_GLOBAL="${HOMEBREW_BUNDLE_FILE_GLOBAL:-$HOME/.Brewfile}"

if [[ -f "$HOMEBREW_BUNDLE_FILE_GLOBAL" ]]; then
  echo "Brewfile location: $HOMEBREW_BUNDLE_FILE_GLOBAL"
  brew bundle --global
else
  echo "Brewfile was not found -- installing default packages"
  brew bundle --file=- <<EOF
brew "openssl@3"

# from the Homebrew Formulae
brew "bash"
brew "bat"
brew "bitwise"
brew "cpufetch"
brew "diff-so-fancy"
brew "direnv"
brew "eza"
brew "fd"
brew "gawk"
brew "ghostscript"
brew "git-delta"
brew "git-open"
brew "gnupg"
brew "imagemagick"
brew "lazygit"
brew "ncdu"
brew "neofetch"
brew "neovim"
brew "picocom"
brew "ripgrep"
brew "shellcheck"
brew "shfmt"
brew "tldr"
brew "tmux"
brew "tree"
brew "wget"
brew "zsh"

# from the Cask project
cask "1password"
cask "brave-browser"
cask "discord"
cask "firefox"
cask "font-fira-code-nerd-font"
cask "gimp"
cask "google-chrome"
cask "iterm2"
cask "rectangle"
cask "slack"
cask "sol"
cask "stats"
cask "transmission"
cask "visual-studio-code"
cask "vscodium"
EOF

  # Handle docker separately because it is a lot of work to resolve conflicts
  # in case docker has already been installed without using Homebrew Cask.
  if command -v docker >/dev/null; then
    if brew list --cask | grep -Fq docker; then
      brew upgrade --cask docker
    else
      skip_step "docker is already installed without using Homebrew Cask -- ignoring"
    fi
  else
    brew install --cask docker
  fi
fi

ok_step

## Github

begin_step 'Checking Github access...'

"$this_dir/shared/check_github_access.sh"

ok_step

## asdf

begin_step 'Installing asdf...'

"$this_dir/shared/install_asdf.sh"

ok_step

begin_step 'Installing asdf plugins...'

brew bundle --file=- <<EOF
# https://github.com/asdf-vm/asdf-erlang
brew "autoconf"
brew "openssl"
brew "wxwidgets"
brew "libxslt"
brew "fop"

# https://hexdocs.pm/nerves/installation.html
brew "fwup"
brew "squashfs"
brew "coreutils"
brew "xz"
brew "pkg-config"

# https://github.com/rbenv/ruby-build/discussions/2118
brew "libyaml"
EOF

asdf_plugins=(
  erlang
  elixir
  nodejs
  ruby
)

add_or_update_asdf_plugin() {
  local plugin_name="$1"

  if ! asdf plugin-list | grep -Fq "$plugin_name"; then
    asdf plugin-add "$plugin_name" >/dev/null
  else
    asdf plugin-update "$plugin_name" >/dev/null
  fi
}

install_asdf_language() {
  local language="$1"
  local version
  version="$(asdf latest "$language")"

  if ! asdf list "$language" | grep -Fq "$version"; then
    asdf install "$language" "$version" >/dev/null
    asdf global "$language" "$version" >/dev/null
  fi
}

for asdf_plugin in "${asdf_plugins[@]}"; do
  add_or_update_asdf_plugin "$asdf_plugin"
  install_asdf_language "$asdf_plugin"
done

echo
asdf list

ok_step

## Dotfiles

begin_step 'Installing dotfiles...'

"$this_dir/shared/install_dotfiles.sh"

ok_step

## Wrapping up

begin_step 'Wrapping up...'

command -v cpufetch &>/dev/null && cpufetch
command -v neofetch &>/dev/null && neofetch

ok_step

all_set=1
say_sth 'All set 🎉🎉🎉'

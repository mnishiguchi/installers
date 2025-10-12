#!/usr/bin/env bash
# Minimal Debian/LMDE post-install orchestrator
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

say() { printf "\n\033[34m%s\033[0m\n" "$*"; }
ok() { printf " \033[32m✔ %s\033[0m\n" "$*"; }
warn() { printf " \033[33m⚠ %s\033[0m\n" "$*"; }
fail() {
  printf " \033[31m✖ %s\033[0m\n" "$*"
  exit 1
}

has() { command -v "$1" >/dev/null 2>&1; }

run_script() {
  local script="$1"
  shift || true
  [[ -f "$script" ]] || fail "missing script: $script"
  [[ -x "$script" ]] || chmod +x "$script"
  bash "$script" "$@"
}

create_dirs() {
  say "Create XDG/common directories"
  mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
  mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
  mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}"
  mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}"
  mkdir -p "$HOME/.local/bin"
  ok "directories ready"
}

export DEBIAN_FRONTEND=noninteractive
APT_FLAGS=(-y -o Dpkg::Use-Pty=0 -o Acquire::Retries=3 -qq)

apt_essentials() {
  say "APT: upgrade + essentials"
  sudo apt-get update -qq
  sudo apt-get upgrade "${APT_FLAGS[@]}" || true
  sudo apt-get install "${APT_FLAGS[@]}" \
    alacritty \
    bitwise \
    curl \
    direnv \
    fish \
    flameshot \
    flatpak \
    git \
    gawk \
    gnupg \
    htop \
    ncdu \
    peek \
    rofi \
    shfmt \
    tmux \
    unzip \
    vim \
    wget \
    xclip \
    xdotool
  ok "base packages installed"
}

apt_erlang_build_deps() {
  say "APT: Erlang build dependencies"

  # See: https://github.com/asdf-vm/asdf-erlang
  sudo apt-get install "${APT_FLAGS[@]}" \
    build-essential \
    autoconf \
    m4 \
    libncurses-dev \
    libwxgtk3.2-dev \
    libwxgtk-webview3.2-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev \
    libpng-dev \
    libssh-dev \
    unixodbc-dev \
    xsltproc \
    fop \
    libxml2-utils \
    openjdk-21-jdk
  if [[ $? -ne 0 ]]; then
    warn "Some Erlang deps failed or are unavailable on this LMDE version; adjust package names if needed."
  else
    ok "Erlang build deps installed"
  fi
}

install_dotfiles() {
  say "Setup dotfiles"
  local dotfiles_dir="$SCRIPT_DIR/../dotfiles"
  if [[ ! -d "$dotfiles_dir/.git" ]]; then
    mkdir -p "$dotfiles_dir"
    if ! git clone https://github.com/mnishiguchi/dotfiles.git "$dotfiles_dir"; then
      fail "dotfiles clone failed over HTTPS"
    fi
    ok "dotfiles repo cloned"
  fi
  run_script "$dotfiles_dir/install.sh"
  ok "dotfiles installed"
}

install_diff_so_fancy() {
  say "Install diff-so-fancy"
  run_script "$SCRIPT_DIR/shared/diff-so-fancy-install.sh"
  ok "diff-so-fancy ready"
}

install_nerd_font_firacode() {
  say "Install Nerd Font: FiraCode"
  # Ensure fontconfig tools exist for fc-list/fc-cache (no-op if already there)
  if ! command -v fc-list >/dev/null 2>&1; then
    sudo apt-get install "${APT_FLAGS[@]}" fontconfig || true
  fi

  if command -v fc-list >/dev/null 2>&1 && fc-list | grep -qi 'FiraCode Nerd Font'; then
    ok "FiraCode Nerd Font already present"
    return
  fi

  local target="$HOME/.local/share/fonts/FiraCodeNerdFont"
  mkdir -p "$target"
  (
    cd "$target"
    curl -fL https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/FiraCode.zip -o tmp.zip
    unzip -o tmp.zip >/dev/null
    rm -f tmp.zip
  )
  # Cache if available; otherwise silently continue
  command -v fc-cache >/dev/null 2>&1 && fc-cache -f >/dev/null || true
  ok "FiraCode Nerd Font installed"
}

install_mise() {
  say "Install mise (tool runtime manager)"
  if has mise; then
    ok "mise already installed: $(mise --version 2>/dev/null || echo present)"
    return 0
  fi

  # minimal + HTTPS: installs to ~/.local/bin/mise by default
  curl -fsSL https://mise.run | sh || fail "mise install failed"
  ok "mise installed to ${HOME}/.local/bin (default)"
}

install_mise_tools() {
  say "Install tools via mise"
  if ! has mise; then
    warn "Skipping mise tools (mise not installed)"
    return 0
  fi

  local -a tools=(
    bat@latest
    eza@latest
    fastfetch@latest
    fd@latest
    fzf@latest
    lazydocker@latest
    lazygit@latest
    neovim@latest
    node@lts
    python@latest
    rebar@latest
    ripgrep@latest
    yazi@latest
    zoxide@latest
    erlang@latest
    elixir@latest
  )

  mise plugins update || true

  for t in "${tools[@]}"; do
    if mise use --global "$t"; then
      ok "installed: $t"
    else
      warn "mise install failed: $t"
    fi
  done

  ok "mise tools processed"
}

install_flatpak_apps() {
  say "Install desktop apps via Flatpak (Brave/Discord/Slack)"
  if ! has flatpak; then
    warn "Skipping Flatpak apps (flatpak not installed)"
    return 0
  fi

  # Ensure Flathub remote exists
  if ! flatpak remote-list | awk '{print $1}' | grep -qx flathub; then
    if ! flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo; then
      warn "Failed to add Flathub remote"
      return 0
    fi
  fi

  local -a apps=(
    com.brave.Browser
    com.discordapp.Discord
    com.slack.Slack
  )

  for app in "${apps[@]}"; do
    if flatpak install -y flathub "$app"; then
      ok "installed: $app"
    else
      warn "Flatpak install failed: $app"
    fi
  done

  ok "Flatpak apps processed"
}

install_docker() {
  say "Install Docker Engine (+compose plugin)"
  run_script "$SCRIPT_DIR/debian/docker-install.sh"
  ok "Docker ready"
}

main() {
  create_dirs
  apt_essentials
  apt_erlang_build_deps
  install_dotfiles
  install_diff_so_fancy
  install_nerd_font_firacode
  install_mise
  install_mise_tools
  install_flatpak_apps
  install_docker
  echo
  ok "All set 🎉  (log out/in for keymap & any group changes)"
}

main "$@"

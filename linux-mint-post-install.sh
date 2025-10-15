#!/usr/bin/env bash
# post_install.sh — Minimal Debian/LMDE post-install orchestrator
set -Eeuo pipefail
IFS=$'\n\t'

say() { printf "\n\033[34m%s\033[0m\n" "$*"; }
ok() { printf " \033[32m✔ %s\033[0m\n" "$*"; }
warn() { printf " \033[33m⚠ %s\033[0m\n" "$*"; }
fail() {
  printf " \033[31m✖ %s\033[0m\n" "$*"
  exit 1
}

has() { command -v "$1" >/dev/null 2>&1; }

add_path_prepend() {
  local dir="$1"
  [[ -d "$dir" ]] || return 0
  case ":$PATH:" in *":$dir:"*) ;; *) export PATH="$dir:$PATH";; esac
}

run_installer() {
  local script="$1"
  shift || true
  [[ -f "$script" ]] || fail "missing script: $script"
  [[ -x "$script" ]] || chmod +x "$script"
  bash "$script" "$@"
}

export DEBIAN_FRONTEND=noninteractive
APT_FLAGS=(-y -o Dpkg::Use-Pty=0 -o Acquire::Retries=3)

# Make sure user-local bin is usable for this run (yazi, lazygit, neovim, etc.)
add_path_prepend "$HOME/.local/bin"

INSTALLERS_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECTS="$HOME/Projects"
DOTFILES_DIR="$PROJECTS/dotfiles"
DOTFILES_REPO="${DOTFILES_REPO:-git@github.com:mnishiguchi/dotfiles.git}"

apt_essentials() {
  say "APT: upgrade + essentials"
  sudo apt update -yq
  sudo apt upgrade -yq || true
  sudo apt install "${APT_FLAGS[@]}" \
    alacritty \
    bitwise \
    curl \
    delta \
    direnv \
    eza \
    gawk \
    git \
    gnupg \
    htop \
    ncdu \
    ripgrep \
    rofi \
    shfmt \
    tmux \
    unzip \
    vim \
    wget \
    xclip \
    zoxide
  ok "base packages installed"
}

create_dirs() {
  say "Create XDG/common directories"
  mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
  mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"
  mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}"
  mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}"
  mkdir -p "$HOME/.local/bin" "$PROJECTS"
  ok "directories ready"
}

install_dotfiles() {
  say "Setup dotfiles"
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    (mkdir -p "$PROJECTS" && cd "$PROJECTS" && git clone "$DOTFILES_REPO")
    ok "dotfiles repo cloned"
  fi
  if [[ -x "$DOTFILES_DIR/install.sh" ]]; then
    (cd "$DOTFILES_DIR" && ./install.sh)
    ok "dotfiles installed"
  else
    warn "dotfiles install.sh not found or not executable at $DOTFILES_DIR/install.sh"
  fi
}

install_nerd_font_firacode() {
  say "Install Nerd Font: FiraCode"
  # Ensure fontconfig tools exist for fc-list/fc-cache (no-op if already there)
  if ! command -v fc-list >/dev/null 2>&1; then
    sudo apt install "${APT_FLAGS[@]}" fontconfig || true
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

install_yazi() {
  say "Install Yazi"
  if has yazi; then
    ok "yazi already installed"
    return
  fi
  run_installer "$INSTALLERS_DIR/shared/yazi-install.sh"
}

install_starship() {
  say "Install starship"
  run_installer "$INSTALLERS_DIR/shared/starship-install.sh"
}

install_fzf() {
  say "Install fzf"
  run_installer "$INSTALLERS_DIR/shared/fzf-install.sh"
}

install_ble() {
  say "Install ble.sh"
  run_installer "$INSTALLERS_DIR/shared/ble-install.sh"
}

install_lazygit() {
  say "Install lazygit"
  if has lazygit; then
    ok "lazygit already installed ($("$HOME/.local/bin/lazygit" --version 2>/dev/null || lazygit --version))"
  else
    run_installer "$INSTALLERS_DIR/debian/lazygit-install.sh"
  fi
}

install_neovim() {
  say "Install Neovim"
  if has nvim; then
    ok "neovim already installed ($(nvim --version | head -n1))"
    return
  fi
  run_installer "$INSTALLERS_DIR/shared/neovim-install.sh"
}

install_asdf() {
  say "Install asdf"
  run_installer "$INSTALLERS_DIR/shared/asdf-install.sh"
}

ensure_asdf_in_path() {
  ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"
  local asdf_bin="$ASDF_DATA_DIR/bin/asdf"
  if [[ -x "$asdf_bin" ]]; then
    export ASDF_DATA_DIR
    case ":$PATH:" in
    *":$ASDF_DATA_DIR/bin:"*) : ;;
    *) export PATH="$ASDF_DATA_DIR/bin:$PATH" ;;
    esac
    hash -r || true
  fi
}

ensure_flatpak_flathub() {
  say "Ensure Flatpak + Flathub"
  if ! has flatpak; then sudo apt install "${APT_FLAGS[@]}" flatpak || warn "failed to install flatpak via apt"; fi
  if has flatpak; then
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
    ok "Flatpak/Flathub ready"
  else
    warn "flatpak unavailable — Flatpak apps will be skipped"
  fi
}

install_brave_flatpak() {
  say "Install Brave"
  if has flatpak; then
    flatpak install -y flathub com.brave.Browser || warn "Brave Flatpak install failed"
    ok "Brave processed"
  else
    warn "Skipping Brave (no flatpak)"
  fi
}

install_desktop_apps() {
  say "Install desktop apps"
  run_installer "$INSTALLERS_DIR/debian/1password-install.sh"
  if has flatpak; then
    flatpak install -y flathub org.flameshot.Flameshot || true
    flatpak install -y flathub com.uploadedlobster.peek || true
  fi
  ok "desktop apps processed"
}

install_elixir() {
  say "Install Elixir & Erlang via asdf"
  run_installer "$INSTALLERS_DIR/debian/elixir-install.sh"
}

install_nerves() {
  say "Install Nerves prerequisites + systems"
  run_installer "$INSTALLERS_DIR/debian/nerves-install.sh"
}

install_docker() {
  say "Install Docker Engine (+compose plugin)"
  run_installer "$INSTALLERS_DIR/debian/docker-install.sh"
  ok "Docker ready"
}

main() {
  apt_essentials
  create_dirs
  install_dotfiles
  install_nerd_font_firacode

  install_alacritty
  install_yazi
  install_starship
  install_fzf
  install_ble
  install_lazygit
  install_neovim

  ensure_flatpak_flathub
  install_brave_flatpak
  install_desktop_apps

  install_asdf
  ensure_asdf_in_path

  install_elixir
  install_nerves
  install_docker

  echo
  ok "All set 🎉  (log out/in for keymap & any group changes)"
}

main "$@"

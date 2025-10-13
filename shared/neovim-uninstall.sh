#!/usr/bin/env bash
set -euo pipefail

# Minimal Neovim uninstaller for the binary installed by neovim-install.sh
# Removes:
#   - INSTALL_ROOT (default: ~/.local/opt/nvim)
#   - Symlink BIN_DIR/nvim if it points to INSTALL_ROOT/bin/nvim

INSTALL_ROOT="${INSTALL_ROOT:-$HOME/.local/opt/nvim}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
NVIM_LINK="$BIN_DIR/nvim"
NVIM_TARGET="$INSTALL_ROOT/bin/nvim"

echo_h() { printf "\n\033[34m%s\033[0m\n" "$*"; }
ok() { printf " \033[32m✔ %s\033[0m\n" "$*"; }
warn() { printf " \033[33m⚠ %s\033[0m\n" "$*"; }
fail() {
  printf " \033[31m✖ %s\033[0m\n" "$*"
  exit 1
}

main() {
  echo_h "Removing Neovim files…"

  # Remove symlink if it points to our install
  if [[ -L "$NVIM_LINK" ]]; then
    link_target="$(readlink -f "$NVIM_LINK")"
    if [[ "$link_target" == "$NVIM_TARGET" ]]; then
      rm -f "$NVIM_LINK"
      ok "removed symlink: $NVIM_LINK"
    else
      warn "$NVIM_LINK points to '$link_target' (not our install). Leaving it."
    fi
  elif [[ -e "$NVIM_LINK" ]]; then
    warn "$NVIM_LINK exists but is not a symlink. Leaving it."
  else
    ok "no symlink to remove at $NVIM_LINK"
  fi

  # Remove installation directory
  if [[ -d "$INSTALL_ROOT" ]]; then
    rm -rf "$INSTALL_ROOT"
    ok "removed directory: $INSTALL_ROOT"
  else
    ok "no install dir to remove at $INSTALL_ROOT"
  fi

  echo_h "Post-check"
  if command -v nvim >/dev/null 2>&1; then
    which_nvim="$(command -v nvim)"
    ok "nvim still available at: $which_nvim (likely another install)"
  else
    ok "nvim not found in PATH (uninstalled)"
  fi
}

main "$@"

#!/usr/bin/env bash
set -euo pipefail

# Minimal Neovim installer (binary tarball from GitHub releases)
# - Installs under:   ~/.local/opt/nvim
# - Symlink created:  ~/.local/bin/nvim
# - Defaults: channel "stable" (then fallback to "latest")
#   Override with NVIM_VERSION=v0.10.4 (exact tag), or NVIM_CHANNEL=latest

NVIM_VERSION="${NVIM_VERSION:-}"
NVIM_CHANNEL="${NVIM_CHANNEL:-stable}" # stable -> latest
INSTALL_ROOT="${INSTALL_ROOT:-$HOME/.local/opt/nvim}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

echo_h() { printf "\n\033[34m%s\033[0m\n" "$*"; }
ok() { printf " \033[32m✔ %s\033[0m\n" "$*"; }
warn() { printf " \033[33m⚠ %s\033[0m\n" "$*"; }
fail() {
  printf " \033[31m✖ %s\033[0m\n" "$*"
  exit 1
}

need() { command -v "$1" >/dev/null 2>&1 || fail "need '$1' (not found)"; }

detect_arch() {
  case "$(uname -m)" in
  x86_64) echo "x86_64" ;;
  aarch64 | arm64) echo "arm64" ;;
  *) fail "unsupported architecture: $(uname -m)" ;;
  esac
}

# Return first working URL among known filename variants & channels/tags
resolve_url() {
  local arch variant tag url
  arch="$(detect_arch)"

  # Known filename variants by arch
  # x86_64: nvim-linux64.tar.gz (old) OR nvim-linux-x86_64.tar.gz (newish)
  # arm64 : nvim-linux-arm64.tar.gz (common) OR nvim-linux-aarch64.tar.gz (alt)
  case "$arch" in
  x86_64) variants=("nvim-linux64.tar.gz" "nvim-linux-x86_64.tar.gz") ;;
  arm64) variants=("nvim-linux-arm64.tar.gz" "nvim-linux-aarch64.tar.gz") ;;
  esac

  # Tags/Channels to try
  tags=()
  if [[ -n "$NVIM_VERSION" ]]; then
    tags+=("$NVIM_VERSION")
  else
    tags+=("$NVIM_CHANNEL" "latest") # try requested channel, then latest
  fi

  # Probe candidates via HTTP HEAD to find a valid asset
  for tag in "${tags[@]}"; do
    for variant in "${variants[@]}"; do
      url="https://github.com/neovim/neovim/releases/download/${tag}/${variant}"
      if curl -fsIL "$url" >/dev/null 2>&1; then
        echo "$url"
        return 0
      fi
    done
  done

  return 1
}

main() {
  need curl
  need tar

  echo_h "Resolving Neovim download URL…"
  url="$(resolve_url)" || fail "could not find a matching release asset.
Tried channel/tag: NVIM_VERSION='${NVIM_VERSION:-unset}', NVIM_CHANNEL='$NVIM_CHANNEL'
Arch: $(detect_arch)
Known variants: see script."

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  echo_h "Downloading Neovim…"
  curl -fL "$url" -o "$tmpdir/nvim.tar.gz" || fail "download failed: $url"
  ok "downloaded"

  echo_h "Extracting…"
  mkdir -p "$INSTALL_ROOT"
  tar -xzf "$tmpdir/nvim.tar.gz" -C "$tmpdir"
  rm -rf "$INSTALL_ROOT"
  mv "$tmpdir"/nvim-* "$INSTALL_ROOT"
  ok "installed to $INSTALL_ROOT"

  echo_h "Linking binary…"
  mkdir -p "$BIN_DIR"
  ln -sf "$INSTALL_ROOT/bin/nvim" "$BIN_DIR/nvim"
  ok "symlink: $BIN_DIR/nvim -> $INSTALL_ROOT/bin/nvim"

  echo_h "Verifying…"
  if "$BIN_DIR/nvim" --version | head -n1; then
    ok "neovim ready"
  else
    fail "could not execute $BIN_DIR/nvim"
  fi

  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    warn "$BIN_DIR is not in PATH."
    echo "Add to your shell rc:"
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
  fi
}

main "$@"

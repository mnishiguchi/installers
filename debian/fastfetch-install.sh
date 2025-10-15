#!/usr/bin/env bash
set -euo pipefail

# Minimal Fastfetch installer (GitHub .deb)
# - Works on Linux Mint 22 (Ubuntu 24.04 base) and LMDE 6 (Debian 12)
# - Uses the official .deb as recommended for Ubuntu >=20.04 / Debian >=11
# - Defaults: latest release, auto-detected arch (amd64/arm64)
#
# Env overrides:
#   FASTFETCH_VERSION=v2.28.0   # exact tag (e.g., v2.28.0). If unset -> 'latest'
#   FASTFETCH_ARCH=amd64        # force architecture (auto if unset)
#   DEB_URL=...                 # provide a full URL to a .deb and skip resolution
#
# Behavior:
#   - Downloads to /tmp
#   - Installs via 'apt install /path/to.deb' so dependencies are resolved
#
# Uninstall:
#   - sudo apt remove fastfetch
#
# Docs: Debian/Ubuntu install via .deb from releases page. Config at ~/.config/fastfetch/config.jsonc
#       https://github.com/fastfetch-cli/fastfetch
#       https://github.com/fastfetch-cli/fastfetch/wiki/Configuration

echo_h() { printf "\n\033[34m%s\033[0m\n" "$*"; }
ok() { printf " \033[32m✔ %s\033[0m\n" "$*"; }
warn() { printf " \033[33m⚠ %s\033[0m\n" "$*"; }
fail() {
  printf " \033[31m✖ %s\033[0m\n" "$*"
  exit 1
}

need() { command -v "$1" >/dev/null 2>&1 || fail "need '$1' (not found)"; }

detect_arch() {
  # Map kernel arch -> deb arch
  if [[ -n "${FASTFETCH_ARCH:-}" ]]; then
    echo "$FASTFETCH_ARCH"
    return 0
  fi
  case "$(uname -m)" in
  x86_64) echo "amd64" ;;
  aarch64 | arm64) echo "arm64" ;;
  *)
    fail "unsupported architecture: $(uname -m). Try setting FASTFETCH_ARCH=amd64|arm64"
    ;;
  esac
}

resolve_url() {
  # If user provided a URL explicitly, trust it.
  if [[ -n "${DEB_URL:-}" ]]; then
    echo "$DEB_URL"
    return 0
  fi

  local arch tag base url
  arch="$(detect_arch)"

  # Choose tag: exact version (if provided) else "latest"
  tag="${FASTFETCH_VERSION:-latest}"
  base="https://github.com/fastfetch-cli/fastfetch/releases"

  # Use GitHub "latest/download" for moving target, or specific tag path
  if [[ "$tag" == "latest" ]]; then
    url="$base/latest/download/fastfetch-linux-$arch.deb"
  else
    # ensure leading 'v' is allowed as-is (user supplies the exact tag)
    url="$base/download/$tag/fastfetch-linux-$arch.deb"
  fi

  # Probe with HEAD
  if curl -fsIL "$url" >/dev/null 2>&1; then
    echo "$url"
    return 0
  fi

  return 1
}

main() {
  need curl
  need sudo
  need apt
  need dpkg

  echo_h "Detecting architecture…"
  arch="$(detect_arch)"
  ok "architecture: $arch (dpkg reports: $(dpkg --print-architecture 2>/dev/null || echo 'n/a'))"

  echo_h "Resolving Fastfetch .deb URL…"
  url="$(resolve_url)" || fail "could not find a matching release asset (.deb).
Tried:
  FASTFETCH_VERSION='${FASTFETCH_VERSION:-unset}' (or latest)
  FASTFETCH_ARCH='${FASTFETCH_ARCH:-auto-detected}'
You can also set DEB_URL to a direct .deb link."

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT

  echo_h "Downloading…"
  deb="$tmpdir/fastfetch-linux-${arch}.deb"
  curl -fL "$url" -o "$deb" || fail "download failed: $url"
  ok "downloaded: $url"

  echo_h "Installing via apt (to resolve dependencies)…"
  sudo apt install -y "$deb" || fail "apt install failed"

  echo_h "Verifying…"
  if command -v fastfetch >/dev/null 2>&1; then
    fastfetch --version || true
    ok "fastfetch installed"
    echo
    echo "Tip: generate a config with:"
    echo "  fastfetch --gen-config    # minimal"
    echo "  fastfetch --gen-config-full"
  else
    fail "fastfetch not found in PATH after install"
  fi
}

main "$@"

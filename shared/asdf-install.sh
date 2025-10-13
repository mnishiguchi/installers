#!/usr/bin/env bash
set -euo pipefail

# Minimal asdf installer (binary-only)
# Usage:
#   ./asdf-install.sh            # install latest release
#   ./asdf-install.sh v0.15.2    # install specific version

ASDF_VERSION="${1:-}"
ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"
ASDF_BIN_DIR="$ASDF_DATA_DIR/bin"
mkdir -p "$ASDF_BIN_DIR"

log() { printf '\033[34m==>\033[0m %s\n' "$*"; }
ok() { printf '\033[32m✔\033[0m %s\n' "$*"; }
die() {
  printf '\033[31m✖ %s\033[0m\n' "$*" >&2
  exit 1
}

arch_slug() {
  case "$(uname -m)" in
  x86_64) echo "linux-amd64" ;;
  aarch64 | arm64) echo "linux-arm64" ;;
  *) die "Unsupported arch: $(uname -m)" ;;
  esac
}

latest_tag() {
  # Resolve the redirect of releases/latest to get the real tag (no jq required)
  curl -fsSL -o /dev/null -w '%{url_effective}' \
    https://github.com/asdf-vm/asdf/releases/latest |
    sed -n 's@.*/tag/\(v[0-9]\+\.[0-9]\+\.[0-9]\+\).*@\1@p'
}

main() {
  local slug ver url tmp
  slug="$(arch_slug)"

  if [[ -z "$ASDF_VERSION" ]]; then
    log "Detecting latest asdf release…"
    ver="$(latest_tag)"
    [[ -n "$ver" ]] || die "Could not determine latest release tag."
  else
    ver="$ASDF_VERSION"
  fi

  url="https://github.com/asdf-vm/asdf/releases/download/${ver}/asdf-${ver}-${slug}.tar.gz"
  log "Installing asdf ${ver} (${slug})"
  tmp="$(mktemp -d)"

  curl -fsSL "$url" -o "$tmp/asdf.tgz" || die "Download failed: $url"
  tar -xzf "$tmp/asdf.tgz" -C "$tmp" || die "Could not extract archive"
  [[ -f "$tmp/asdf" ]] || die "Archive did not contain 'asdf' binary"

  mv "$tmp/asdf" "$ASDF_BIN_DIR/asdf"
  chmod +x "$ASDF_BIN_DIR/asdf"
  rm -rf "$tmp"

  # Verify without requiring PATH changes yet
  "$ASDF_BIN_DIR/asdf" --version || die "Installed asdf failed to run"
  ok "asdf installed to $ASDF_BIN_DIR/asdf"

  cat <<EOF

Add this to your shell config (e.g. ~/.bashrc or ~/.zshrc):

  export ASDF_DATA_DIR="$ASDF_DATA_DIR"
  export PATH="$ASDF_BIN_DIR:\$PATH"

Then reload your shell:
  exec \$SHELL

EOF
}

main "$@"

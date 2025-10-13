#!/bin/bash
#
# Install Yazi using official prebuilt binaries (no apt, no Rust build).
# - Detects latest release + arch
# - Installs yazi/ya into ~/.local/bin
# - Optionally clones Yazi Flavors into ~/.config/yazi/flavors
#
set -Eeuo pipefail

# ----------------------------
# Printing helpers
# ----------------------------
echo_heading() { echo -e "\n\033[34m$1\033[0m"; }
echo_success() { echo -e " \033[32m✔ $1\033[0m"; }
echo_failure() { echo -e " \033[31m✖ $1\033[0m"; }
warn() { echo -e " \033[33m⚠ $1\033[0m"; }

die() {
  echo_failure "$*"
  exit 1
}
need() { command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }

# ----------------------------
# Resolve platform + asset
# ----------------------------
detect_targets() {
  case "$(uname -m)" in
  x86_64) echo "x86_64-unknown-linux-gnu x86_64-unknown-linux-musl" ;;
  aarch64 | arm64) echo "aarch64-unknown-linux-gnu aarch64-unknown-linux-musl" ;;
  *) die "Unsupported architecture: $(uname -m)" ;;
  esac
}

latest_tag() {
  # follow redirect and extract tag (e.g. v0.2.5)
  local eff
  eff="$(curl -fsSL -o /dev/null -w '%{url_effective}' https://github.com/sxyazi/yazi/releases/latest || true)"
  sed -n 's@.*/tag/\(v[^/]*\).*@\1@p' <<<"$eff"
}

resolve_asset_url() {
  local tag="$1"
  local base="https://github.com/sxyazi/yazi/releases/download/$tag"
  local -a targets=($2)
  local f

  # Prefer .tar.xz (keeps unzip optional), then .zip
  for t in "${targets[@]}"; do
    for f in \
      "yazi-$t.tar.xz" \
      "yazi-$tag-$t.tar.xz" \
      "yazi-$t.zip" \
      "yazi-$tag-$t.zip"; do
      if curl -fsIL "$base/$f" >/dev/null 2>&1; then
        echo "$base/$f"
        return 0
      fi
    done
  done
  return 1
}

# ----------------------------
# Install binaries
# ----------------------------
install_yazi_binaries() {
  echo_heading "Installing Yazi (official binary)"

  local bin_dir="$HOME/.local/bin"
  mkdir -p "$bin_dir"

  if command -v yazi >/dev/null 2>&1; then
    echo_success "yazi already installed ($(yazi --version 2>/dev/null || echo present))"
  else
    need curl
    need tar # prefer .tar.xz; we’ll only need unzip if a .zip is chosen

    local targets tag url tmp asset
    targets="$(detect_targets)"
    tag="$(latest_tag)"
    [[ -n "$tag" ]] || die "Could not determine latest Yazi release tag"

    url="$(resolve_asset_url "$tag" "$targets")" || die "No suitable Yazi asset found for your platform"
    asset="${url##*/}"

    echo_heading "Downloading $asset"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    curl -fL "$url" -o "$tmp/$asset" || die "Download failed: $url"

    echo_heading "Extracting $asset"
    case "$asset" in
    *.tar.xz)
      tar -xJf "$tmp/$asset" -C "$tmp"
      ;;
    *.zip)
      need unzip
      unzip -q "$tmp/$asset" -d "$tmp"
      ;;
    *)
      die "Unknown archive format: $asset"
      ;;
    esac

    # Find the yazi/ya binaries in extracted tree
    local yazi_bin ya_bin
    yazi_bin="$(find "$tmp" -type f -name yazi -perm -u+x | head -n1 || true)"
    ya_bin="$(find "$tmp" -type f -name ya -perm -u+x | head -n1 || true)"
    [[ -n "$yazi_bin" && -n "$ya_bin" ]] || die "Could not locate yazi/ya binaries in archive"

    install -m 0755 "$yazi_bin" "$bin_dir/yazi"
    install -m 0755 "$ya_bin" "$bin_dir/ya"
    echo_success "Installed yazi + ya → $bin_dir"

    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
      warn "~/.local/bin is not in PATH. Add:  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
  fi
}

# ----------------------------
# Flavors (themes)
# ----------------------------
install_yazi_flavors() {
  echo_heading "Installing Yazi Flavors"
  local flavors_dir="$HOME/.config/yazi/flavors"
  if [[ -d "$flavors_dir" ]]; then
    # best-effort update
    if command -v git >/dev/null 2>&1; then
      git -C "$flavors_dir" pull --ff-only >/dev/null 2>&1 &&
        echo_success "Flavors updated" || warn "Could not update flavors (leaving as-is)"
    else
      echo_success "Flavors already present"
    fi
  else
    need git
    git clone --depth=1 https://github.com/yazi-rs/flavors.git "$flavors_dir" &&
      echo_success "Flavors installed" ||
      warn "Could not fetch flavors (skipping)"
  fi
}

# ----------------------------
# Main
# ----------------------------
main() {
  install_yazi_binaries
  install_yazi_flavors
  echo_heading "Yazi installation complete. Run: yazi  (or: ya)"
}

main "$@"

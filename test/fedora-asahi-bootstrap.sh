#!/usr/bin/env bash
# Offline regression tests for the Fedora Asahi bootstrap.
set -Eeuo pipefail
IFS=$'\n\t'

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf -- "$TMP"' EXIT
export HOME="$TMP/home"
export OS_RELEASE_FILE="$TMP/os-release"
export SHELLS_FILE="$TMP/shells"
export DOTFILES_DIR="$TMP/dotfiles"
mkdir -p "$HOME" "$TMP/bin"
cat > "$OS_RELEASE_FILE" <<'OS'
ID=fedora-asahi-remix
VERSION_ID=45
RELEASE_TYPE=development
PRETTY_NAME="Fedora Linux Asahi Remix 45 (KDE)"
OS
printf '%s\n' "$TMP/bin/fish" > "$SHELLS_FILE"
printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/fish"
chmod +x "$TMP/bin/fish"
export PATH="$TMP/bin:$PATH"
touch "$TMP/installed-packages" "$TMP/dnf.log" "$TMP/mise.log"

# shellcheck source=fedora-asahi-bootstrap.sh
source "$ROOT/fedora-asahi-bootstrap.sh"

uname() {
  case "${1:-}" in
    -m) printf '%s\n' "${TEST_ARCH:-aarch64}" ;;
    -s) printf '%s\n' Linux ;;
    *) printf '%s\n' Linux ;;
  esac
}
dnf() { :; }
rpm() {
  [[ "$1" == -q && "$2" == --quiet ]] || return 2
  grep -Fxq "$3" "$TMP/installed-packages"
}
sudo() {
  printf '%s\n' "$*" >>"$TMP/dnf.log"
  [[ "$1" == dnf && "$2" == install && "$3" == --assumeyes ]] || return 2
  shift 3
  printf '%s\n' "$@" >>"$TMP/installed-packages"
}
fc-list() { printf '%s\n' 'FiraCode Nerd Font Mono:style=Regular'; }
getent() { printf 'testuser:x:1000:1000::%s:%s\n' "$HOME" "$TMP/bin/fish"; }

# Target detection accepts only Fedora Asahi Remix on aarch64.
section_preflight
sed -i 's/^ID=.*/ID=fedora/' "$OS_RELEASE_FILE"
if (section_preflight >/dev/null 2>&1); then
  echo 'preflight accepted generic Fedora' >&2
  exit 1
fi
sed -i 's/^ID=.*/ID=fedora-asahi-remix/' "$OS_RELEASE_FILE"
TEST_ARCH=x86_64
if (section_preflight >/dev/null 2>&1); then
  echo 'preflight accepted non-ARM64 architecture' >&2
  exit 1
fi
unset TEST_ARCH

# Section parsing rejects unknown/empty sections and preserves requested modes.
CHECK=false
CHANGE_SHELL=true
ONLY=''
parse_args --check --only packages,desktop --skip-shell-change
[[ "$CHECK" == true && "$CHANGE_SHELL" == false ]]
section_enabled packages && section_enabled desktop
! section_enabled mise
if (parse_args --only packages,,desktop >/dev/null 2>&1); then exit 1; fi
if (parse_args --only unknown >/dev/null 2>&1); then exit 1; fi
CHECK=false
CHANGE_SHELL=true
ONLY=''

# Check mode reports missing packages without invoking DNF.
CHECK=true
DRIFT=0
section_packages >/dev/null
[[ "$DRIFT" == 1 && ! -s "$TMP/dnf.log" ]]

# Apply mode delegates package installation to DNF through sudo.
CHECK=false
DRIFT=0
section_packages >/dev/null
[[ -s "$TMP/dnf.log" ]]
rpm -q --quiet fish

# Desktop and build manifests are independently installable.
section_desktop >/dev/null
section_build >/dev/null
build_prerequisites_ready

# The font section is idempotent and check mode is read-only.
CHECK=true
DRIFT=0
section_fonts >/dev/null
[[ "$DRIFT" == 0 ]]

# Dotfiles verification reuses the explicit checkout and does not clone.
DOTFILES_TEST_DIR="$DOTFILES_OVERRIDE"
mkdir -p "$DOTFILES_TEST_DIR/fish"
git -C "$DOTFILES_TEST_DIR" init -q
cat > "$DOTFILES_TEST_DIR/install.sh" <<'INSTALL'
#!/usr/bin/env bash
case "${1:-}" in --verify) exit 0 ;; --force) exit 0 ;; *) exit 2 ;; esac
INSTALL
chmod +x "$DOTFILES_TEST_DIR/install.sh"
section_dotfiles >/dev/null

# Fish is already registered and is the current login shell.
section_shell >/dev/null

# Mise tools are verified in check mode and installed in dependency order.
MISE_READY=true
mise() {
  case "${1:-}" in
    --version) printf '%s\n' '2026.11.14' ;;
    ls)
      if [[ "$MISE_READY" == true ]]; then
        cat <<'JSON'
{
  "yazi": [{"requested_version":"latest","installed":true,"active":true}],
  "shfmt": [{"requested_version":"latest","installed":true,"active":true}],
  "github:linebender/resvg": [{"requested_version":"0.50.0","installed":true,"active":true}],
  "erlang": [{"requested_version":"28","installed":true,"active":true}],
  "elixir": [{"requested_version":"1.19.5-otp-28","installed":true,"active":true}],
  "node": [{"requested_version":"24","installed":true,"active":true}],
  "python": [{"requested_version":"3.12","installed":true,"active":true}],
  "ruby": [{"requested_version":"latest","installed":true,"active":true}],
  "go": [{"requested_version":"latest","installed":true,"active":true}],
  "rust": [{"requested_version":"latest","installed":true,"active":true}],
  "uv": [{"requested_version":"latest","installed":true,"active":true}]
}
JSON
      else
        printf '{}\n'
      fi
      ;;
    use)
      printf '%s\n' "$*" >>"$TMP/mise.log"
      MISE_READY=true
      ;;
    reshim) printf '%s\n' 'reshim' >>"$TMP/mise.log" ;;
    *) return 2 ;;
  esac
}
CHECK=true
DRIFT=0
section_mise >/dev/null
[[ "$DRIFT" == 0 && ! -s "$TMP/mise.log" ]]
CHECK=false
manage_mise() { printf '%s\n' "$*" >>"$TMP/runtime-order.log"; }
section_runtimes >/dev/null
first_use="$(sed -n '1p' "$TMP/runtime-order.log")"
second_use="$(sed -n '2p' "$TMP/runtime-order.log")"
[[ "$first_use" == 'erlang@28' && "$second_use" == *'elixir@1.19.5-otp-28'* ]]

# Missing Mise in check mode is reported as drift without aborting the audit.
unset -f mise
CHECK=true
DRIFT=0
section_mise >/dev/null
[[ "$DRIFT" == 1 ]]

# Runtime installation refuses to compile Erlang before native dependencies.
CHECK=false
: > "$TMP/installed-packages"
if (section_runtimes >/dev/null 2>&1); then
  echo 'runtimes accepted missing native build dependencies' >&2
  exit 1
fi

printf '%s\n' 'fedora-asahi-bootstrap: ok'

#!/bin/bash
# Restore the macOS terminal development environment using native Homebrew.
# Compatible with the system Bash 3.2; do not require Homebrew Bash to bootstrap.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
readonly BREWFILE="$SCRIPT_DIR/manifests/Brewfile"
readonly DOTFILES_DIR="${DOTFILES_DIR:-$SCRIPT_DIR/../dotfiles}"
readonly -a DEFAULT_SECTIONS=(directories brew dotfiles mise alacritty shell)
readonly -a ALL_SECTIONS=(directories brew dotfiles mise runtimes alacritty shell)
readonly -a MISE_TOOLS=(neovim@latest yazi@latest)
readonly -a MISE_RUNTIMES=(erlang@28 elixir@1.19.5-otp-28 node@24 python@3.12 ruby@latest go@latest rust@latest uv@latest)
CHECK=false
CHANGE_SHELL=true
DRIFT=0
ONLY=""

say() { printf '\n%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
missing() { warn "$*"; DRIFT=1; }

usage() {
  cat <<'USAGE'
Usage: macos-bootstrap.sh [options]

  --check             Check managed state without installing or changing settings.
  --only <sections>   Comma-separated sections (run in dependency order).
                      directories,brew,dotfiles,mise,runtimes,alacritty,shell
  --skip-shell-change Do not check or change the login shell.
  -h, --help          Show help.

Default: directories,brew,dotfiles,mise,alacritty,shell
Optional: runtimes (installs programming language runtimes through mise).
Homebrew and Alacritty are installed manually; see docs/macos-setup.md.
USAGE
}

parse_args() {
  while (($#)); do
    case "$1" in
      --check) CHECK=true; shift ;;
      --only) [[ $# -ge 2 && -n "$2" ]] || fail '--only requires sections'; ONLY="$2"; shift 2 ;;
      --skip-shell-change) CHANGE_SHELL=false; shift ;;
      -h|--help) usage; exit 0 ;;
      *) fail "unknown option: $1" ;;
    esac
  done
  local section
  local -a requested
  if [[ -n "$ONLY" ]]; then
    case "$ONLY" in ,*|*,|*,,*) fail 'empty section in --only' ;; esac
    IFS=',' read -r -a requested <<< "$ONLY"
    for section in "${requested[@]}"; do
      case "$section" in
        directories|brew|dotfiles|mise|runtimes|alacritty|shell) ;;
        *) fail "unknown section: $section" ;;
      esac
    done
  fi
}

section_enabled() {
  local section="$1" selected
  if [[ -n "$ONLY" ]]; then
    [[ ",$ONLY," == *",$section,"* ]]
  else
    for selected in "${DEFAULT_SECTIONS[@]}"; do
      [[ "$selected" != "$section" ]] || return 0
    done
    return 1
  fi
}

# Select native Homebrew even when a GUI or a fresh shell has a minimal PATH.
init_brew_path() {
  local prefix
  case "$(uname -m)" in
    arm64) prefix=/opt/homebrew ;;
    x86_64) prefix=/usr/local ;;
    *) fail "unsupported architecture: $(uname -m)" ;;
  esac
  if [[ -x "$prefix/bin/brew" ]]; then
    export PATH="$prefix/bin:$prefix/sbin:$PATH"
  fi
  export PATH="$HOME/.local/bin:$PATH"
}

section_directories() {
  local dir
  say 'XDG and user directories'
  for dir in "${XDG_CONFIG_HOME:-$HOME/.config}" "${XDG_CACHE_HOME:-$HOME/.cache}" \
    "${XDG_DATA_HOME:-$HOME/.local/share}" "${XDG_STATE_HOME:-$HOME/.local/state}" "$HOME/.local/bin"; do
    if [[ ! -d "$dir" ]]; then
      if [[ "$CHECK" == true ]]; then missing "missing directory: $dir"; else mkdir -p "$dir"; fi
    fi
  done
}

section_brew() {
  say 'Homebrew packages'
  if ! command -v brew >/dev/null 2>&1; then
    if [[ "$CHECK" == true ]]; then missing 'Homebrew is missing'; return; fi
    fail 'Install native Homebrew first: https://brew.sh/ (see docs/macos-setup.md)'
  fi
  [[ -f "$BREWFILE" ]] || fail "missing manifest: $BREWFILE"
  if [[ "$CHECK" == true ]]; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check --no-upgrade --verbose --file="$BREWFILE" || missing 'Homebrew packages are missing'
  else
    brew bundle install --no-upgrade --file="$BREWFILE"
  fi
}

section_dotfiles() {
  local output
  say 'Dotfiles'
  if [[ ! -d "$DOTFILES_DIR/.git" ]]; then
    if [[ "$CHECK" == true ]]; then missing "dotfiles checkout missing: $DOTFILES_DIR"; return; fi
    [[ ! -e "$DOTFILES_DIR" && ! -L "$DOTFILES_DIR" ]] || fail "not a Git checkout: $DOTFILES_DIR"
    git clone https://github.com/mnishiguchi/dotfiles.git "$DOTFILES_DIR"
  fi
  [[ -z "$(git -C "$DOTFILES_DIR" status --short)" ]] || warn 'Local dotfiles changes are preserved'
  [[ -f "$DOTFILES_DIR/install.sh" ]] || fail 'dotfiles install.sh is missing'
  if [[ "$CHECK" == true ]]; then
    if ! output="$(bash "$DOTFILES_DIR/install.sh" --force --check 2>&1)"; then
      printf '%s\n' "$output"; missing 'dotfiles check failed'
    elif grep -Eq ': (backup|link|mkdir)[[:space:]]' <<< "$output"; then
      printf '%s\n' "$output"; missing 'dotfile links differ'
    fi
  else
    bash "$DOTFILES_DIR/install.sh" --force
  fi
}

manage_mise() {
  local state spec tool version target
  if ! command -v mise >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    if [[ "$CHECK" == true ]]; then missing 'mise or jq is missing'; return; fi
    fail 'run the brew section first'
  fi
  target="${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml"
  if [[ -L "$target" || ( -e "$target" && ! -f "$target" ) ]]; then
    if [[ "$CHECK" == true ]]; then missing "not a regular mise config: $target"; return; fi
    fail "not a regular mise config: $target"
  fi
  if [[ "$CHECK" == true ]]; then
    if ! state="$(mise ls --global --json)"; then missing 'mise state unavailable'; return; fi
    for spec in "$@"; do
      tool="${spec%@*}"; version="${spec##*@}"
      jq -e --arg tool "$tool" --arg version "$version" '(.[$tool] // []) | any(.requested_version == $version and .installed == true and .active == true)' <<< "$state" >/dev/null || missing "mise tool not ready: $spec"
    done
  else
    mise use --global --yes "$@"
  fi
}
section_mise() { say 'Mise-managed terminal tools'; manage_mise "${MISE_TOOLS[@]}"; }
section_runtimes() {
  say 'Optional programming runtimes'
  # Erlang must be available before the Elixir OTP-specific build is installed.
  if [[ "$CHECK" == true ]]; then
    manage_mise "${MISE_RUNTIMES[@]}"
  else
    manage_mise "${MISE_RUNTIMES[0]}"
    manage_mise "${MISE_RUNTIMES[@]:1}"
  fi
}

alacritty_path() {
  local app
  for app in /Applications/Alacritty.app "$HOME/Applications/Alacritty.app"; do
    if [[ -x "$app/Contents/MacOS/alacritty" ]]; then printf '%s\n' "$app/Contents/MacOS/alacritty"; return; fi
  done
  command -v alacritty
}

section_alacritty() {
  local binary version major minor
  say 'Alacritty (manual installation)'
  if ! binary="$(alacritty_path)" || ! version="$("$binary" --version)"; then
    missing 'Install Alacritty from https://alacritty.org/'
    return
  fi
  printf '%s\n' "$version"
  if [[ "$version" =~ ^alacritty[[:space:]]+([0-9]+)\.([0-9]+) ]]; then
    major="${BASH_REMATCH[1]}"; minor="${BASH_REMATCH[2]}"
    if ((major > 0 || minor >= 14)); then return; fi
  fi
  missing 'Alacritty 0.14 or newer is required for terminal.shell configuration'
}

section_shell() {
  local fish_path current_shell
  [[ "$CHANGE_SHELL" == true ]] || return 0
  say 'Login shell'
  if ! fish_path="$(command -v fish)"; then
    if [[ "$CHECK" == true ]]; then missing 'Fish is missing'; return; fi
    fail 'run the brew section first'
  fi
  current_shell="$(dscl . -read "/Users/$(id -un)" UserShell | sed 's/^UserShell: //')"
  if ! grep -Fxq "$fish_path" /etc/shells; then
    if [[ "$CHECK" == true ]]; then missing "Fish is not registered in /etc/shells: $fish_path"; else printf '%s\n' "$fish_path" | sudo tee -a /etc/shells >/dev/null; fi
  fi
  if [[ "$current_shell" != "$fish_path" ]]; then
    if [[ "$CHECK" == true ]]; then missing "login shell is $current_shell; expected $fish_path"; else chsh -s "$fish_path"; fi
  fi
}

main() {
  parse_args "$@"
  [[ "$(uname -s)" == Darwin ]] || fail 'macOS is required; use lm-bootstrap.sh on LMDE'
  [[ $EUID -ne 0 ]] || fail 'run as your normal user, not with sudo'
  [[ "$(sysctl -in sysctl.proc_translated 2>/dev/null || true)" != 1 ]] || fail 'use a native terminal, not Rosetta'
  init_brew_path
  local section
  for section in "${ALL_SECTIONS[@]}"; do
    if section_enabled "$section"; then "section_$section"; fi
  done
  if ((DRIFT)); then warn 'Managed state is incomplete; resolve the warnings and run --check again'; return 1; fi
  if [[ "$CHECK" == true ]]; then say 'Managed state is ready'; else say 'Restore complete. Log out and back in if the login shell changed.'; fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi

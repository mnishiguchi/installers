#!/bin/bash
# Configure the optional macOS Docker CLI stack without starting or resetting a VM.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
manifest="$ROOT/manifests/Brewfile.colima"
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() { printf '%s\n' 'Usage: macos/colima-setup.sh [install | --check]' 'Install or check the Colima CLI stack. Start the VM separately; see docs/colima.md.'; }
desktop_installed() {
  [[ -e /Applications/Docker.app || -L /Applications/Docker.app || -e "$HOME/Applications/Docker.app" || -L "$HOME/Applications/Docker.app" ]] ||
    brew list --cask docker-desktop >/dev/null 2>&1
}

main() {
  mode=${1:-install}
  [[ $# -le 1 ]] || fail 'unexpected arguments'
  case "$mode" in -h|--help) usage; exit 0;; install|--check) ;; *) usage >&2; exit 2;; esac
  [[ "$(uname -s)" == Darwin ]] || fail 'macOS required'
  [[ $EUID -ne 0 ]] || fail 'run as the desktop user, not root'
  command -v brew >/dev/null || fail 'install native Homebrew first'
  # Avoid changing config while Desktop owns the same CLI integration.
  if desktop_installed; then
    fail 'Docker Desktop is still installed; review its data and migrate manually first (docs/colima.md)'
  fi
  if [[ "$mode" == install ]]; then
    HOMEBREW_NO_AUTO_UPDATE=1 brew bundle install --no-upgrade --file="$manifest"
  else
    HOMEBREW_NO_AUTO_UPDATE=1 brew bundle check --no-upgrade --file="$manifest" || fail 'Colima packages missing'
  fi
  for tool in jq colima docker docker-credential-osxkeychain; do
    command -v "$tool" >/dev/null || fail "missing command: $tool"
  done
  prefix=$(brew --prefix) || fail 'cannot determine Homebrew prefix'
  plugin_dir="$prefix/lib/docker/cli-plugins"
  for plugin in docker-compose docker-buildx; do
    [[ -x "$plugin_dir/$plugin" ]] || fail "missing executable: $plugin_dir/$plugin"
  done
  # Never replace a symlink or a non-regular config file. A custom Docker config
  # is not owned by this workstation bootstrap; let its owner configure it.
  config_dir="$HOME/.docker"
  config="$config_dir/config.json"
  [[ -z "${DOCKER_CONFIG:-}" || "$DOCKER_CONFIG" == "$config_dir" ]] || fail 'custom DOCKER_CONFIG; configure plugins manually'
  [[ ! -L "$config_dir" && (! -e "$config_dir" || -d "$config_dir") ]] || fail 'Docker config directory is not a regular directory'
  [[ ! -L "$config" && (! -e "$config" || -f "$config") ]] || fail 'Docker config is not a regular file'
  # User-local plugins have higher priority than the extra plugin directory.
  # Do not silently replace plugins from another installation or stale links.
  for plugin in docker-compose docker-buildx; do
    path="$config_dir/cli-plugins/$plugin"
    if [[ -e "$path" || -L "$path" ]]; then
      [[ "$path" -ef "$plugin_dir/$plugin" ]] || fail "conflicting user plugin: $path; inspect and remove manually if obsolete"
    fi
  done
  # Validate exactly one JSON object and expected field types; keep unrelated
  # keys and existing non-Desktop credential stores, including per-registry ones.
  if [[ ! -f "$config" ]]; then
    original='{}'
  else
    original=$(jq -ce -s 'if length == 1 and (.[0] | type == "object") then .[0] else error("expected one JSON object") end' "$config") || fail 'invalid Docker config; unchanged'
  fi
  updated=$(jq -ce --arg dir "$plugin_dir" '
    if (.cliPluginsExtraDirs != null and (.cliPluginsExtraDirs | type != "array" or any(.[]; type != "string"))) then error("invalid cliPluginsExtraDirs")
    elif (.credsStore != null and (.credsStore | type != "string")) then error("invalid credsStore")
    elif (.credHelpers != null and (.credHelpers | type != "object" or any(.[]; type != "string"))) then error("invalid credHelpers")
    elif ((.credHelpers // {}) | any(.[]; . == "desktop")) then error("Desktop per-registry helper requires manual migration")
    else
      .cliPluginsExtraDirs = ((.cliPluginsExtraDirs // []) | if index($dir) == null then . + [$dir] else . end) |
      if (.credsStore // "") == "" or .credsStore == "desktop" then .credsStore = "osxkeychain" else . end
    end' <<<"$original") || fail 'Docker config needs manual review; unchanged'
  # Check mode is read-only and never needs the daemon or selects a context.
  if [[ "$original" != "$updated" ]]; then
    [[ "$mode" == install ]] || fail 'Docker CLI configuration needs setup'
    umask 077
    mkdir -p "$config_dir"
    tmp=$(mktemp "$config_dir/config.json.XXXXXXXX")
    trap 'rm -f -- "$tmp"' EXIT
    printf '%s\n' "$updated" | jq . > "$tmp"
    if [[ -f "$config" ]]; then
      backup=$(mktemp "$config_dir/config.json.backup.XXXXXXXX")
      cat "$config" > "$backup"
      printf 'Private Docker config backup: %s\n' "$backup"
    fi
    mv -f -- "$tmp" "$config"
    trap - EXIT
    printf '%s\n' 'Docker CLI config updated; registry credentials were not migrated. Log in again if required.'
  fi
  # These are client-only checks. Neither starts a VM nor contacts a daemon.
  colima version
  docker --version
  docker compose version
  docker buildx version
  printf '%s\n' 'Colima CLI setup is ready. VM startup is on demand (docs/colima.md).'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi

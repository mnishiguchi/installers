#!/usr/bin/env bash
# Bootstrap user-level Nerves tooling and clone the nerves_systems workspace.
set -Eeuo pipefail
IFS=$'\n\t'

readonly PROJECTS_DIR="${NERVES_PROJECTS_DIR:-$HOME/Projects}"
readonly REPO_URL="https://github.com/nerves-project/nerves_systems.git"
readonly REPO_DIR="$PROJECTS_DIR/nerves_systems"

say() { printf '\n\033[34m%s\033[0m\n' "$*"; }
ok() { printf ' \033[32m✔ %s\033[0m\n' "$*"; }
fail() {
  printf ' \033[31m✖ %s\033[0m\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "$1 is required"
}

validate_host() {
  case "$(uname -m)" in
  x86_64 | aarch64 | arm64) ;;
  *) fail "Nerves systems builds require an x86_64 or aarch64 Linux host" ;;
  esac
}

bootstrap_elixir_tools() {
  mix local.hex --force
  mix local.rebar --force
  mix archive.install hex nerves_bootstrap --force
}

prepare_repository() {
  mkdir -p -- "$PROJECTS_DIR"

  if [[ -d "$REPO_DIR/.git" ]]; then
    ok "$REPO_DIR already exists; leaving its working tree unchanged"
  elif [[ -e "$REPO_DIR" ]]; then
    fail "$REPO_DIR exists but is not a Git repository"
  else
    git clone "$REPO_URL" "$REPO_DIR"
    ok "cloned nerves_systems into $REPO_DIR"
  fi
}

main() {
  [[ $# -eq 0 ]] || fail "this script does not accept arguments"
  [[ $EUID -ne 0 ]] || fail "run as your normal user, not with sudo"
  require_command git
  require_command mix
  validate_host

  say "Bootstrapping user-level Nerves tooling"
  bootstrap_elixir_tools
  ok "Hex, Rebar, and nerves_bootstrap are ready"

  say "Preparing the nerves_systems workspace"
  prepare_repository
}

main "$@"

#!/usr/bin/env bash
# Apply the minimal Brave baseline using native Linux browser policies.
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
readonly MANIFEST="$SCRIPT_DIR/../manifests/brave-settings.json"
# Empty for the CLI; regression tests use an isolated tree.
POLICY_ROOT=""
MODE=apply
TARGET=""

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'USAGE'
Usage: browser-settings.sh [--browser brave] [--check | --dry-run]

Configure optional Brave services for native Linux installations.
--check reports policy-file drift (exit 1 if incomplete).
--dry-run previews the policy without changing files.
Run as the desktop user; only policy installation requests sudo.
USAGE
}

parse_args() {
  while (($#)); do
    case "$1" in
      --browser)
        [[ $# -ge 2 && -z "$TARGET" ]] || fail 'specify one browser'
        [[ "$2" == brave ]] || fail "unsupported browser: $2"
        TARGET="$2"
        shift 2 ;;
      --check|--dry-run)
        [[ "$MODE" == apply ]] || fail 'choose only one of --check or --dry-run'
        MODE="${1#--}"
        shift ;;
      -h|--help) usage; exit 0 ;;
      *) fail "unknown option: $1" ;;
    esac
  done
}

brave_installed() {
  local candidate path
  for candidate in brave-browser brave-browser-stable brave; do
    path=$(command -v "$candidate") || continue
    [[ "$path" == /* && -x "$path" ]] || continue
    path=$(readlink -f -- "$path") || continue
    case "$path" in /snap/*|*/snap|*/flatpak/*|*/flatpak) continue ;; esac
    return 0
  done
  return 1
}

policy_file() {
  printf '%s/etc/brave/policies/managed/workstation-settings.json\n' "$POLICY_ROOT"
}

read_policy() {
  local file="$1"
  [[ ! -L "$file" ]] || fail "refusing symlink policy: $file"
  if [[ -e "$file" ]]; then
    [[ -f "$file" && -r "$file" ]] || fail "unreadable or non-regular policy: $file"
    jq -e -s 'length == 1 and (.[0] | type == "object")' "$file" >/dev/null || fail "invalid JSON policy: $file"
    cat -- "$file"
  else
    printf '{}\n'
  fi
}

validate_manifest() {
  jq -e -s 'length == 1 and (.[0] | type == "object" and
    keys == ["BraveAIChatEnabled", "BraveNewsDisabled", "BraveRewardsDisabled",
      "BraveTalkDisabled", "BraveVPNDisabled", "BraveWalletDisabled"] and
    all(.[]; type == "boolean"))' "$MANIFEST" >/dev/null || fail 'invalid Brave settings manifest'
}

check_conflicts() {
  local destination="$1" desired="$2" directory other existing
  directory=$(dirname -- "$destination")
  for other in "$directory"/*.json "$directory"/../recommended/*.json; do
    [[ -e "$other" || -L "$other" ]] || continue
    [[ "$other" != "$destination" ]] || continue
    existing=$(read_policy "$other") || return 1
    if jq -e --argjson desired "$desired" 'keys | any(. as $key | $desired | has($key))' \
      <<<"$existing" >/dev/null; then
      fail "Brave settings policy already exists in $other; review it manually"
    fi
  done
}

install_policy() {
  local destination="$1" content="$2" directory temporary source
  directory=$(dirname -- "$destination")
  source=$(mktemp)
  if ! printf '%s\n' "$content" > "$source"; then rm -f -- "$source"; return 1; fi
  if ! sudo mkdir -p -- "$directory"; then rm -f -- "$source"; return 1; fi
  if ! temporary=$(sudo mktemp "$directory/.workstation-settings.XXXXXXXX"); then
    rm -f -- "$source"; return 1
  fi
  if ! sudo install -m 0644 -- "$source" "$temporary" || ! sudo mv -T -- "$temporary" "$destination"; then
    sudo rm -f -- "$temporary" || true
    rm -f -- "$source"
    return 1
  fi
  rm -f -- "$source"
}

main() {
  local destination existing desired existing_normalized desired_normalized
  parse_args "$@"
  [[ $(uname -s) == Linux ]] || fail 'native Linux Brave only; macOS and Windows are not implemented'
  [[ $(id -u) != 0 ]] || fail 'run as the desktop user, not with sudo'
  command -v jq >/dev/null || fail 'jq is required'
  brave_installed || fail 'Brave not found on PATH (native package required)'
  validate_manifest
  destination=$(policy_file)
  desired=$(jq . "$MANIFEST") || fail 'could not read manifest'
  existing=$(read_policy "$destination") || return 1
  # Own only the six supported boolean settings, including an earlier manual trial.
  jq -e --argjson desired "$desired" 'to_entries | all(.[];
    (.key as $key | $desired | has($key)) and (.value | type == "boolean"))' \
    <<<"$existing" >/dev/null || fail "unexpected content in $destination; review it manually"
  check_conflicts "$destination" "$desired" || return 1
  existing_normalized=$(jq -cS . <<<"$existing") || return 1
  desired_normalized=$(jq -cS . <<<"$desired") || return 1
  printf 'brave: %s\n' "$destination"
  if [[ "$MODE" == dry-run ]]; then
    printf '%s\n' "$desired"
  elif [[ "$existing_normalized" == "$desired_normalized" ]]; then
    printf '  [ok] policy already configured\n'
  elif [[ "$MODE" == check ]]; then
    printf '  [review] policy missing or differs\n'
    return 1
  else
    install_policy "$destination" "$desired" || fail "could not install $destination"
    printf '  [ok] policy installed\n'
  fi
  [[ "$MODE" != apply ]] || printf '\nRestart Brave and verify brave://policy.\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

#!/usr/bin/env bash
# Install the workstation's baseline extensions using native Linux browser policies.
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
readonly MANIFEST="$SCRIPT_DIR/../manifests/browser-extensions.json"
readonly -a BROWSERS=(brave chrome chromium firefox)
# The prefix is empty in the CLI; the regression tests use an isolated tree.
POLICY_ROOT=""
MODE=apply
TARGET=""
DRIFT=0

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'USAGE'
Usage: browser-extensions.sh [--browser brave|chrome|chromium|firefox]
                             [--check | --dry-run]

Manage baseline extensions for installed native Linux browsers.
Without --browser, target all supported browsers found on PATH.
--check reports policy-file drift (exit 1 if incomplete).
--dry-run previews proposed policy files without changing them.
Run as the desktop user; only policy installation requests sudo.
USAGE
}

parse_args() {
  while (($#)); do
    case "$1" in
      --browser)
        [[ $# -ge 2 && -z "$TARGET" ]] || fail 'specify one browser'
        case "$2" in brave|chrome|chromium|firefox) TARGET="$2" ;; *) fail "unsupported browser: $2" ;; esac
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

browser_installed() {
  local candidate path
  local -a commands=()
  case "$1" in
    brave) commands=(brave-browser brave-browser-stable brave) ;;
    chrome) commands=(google-chrome-stable google-chrome) ;;
    chromium) commands=(chromium chromium-browser) ;;
    firefox) commands=(firefox firefox-esr) ;;
  esac
  for candidate in "${commands[@]}"; do
    path=$(command -v "$candidate") || continue
    [[ "$path" == /* && -x "$path" ]] || continue
    path=$(readlink -f -- "$path") || continue
    case "$path" in /snap/*|*/snap|*/flatpak/*|*/flatpak) continue ;; esac
    return 0
  done
  return 1
}

validate_manifest() {
  jq -e '
    type == "object" and (.extensions | type == "array" and length > 0
    and all(.[]; type == "object"
      and (.name | type == "string" and length > 0)
      and (.chromium_id | type == "string" and test("^[a-p]{32}$"))
      and (.firefox_slug | type == "string" and test("^[a-z0-9][a-z0-9_-]*$")))
    and ((map(.chromium_id) | unique | length) == length)
    and ((map(.firefox_slug) | unique | length) == length))
  ' "$MANIFEST" >/dev/null || fail 'invalid browser extension manifest'
}

policy_file() {
  case "$1" in
    brave) printf '%s/etc/brave/policies/managed/workstation-extensions.json\n' "$POLICY_ROOT" ;;
    chrome) printf '%s/etc/opt/chrome/policies/managed/workstation-extensions.json\n' "$POLICY_ROOT" ;;
    chromium) printf '%s/etc/chromium/policies/managed/workstation-extensions.json\n' "$POLICY_ROOT" ;;
    firefox) printf '%s/etc/firefox/policies/policies.json\n' "$POLICY_ROOT" ;;
  esac
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

chromium_policy() {
  local destination="$1" directory other existing
  directory=$(dirname -- "$destination")
  # Chromium does not guarantee how duplicate policy keys in separate files merge.
  # Refuse existing extension-install controls instead of bypassing them.
  for other in "$directory"/*.json "$directory"/../recommended/*.json; do
    [[ -e "$other" || -L "$other" ]] || continue
    [[ "$other" != "$destination" ]] || continue
    existing=$(read_policy "$other") || return 1
    if jq -e 'keys | any(. == "ExtensionSettings" or startswith("ExtensionInstall") or . == "ExtensionAllowedTypes")' <<<"$existing" >/dev/null; then
      fail "extension policy already exists in $other; review it manually"
    fi
  done
  existing=$(read_policy "$destination") || return 1
  # This filename belongs to this installer. Refuse unrelated content even there.
  jq -e 'length == 0 or (keys == ["ExtensionSettings"] and
    (.ExtensionSettings | type == "object" and (to_entries | all(.[];
      (.key | test("^[a-p]{32}$")) and
      (.value == {installation_mode:"normal_installed",update_url:"https://clients2.google.com/service/update2/crx"})))))' \
    <<<"$existing" >/dev/null || fail "unexpected content in $destination; review it manually"
  jq '{ExtensionSettings: (.extensions | map({key: .chromium_id, value: {
    installation_mode: "normal_installed",
    update_url: "https://clients2.google.com/service/update2/crx"
  }}) | from_entries)}' "$MANIFEST"
}

firefox_policy() {
  local destination="$1" existing desired other
  # An application-local policy file may take precedence over /etc.
  for other in /usr/lib/firefox /usr/lib64/firefox /usr/lib/firefox-esr /usr/lib64/firefox-esr /opt/firefox; do
    other="$POLICY_ROOT$other/distribution/policies.json"
    [[ ! -e "$other" && ! -L "$other" ]] || fail "application-local Firefox policy exists: $other; review it manually"
  done
  existing=$(read_policy "$destination") || return 1
  jq -e '(.policies // {} | type == "object") and
    ((.policies // {}) | has("ExtensionSettings") | not) and
    ((.policies.Extensions // {}) | type == "object" and
      (keys | all(. == "Install")) and
      (.Install // [] | type == "array" and all(.[]; type == "string")))' \
    <<<"$existing" >/dev/null || fail "conflicting Firefox extension policy in $destination; review it manually"
  desired=$(jq '[.extensions[].firefox_slug | "https://addons.mozilla.org/firefox/downloads/latest/" + . + "/latest.xpi"]' "$MANIFEST")
  # Firefox has one policy document. Keep all existing unrelated keys and URLs.
  jq --argjson desired "$desired" '
    .policies.Extensions.Install = (reduce $desired[] as $url
      (.policies.Extensions.Install // []; if index($url) == null then . + [$url] else . end))
  ' <<<"$existing"
}

# Stage and replace the file within the destination filesystem. No profile writes.
install_policy() {
  local destination="$1" content="$2" directory temporary source
  directory=$(dirname -- "$destination")
  source=$(mktemp)
  printf '%s\n' "$content" > "$source"
  if ! sudo mkdir -p -- "$directory"; then rm -f -- "$source"; return 1; fi
  if ! temporary=$(sudo mktemp "$directory/.workstation-extensions.XXXXXXXX"); then
    rm -f -- "$source"; return 1
  fi
  if ! sudo install -m 0644 -- "$source" "$temporary" || ! sudo mv -T -- "$temporary" "$destination"; then
    sudo rm -f -- "$temporary" || true
    rm -f -- "$source"
    return 1
  fi
  rm -f -- "$source"
}

manage_browser() {
  local browser="$1" destination existing desired existing_normalized desired_normalized
  destination=$(policy_file "$browser")
  existing=$(read_policy "$destination") || return 1
  case "$browser" in
    firefox) desired=$(firefox_policy "$destination") || return 1 ;;
    *) desired=$(chromium_policy "$destination") || return 1 ;;
  esac
  existing_normalized=$(jq -cS . <<<"$existing") || return 1
  desired_normalized=$(jq -cS . <<<"$desired") || return 1
  printf '\n%s: %s\n' "$browser" "$destination"
  if [[ "$MODE" == dry-run ]]; then
    printf '%s\n' "$desired"
  elif [[ "$existing_normalized" == "$desired_normalized" ]]; then
    printf '  [ok] policy already configured\n'
  elif [[ "$MODE" == check ]]; then
    printf '  [review] policy missing or differs\n'
    DRIFT=1
  else
    install_policy "$destination" "$desired" || fail "could not install $destination"
    printf '  [ok] policy installed\n'
  fi
}

main() {
  local browser found=0
  parse_args "$@"
  [[ $(uname -s) == Linux ]] || fail 'native Linux browsers only; macOS and Windows are not implemented'
  [[ $(id -u) != 0 ]] || fail 'run as the desktop user, not with sudo'
  command -v jq >/dev/null || fail 'jq is required'
  validate_manifest
  for browser in "${BROWSERS[@]}"; do
    [[ -z "$TARGET" || "$TARGET" == "$browser" ]] || continue
    if ! browser_installed "$browser"; then
      [[ -z "$TARGET" ]] || fail "$browser not found on PATH (native package required)"
      continue
    fi
    found=1
    manage_browser "$browser" || fail "could not configure $browser"
  done
  ((found)) || fail 'no supported native browsers detected on PATH'
  ((DRIFT == 0)) || return 1
  [[ "$MODE" != apply ]] || printf '\nRestart the browsers and verify their policy and extensions pages.\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

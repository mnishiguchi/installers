#!/usr/bin/env bash
# Exercise the installer against an isolated policy tree, without real sudo.
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
# shellcheck source=user/browser-extensions.sh
source "$ROOT/user/browser-extensions.sh"
POLICY_ROOT="$TMP/root"
mkdir -p "$TMP/bin"
for command in brave-browser google-chrome chromium firefox-esr; do
  printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/$command"
  chmod +x "$TMP/bin/$command"
done
export PATH="$TMP/bin:$PATH"
id() { printf '1000\n'; }
sudo() {
  printf '%s\n' "$*" >> "$TMP/sudo.log"
  "$@"
}
run() ( main "$@"; )
reject() {
  if run "$@" > "$TMP/error.log" 2>&1; then
    printf 'Expected failure: %s\n' "$*" >&2
    exit 1
  fi
}

# Dry-run and missing-policy check do not write anything or request elevation.
run --dry-run > "$TMP/preview"
grep -q 'normal_installed' "$TMP/preview"
grep -q 'save-pinned-tabs/latest.xpi' "$TMP/preview"
[[ ! -e "$POLICY_ROOT" && ! -e "$TMP/sudo.log" ]]
reject --check
[[ ! -e "$POLICY_ROOT" && ! -e "$TMP/sudo.log" ]]
reject --browser safari
reject --check --dry-run

# Target selection writes only the requested browser, not profiles.
run --browser brave
brave=$(policy_file brave)
chrome=$(policy_file chrome)
chromium=$(policy_file chromium)
firefox=$(policy_file firefox)
[[ -f "$brave" && ! -e "$chrome" && ! -e "$chromium" && ! -e "$firefox" ]]
jq -e '.ExtensionSettings | length == 2 and all(.[]; .installation_mode == "normal_installed")' "$brave" >/dev/null

# Existing unrelated Firefox and Chromium policies are preserved.
mkdir -p "$(dirname "$firefox")" "$(dirname "$chrome")"
printf '%s\n' '{"policies":{"DisableTelemetry":true,"Extensions":{"Install":["https://addons.mozilla.org/firefox/downloads/latest/example/latest.xpi"]}}}' > "$firefox"
printf '%s\n' '{"ShowHomeButton":true}' > "$(dirname "$chrome")/other.json"
run
cmp "$brave" "$chrome"
cmp "$brave" "$chromium"
jq -e '.policies.DisableTelemetry and (.policies.Extensions.Install | length == 3 and any(.[]; contains("save-pinned-tabs")))' "$firefox" >/dev/null
jq -e '.ShowHomeButton == true' "$(dirname "$chrome")/other.json" >/dev/null
[[ $(stat -c '%a' "$brave") == 644 ]]
: > "$TMP/sudo.log"
run --check
run
[[ ! -s "$TMP/sudo.log" ]]

# A duplicate policy key, malformed policy, unexpected owned-file content,
# or Firefox install restrictions must not be silently overwritten.
printf '%s\n' '{"ExtensionSettings":{"*":{"installation_mode":"blocked"}}}' > "$(dirname "$brave")/other.json"
reject --browser brave
grep -q 'extension policy already exists' "$TMP/error.log"
rm "$(dirname "$brave")/other.json"
printf 'invalid json\n' > "$(dirname "$brave")/other.json"
reject --browser brave
rm "$(dirname "$brave")/other.json"
printf '%s\n' '{"policies":{"ExtensionSettings":{"*":{"installation_mode":"blocked"}}}}' > "$firefox"
reject --browser firefox
grep -q 'conflicting Firefox extension policy' "$TMP/error.log"
printf '%s\n' '{"policies":{"Extensions":{"Locked":["example"]}}}' > "$firefox"
reject --browser firefox
printf '%s\n' '{"HomepageLocation":"https://example.org"}' > "$brave"
reject --browser brave
jq -e '.HomepageLocation == "https://example.org"' "$brave" >/dev/null
rm "$brave"
ln -s "$chrome" "$brave"
reject --browser brave
[[ -L "$brave" && ! -s "$TMP/sudo.log" ]]

printf '%s\n' 'browser-extensions: ok'

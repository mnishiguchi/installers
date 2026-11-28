#!/usr/bin/env bash
# Test native Brave policy installation without touching /etc or a browser profile.
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT
# shellcheck source=user/browser-settings.sh
source "$ROOT/user/browser-settings.sh"
POLICY_ROOT="$TMP/root"
mkdir -p "$TMP/bin"
printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/brave-browser"
chmod +x "$TMP/bin/brave-browser"
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

run --dry-run > "$TMP/preview"
grep -q '"BraveAIChatEnabled": false' "$TMP/preview"
reject --check
reject --browser firefox
reject --check --dry-run
[[ ! -e "$POLICY_ROOT" && ! -e "$TMP/sudo.log" ]]

destination=$(policy_file)
directory=$(dirname -- "$destination")
mkdir -p "$directory"
printf '%s\n' '{"ExtensionSettings":{"example":{"installation_mode":"normal_installed"}}}' > "$directory/workstation-extensions.json"
cp "$directory/workstation-extensions.json" "$TMP/extensions-original"
run --browser brave
jq -e 'length == 6 and .BraveAIChatEnabled == false and
  ([to_entries[] | select(.key != "BraveAIChatEnabled") | .value] | all(. == true))' "$destination" >/dev/null
cmp "$directory/workstation-extensions.json" "$TMP/extensions-original"
[[ $(stat -c '%a' "$destination") == 644 ]]
: > "$TMP/sudo.log"
run --check
run
[[ ! -s "$TMP/sudo.log" ]]

# Adopt the earlier manual experiment regardless of formatting; repair drift.
printf '%s\n' "$(jq -cS . "$MANIFEST")" > "$destination"
run --check
run
[[ ! -s "$TMP/sudo.log" ]]
printf '%s\n' '{"BraveAIChatEnabled":true}' > "$destination"
reject --check
run --dry-run > "$TMP/preview"
[[ ! -s "$TMP/sudo.log" ]]
jq -e '.BraveAIChatEnabled == true' "$destination" >/dev/null
run
run --check
: > "$TMP/sudo.log"

# Reject duplicate managed/recommended keys, invalid JSON, unrelated content and symlinks.
for other in "$directory/other.json" "$directory/../recommended/other.json"; do
  mkdir -p "$(dirname -- "$other")"
  printf '%s\n' '{"BraveNewsDisabled":false}' > "$other"
  reject
  grep -q 'Brave settings policy already exists' "$TMP/error.log"
  rm "$other"
done
printf 'invalid json\n' > "$directory/other.json"
reject
rm "$directory/other.json"
printf '%s\n' '{"HomepageLocation":"https://example.org"}' > "$destination"
reject
jq -e '.HomepageLocation == "https://example.org"' "$destination" >/dev/null
printf '%s\n' '{"BraveAIChatEnabled":"false"}' > "$destination"
reject
rm "$destination"
ln -s "$directory/workstation-extensions.json" "$destination"
reject
[[ -L "$destination" && ! -s "$TMP/sudo.log" ]]
cmp "$directory/workstation-extensions.json" "$TMP/extensions-original"
printf '%s\n' 'browser-settings: ok'

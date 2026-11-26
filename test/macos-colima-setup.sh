#!/bin/bash
# Isolated Colima setup tests; no Homebrew, daemon, network, or real HOME changes.
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
if [[ $EUID -eq 0 ]]; then
  printf '%s\n' 'Colima setup tests skipped as root (installer refuses root).'
  exit 0
fi
T=$(mktemp -d)
trap 'rm -rf -- "$T"' EXIT
export HOME="$T/home" PREFIX="$T/prefix" MOCK_LOG="$T/commands.log"
unset DOCKER_CONFIG
mkdir -p "$HOME" "$T/bin" "$PREFIX/lib/docker/cli-plugins"
export PATH="$T/bin:$PATH"
cat > "$T/bin/uname" <<'SH'
#!/bin/sh
echo Darwin
SH
cat > "$T/bin/brew" <<'SH'
#!/bin/sh
printf 'brew %s\n' "$*" >> "$MOCK_LOG"
case "$1" in
  --prefix) echo "$PREFIX" ;;
  bundle) case "$2" in install|check) exit 0;; *) exit 99;; esac ;;
  *) exit 99 ;;
esac
SH
cat > "$T/bin/docker" <<'SH'
#!/bin/sh
printf 'docker %s\n' "$*" >> "$MOCK_LOG"
case "$*" in --version|'compose version'|'buildx version') echo 'mock version';; *) exit 99;; esac
SH
cat > "$T/bin/colima" <<'SH'
#!/bin/sh
[ "$*" = version ] || exit 99
echo 'mock colima version'
SH
printf '#!/bin/sh\nexit 99\n' > "$T/bin/docker-credential-osxkeychain"
for plugin in docker-compose docker-buildx; do
  printf '#!/bin/sh\nexit 0\n' > "$PREFIX/lib/docker/cli-plugins/$plugin"
done
chmod +x "$T/bin/"* "$PREFIX/lib/docker/cli-plugins/"*
# Override only the physical Desktop probe after sourcing, so tests also work
# on macOS hosts where Desktop is installed. All other code is unchanged.
setup() {
  bash -c 'source "$1"; desktop_installed() { [[ "${MOCK_DESKTOP:-}" == yes ]]; }; main "$2"' _ "$ROOT/macos/colima-setup.sh" "$1"
}
reject() {
  if setup "$1" > "$T/rejected.log" 2>&1; then
    echo "unexpected success: $1" >&2; exit 1
  fi
}
config="$HOME/.docker/config.json"
reject --check
[[ ! -e "$HOME/.docker" ]]
MOCK_DESKTOP=yes reject install
[[ ! -e "$HOME/.docker" ]]
setup install
jq -e --arg dir "$PREFIX/lib/docker/cli-plugins" '.credsStore == "osxkeychain" and .cliPluginsExtraDirs == [$dir]' "$config" >/dev/null
setup --check
cp "$config" "$T/fresh.json"
setup install
cmp "$config" "$T/fresh.json"
[[ -z "$(find "$HOME/.docker" -name 'config.json.backup.*' -print)" ]]
cat > "$config" <<'JSON'
{"currentContext":"custom","auths":{"example.invalid":{}},"credsStore":"desktop","credHelpers":{"private.invalid":"custom"},"cliPluginsExtraDirs":["/other","/first"]}
JSON
cp "$config" "$T/original.json"
reject --check
cmp "$config" "$T/original.json"
setup install
jq -e --arg dir "$PREFIX/lib/docker/cli-plugins" '.credsStore == "osxkeychain" and .currentContext == "custom" and .credHelpers == {"private.invalid":"custom"} and .auths == {"example.invalid":{}} and .cliPluginsExtraDirs == ["/other","/first",$dir]' "$config" >/dev/null
# Verify exact backup bytes and no redundant backup on rerun.
set -- "$HOME/.docker/"config.json.backup.*
[[ $# -eq 1 && -f "$1" ]]
cmp "$1" "$T/original.json"
setup install
set -- "$HOME/.docker/"config.json.backup.*
[[ $# -eq 1 && -f "$1" ]]
# A deliberate custom global store must be retained.
printf '%s\n' '{"credsStore":"custom"}' > "$config"
setup install
jq -e '.credsStore == "custom"' "$config" >/dev/null
# Invalid data, conflicting plugins, symlinks and custom config paths are refused.
for invalid in 'not-json' '{} {}' '{"credsStore":false}' '{"cliPluginsExtraDirs":false}' '{"cliPluginsExtraDirs":[1]}' '{"credHelpers":{"private.invalid":"desktop"}}'; do
  printf '%s\n' "$invalid" > "$config"
  cp "$config" "$T/invalid.json"
  reject install
  cmp "$config" "$T/invalid.json"
done
cp "$T/fresh.json" "$config"
mkdir -p "$HOME/.docker/cli-plugins"
ln -s /nonexistent "$HOME/.docker/cli-plugins/docker-compose"
reject install
[[ -L "$HOME/.docker/cli-plugins/docker-compose" ]]
unlink "$HOME/.docker/cli-plugins/docker-compose"
ln -s "$PREFIX/lib/docker/cli-plugins/docker-compose" "$HOME/.docker/cli-plugins/docker-compose"
setup --check
DOCKER_CONFIG="$T/custom" reject install
rm "$config"
ln -s "$T/fresh.json" "$config"
reject install
[[ -L "$config" ]]
# A check-only invocation is allowed to inspect version commands, never start
# Colima, select a context, run Docker operations or invoke credential helpers.
if grep -Ev '^(brew (--prefix|bundle (check|install) --no-upgrade --file=.*)|docker (--version|compose version|buildx version))$' "$MOCK_LOG"; then
  echo 'unexpected command in mock log' >&2; exit 1
fi
printf '%s\n' 'macos-colima-setup_test: ok'

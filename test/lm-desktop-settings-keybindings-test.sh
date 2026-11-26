#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

source_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
scratch="$(mktemp -d "${TMPDIR:-/tmp}/lm-desktop-keybindings-test.XXXXXX")"
trap 'rm -rf -- "$scratch"' EXIT

repo="$scratch/repo"
home="$scratch/home"
mock="$scratch/mock"
mkdir -p "$repo/manifests/desktop" "$home" "$mock" "$repo/manifests/desktop/cinnamon-spice-settings"
cp "$source_root/lm-desktop-settings.sh" "$repo/lm-desktop-settings.sh"
chmod +x "$repo/lm-desktop-settings.sh"
export HOME="$home" MOCK_KEYBINDINGS="$scratch/current-keybindings.dconf"
export PATH="$mock:$PATH"

cat > "$repo/manifests/desktop/cinnamon.dconf" <<'DConf'
[/]
desktop-effects-workspace=false

[cinnamon-session]
quit-time-delay=60

[desktop/interface]
gtk-theme='Mint-Y-Dark-Aqua'

[desktop/keybindings]
custom-list=['custom0']

[desktop/keybindings/custom-keybindings/custom0]
binding=['<Super>a']
command='@HOME@/.local/bin/rofi-combi-menu'
name='Old Rofi Name'

[desktop/keybindings/wm]
activate-window-menu=@as []

[desktop/media-handling]
autorun-never=false

[theme]
name='Mint-Y-Dark-Aqua'
DConf
printf 'applet snapshot sentinel\n' > "$repo/manifests/desktop/applet-sentinel.txt"

cat > "$MOCK_KEYBINDINGS" <<DConf
[/]
custom-list=['custom0']
[custom-keybindings/custom0]
binding=['<Alt>space', '<Super>space', '<Super>a']
command='$HOME/.local/bin/rofi-combi-menu'
name='Rofi Launcher'
[wm]
activate-window-menu=@as []
DConf

cat > "$mock/dconf" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  dump)
    [[ "$2" == /org/cinnamon/desktop/keybindings/ ]] || exit 2
    [[ "${MOCK_EMPTY:-no}" != yes ]] || exit 0
    cat "$MOCK_KEYBINDINGS"
    ;;
  *) echo "unexpected dconf command: $*" >&2; exit 2 ;;
esac
MOCK

cat > "$mock/gsettings" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  list-schemas) printf '%s\n' org.cinnamon ;;
  *) echo "unexpected gsettings command: $*" >&2; exit 2 ;;
esac
MOCK
chmod +x "$mock/dconf" "$mock/gsettings"

script="$repo/lm-desktop-settings.sh"
snapshot="$repo/manifests/desktop/cinnamon.dconf"
applet="$repo/manifests/desktop/applet-sentinel.txt"

expect_status() {
  local expected=$1 actual=0
  shift
  "$@" > "$scratch/stdout" 2> "$scratch/stderr" || actual=$?
  if [[ "$actual" != "$expected" ]]; then
    cat "$scratch/stdout" "$scratch/stderr" >&2
    echo "expected exit $expected, got $actual: $*" >&2
    exit 1
  fi
}

# The focused check detects only keyboard-binding drift and is read-only.
expect_status 1 "$script" check-keybindings
cp "$snapshot" "$scratch/before-check"
expect_status 1 "$script" check-keybindings
cmp "$snapshot" "$scratch/before-check"

# Capture updates only desktop/keybindings and normalizes the home directory.
"$script" capture-keybindings > "$scratch/capture-output"
grep -F "name='Rofi Launcher'" "$snapshot" >/dev/null
grep -F "binding=['<Alt>space', '<Super>space', '<Super>a']" "$snapshot" >/dev/null
grep -F "command='@HOME@/.local/bin/rofi-combi-menu'" "$snapshot" >/dev/null
"$script" check-keybindings >/dev/null

# All unrelated Cinnamon sections and applet snapshots remain untouched.
grep -F "[desktop/interface]" "$snapshot" >/dev/null
grep -F "gtk-theme='Mint-Y-Dark-Aqua'" "$snapshot" >/dev/null
grep -F "[desktop/media-handling]" "$snapshot" >/dev/null
grep -F "autorun-never=false" "$snapshot" >/dev/null
[[ "$(cat "$applet")" == 'applet snapshot sentinel' ]]

# A second capture is idempotent.
cp "$snapshot" "$scratch/after-capture"
"$script" capture-keybindings >/dev/null
cmp "$snapshot" "$scratch/after-capture"

# A later live shortcut change is detected without modifying the tracked file.
cat > "$MOCK_KEYBINDINGS" <<DConf
[/]
custom-list=['custom0']
[custom-keybindings/custom0]
binding=['<Super>a']
command='$HOME/.local/bin/rofi-combi-menu'
name='Rofi Launcher'
[wm]
activate-window-menu=@as []
DConf
cp "$snapshot" "$scratch/before-drift-check"
expect_status 1 "$script" check-keybindings
cmp "$snapshot" "$scratch/before-drift-check"

# Empty live output must not erase or replace the existing snapshot.
cp "$snapshot" "$scratch/before-empty-capture"
expect_status 1 env MOCK_EMPTY=yes "$script" capture-keybindings
cmp "$snapshot" "$scratch/before-empty-capture"

# The full snapshot commands remain available.
help_output=$("$script" help)
[[ "$help_output" == *capture-keybindings* && "$help_output" == *check-keybindings* ]]

printf '%s\n' 'lm-desktop-settings-keybindings-test: ok'

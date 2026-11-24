#!/bin/bash
# shellcheck disable=SC2034,SC2154
# Offline regression tests. No Homebrew, network, sudo or real home mutations.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
unset XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME
mkdir -p "$HOME"
# shellcheck source=macos-bootstrap.sh
source "$ROOT/macos-bootstrap.sh"

parse_args --check --only directories,brew --skip-shell-change
[[ "$CHECK" == true && "$CHANGE_SHELL" == false ]]
section_enabled directories
section_enabled brew
if section_enabled shell || section_enabled runtimes; then
  echo "unexpected section selected" >&2; exit 1
fi
for sections in bogus brew, ,brew brew,,shell; do
  if (parse_args --only "$sections"); then echo "accepted bad section: $sections" >&2; exit 1; fi
done
section_directories
[[ "$DRIFT" == 1 && ! -e "$HOME/.config" ]]
CHECK=false
DRIFT=0
section_directories
[[ -d "$HOME/.config" && -d "$HOME/.local/bin" ]]
CHECK=true
section_directories
[[ "$DRIFT" == 0 ]]

brew() { printf '%s\n' "$*" >> "$TMP/brew.log"; }
section_brew
grep -F 'bundle check --no-upgrade --verbose' "$TMP/brew.log"
CHECK=false
section_brew
grep -F 'bundle install --no-upgrade' "$TMP/brew.log"

alacritty_path() { printf '%s\n' "$TMP/alacritty"; }
printf '#!/bin/sh\necho alacritty 0.13.2\n' > "$TMP/alacritty"
chmod +x "$TMP/alacritty"
DRIFT=0
section_alacritty
[[ "$DRIFT" == 1 ]]
printf '#!/bin/sh\necho alacritty 0.17.0\n' > "$TMP/alacritty"
DRIFT=0
section_alacritty
[[ "$DRIFT" == 0 ]]
printf 'macOS bootstrap regression tests passed.\n'

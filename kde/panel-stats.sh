#!/usr/bin/env bash
# Install the compact native Plasma sensor face and configure one bottom-panel widget.
set -Eeuo pipefail

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() { printf 'Usage: %s [--check | --dry-run | --help]\n' "$0"; }
mode=apply
case "${1:-}" in
  '') ;;
  --check) mode=check ;;
  --dry-run) mode=dry-run ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[[ $# -le 1 ]] || fail 'Expected at most one argument'
[[ $(id -u) != 0 ]] || fail 'Run as the desktop user, not root'
[[ ${XDG_CURRENT_DESKTOP:-} == KDE ]] || fail 'Run in a KDE Plasma session'
command -v busctl >/dev/null || fail 'busctl is required'
command -v kreadconfig6 >/dev/null || fail 'Plasma 6 is required'
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
face_id=org.example.installers.compactstats.cores
face_dir="${XDG_DATA_HOME:-$HOME/.local/share}/ksysguard/sensorfaces/$face_id"
[[ $face_dir == /* ]] || fail 'Expected absolute XDG data directory'
# The working preview used this ID and ownership marker. Adopt it in place.
for path in "$face_dir" "$face_dir/contents" "$face_dir/contents/ui"; do
  [[ ! -L $path ]] || fail "Refusing symlink: $path"
done
if [[ -e $face_dir ]]; then
  [[ -d $face_dir && -f $face_dir/.installers-preview && ! -L $face_dir/.installers-preview ]] ||
    fail "Refusing to overwrite unowned face: $face_dir"
fi
core_model=$(awk '/^cpu[0-9]+[[:space:]]/ {printf "%s\"cpu/%s/usage\"", sep, $1; sep=","} END {print ""}' /proc/stat)
[[ -n $core_model ]] || fail 'No logical CPUs found in /proc/stat'
files=(metadata.json contents/faceproperties contents/ui/CompactRepresentation.qml contents/ui/FullRepresentation.qml)
render() {
  if [[ $1 == contents/ui/CompactRepresentation.qml ]]; then
    sed "s|CORE_MODEL_PLACEHOLDER|$core_model|" "$base/compact-stats/$1"
  else
    cat "$base/compact-stats/$1"
  fi
}
# Check widget selection before touching package files. Plasma returns print output.
run_plasma() {
  local result
  result=$(busctl --user call org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell evaluateScript s \
    "const mode = \"$1\"; $(cat "$base/panel-stats.js")") || fail 'Plasma scripting call failed'
  printf '%s\n' "$result"
  case "$result" in
    's "COMPACT_STATS_OK:'*) return 0 ;;
    's "COMPACT_STATS_DRIFT:'*) return 3 ;;
    *) fail 'Unexpected Plasma scripting result' ;;
  esac
}
widget_drift=0
run_plasma check || widget_drift=$?
[[ $widget_drift == 0 || $widget_drift == 3 ]] || fail 'Widget check failed'
drift=0
for file in "${files[@]}"; do
  [[ ! -L $face_dir/$file ]] || fail "Refusing symlink: $face_dir/$file"
  if [[ -f $face_dir/$file ]] && render "$file" | cmp -s - "$face_dir/$file"; then
    continue
  fi
  [[ ! -e $face_dir/$file || -f $face_dir/$file ]] || fail "Not a regular file: $face_dir/$file"
  printf '  [review] %s\n' "$face_dir/$file"
  drift=1
done
if [[ $mode == check ]]; then
  ((drift == 0 && widget_drift == 0)) || exit 1
  printf '  [ok] Compact Stats configured\n'
  exit 0
fi
if [[ $mode == dry-run ]]; then
  printf 'Would install/update Compact Stats at %s and configure the selected widget if needed.\n' "$face_dir"
  exit 0
fi
if ((drift)); then
  mkdir -p "$face_dir/contents/ui"
  touch "$face_dir/.installers-preview"
  for file in "${files[@]}"; do
    if [[ -f $face_dir/$file ]] && render "$file" | cmp -s - "$face_dir/$file"; then continue; fi
    tmp=$(mktemp "$face_dir/$file.XXXXXX")
    if ! render "$file" > "$tmp" || ! chmod 644 "$tmp" || ! mv -f -- "$tmp" "$face_dir/$file"; then
      rm -f -- "$tmp"
      fail "Could not install $file"
    fi
  done
fi
if ((widget_drift)); then
  run_plasma apply
  run_plasma check
fi
printf '  [ok] Compact Stats configured. If the display did not refresh, log out and back in.\n'

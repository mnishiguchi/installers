#!/usr/bin/env bash
# Offline test; no live Plasma session is changed.
set -Eeuo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
node "$repo/test/kde-panel-stats.js"
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/bin"
export XDG_DATA_HOME="$tmp/data" XDG_CURRENT_DESKTOP=KDE
export MOCK_STATE="$tmp/state"
export PATH="$tmp/bin:$PATH"
cat > "$tmp/bin/id" <<'MOCK'
#!/bin/sh
printf '1000\n'
MOCK
cat > "$tmp/bin/kreadconfig6" <<'MOCK'
#!/bin/sh
exit 0
MOCK
cat > "$tmp/bin/busctl" <<'MOCK'
#!/usr/bin/env bash
set -eu
case "${*: -1}" in
  'const mode = "apply";'*) touch "$MOCK_STATE"; printf 's "COMPACT_STATS_OK: installed"\n' ;;
  *) if [[ -f $MOCK_STATE ]]; then printf 's "COMPACT_STATS_OK: 0 settings differ"\n'; else printf 's "COMPACT_STATS_DRIFT: missing widget"\n'; fi ;;
esac
MOCK
chmod +x "$tmp/bin/"*
script="$repo/kde/panel-stats.sh"
face="$XDG_DATA_HOME/ksysguard/sensorfaces/org.example.installers.compactstats.cores"
"$script" --dry-run
[[ ! -e $face && ! -e $MOCK_STATE ]]
if "$script" --check; then exit 1; fi
"$script"
[[ -f $face/metadata.json && -f $face/.installers-preview ]]
grep -q '"cpu/cpu0/usage"' "$face/contents/ui/CompactRepresentation.qml"
! grep -q CORE_MODEL_PLACEHOLDER "$face/contents/ui/CompactRepresentation.qml"
"$script" --check
before=$(stat -c '%i' "$face/metadata.json")
"$script"
[[ $(stat -c '%i' "$face/metadata.json") == "$before" ]]
printf 'drift\n' > "$face/metadata.json"
if "$script" --check; then exit 1; fi
"$script"
"$script" --check
rm "$face/.installers-preview"
if "$script"; then exit 1; fi
printf 'kde-panel-stats: ok\n'

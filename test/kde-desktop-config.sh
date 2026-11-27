#!/usr/bin/env bash
# Offline regression test; never touch real KDE configuration.
set -Eeuo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
export HOME="$fixture/home" XDG_CONFIG_HOME="$fixture/config"
export XDG_DATA_DIRS="$fixture/share" XDG_CURRENT_DESKTOP=KDE XDG_SESSION_TYPE=wayland
export FAKE_KDE_STATE="$fixture/state" FAKE_KDE_WRITES="$fixture/writes"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_DIRS/applications" "$FAKE_KDE_STATE" "$fixture/bin"
touch "$XDG_DATA_DIRS/applications/org.fcitx.Fcitx5.desktop" "$FAKE_KDE_WRITES"
export PATH="$fixture/bin:$PATH"
cat > "$fixture/bin/id" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' 1000
STUB
cat > "$fixture/bin/kreadconfig6" <<'STUB'
#!/usr/bin/env bash
set -eu
file= group= key= default=
while (($#)); do
  case "$1" in
    --file) file=$2 ;;
    --group) group=$2 ;;
    --key) key=$2 ;;
    --default) default=$2 ;;
    *) exit 2 ;;
  esac
  shift 2
done
path="$FAKE_KDE_STATE/$file/$group/$key"
if [[ -f "$path" ]]; then cat "$path"; else printf '%s\n' "$default"; fi
STUB
cat > "$fixture/bin/kwriteconfig6" <<'STUB'
#!/usr/bin/env bash
set -eu
file= group= key=
while (($# > 1)); do
  case "$1" in
    --file) file=$2 ;;
    --group) group=$2 ;;
    --key) key=$2 ;;
    --type) [[ "$2" == path ]] ;;
    *) exit 2 ;;
  esac
  shift 2
done
mkdir -p "$FAKE_KDE_STATE/$file/$group"
printf '%s\n' "$1" > "$FAKE_KDE_STATE/$file/$group/$key"
printf '%s\n' "$file/$group/$key" >> "$FAKE_KDE_WRITES"
STUB
cat > "$fixture/bin/plasma-apply-colorscheme" <<'STUB'
#!/usr/bin/env bash
exec kwriteconfig6 --file kdeglobals --group General --key ColorScheme "$1"
STUB
chmod +x "$fixture/bin/"*
script="$repo/kde/desktop-config.sh"
"$script" --help >/dev/null
if "$script" --check > "$fixture/check.log"; then
  echo 'Expected drift on empty state' >&2; exit 1
fi
[[ ! -s "$FAKE_KDE_WRITES" ]]
mkdir -p "$FAKE_KDE_STATE/kwinrc/Desktops" "$FAKE_KDE_STATE/kwinrc/Xwayland" "$FAKE_KDE_STATE/kxkbrc/Layout"
printf 'keep-this-id\n' > "$FAKE_KDE_STATE/kwinrc/Desktops/Id_1"
printf '1.7\n' > "$FAKE_KDE_STATE/kwinrc/Xwayland/Scale"
printf 'intl\n' > "$FAKE_KDE_STATE/kxkbrc/Layout/VariantList"
"$script" > "$fixture/apply.log"
"$script" --check > "$fixture/check.log"
grep -q 'Managed KDE settings are ready' "$fixture/check.log"
[[ $(cat "$FAKE_KDE_STATE/kwinrc/Desktops/Id_1") == keep-this-id ]]
[[ $(cat "$FAKE_KDE_STATE/kwinrc/Xwayland/Scale") == 1.7 ]]
[[ -z $(cat "$FAKE_KDE_STATE/kxkbrc/Layout/VariantList") ]]
[[ $(cat "$FAKE_KDE_STATE/kwinrc/Desktops/Number") == 3 ]]
[[ $(cat "$FAKE_KDE_STATE/kwinrc/Wayland/InputMethod") == "$XDG_DATA_DIRS/applications/org.fcitx.Fcitx5.desktop" ]]
: > "$FAKE_KDE_WRITES"
"$script" > "$fixture/rerun.log"
[[ ! -s "$FAKE_KDE_WRITES" ]]
if XDG_SESSION_TYPE=x11 "$script" > /dev/null 2>&1; then
  echo 'Expected non-Wayland session rejection' >&2; exit 1
fi
if "$script" --unknown > /dev/null 2>&1; then
  echo 'Expected unknown argument rejection' >&2; exit 1
fi
rm "$XDG_DATA_DIRS/applications/org.fcitx.Fcitx5.desktop"
if "$script" > /dev/null 2>&1; then
  echo 'Expected missing Fcitx5 rejection' >&2; exit 1
fi
[[ ! -s "$FAKE_KDE_WRITES" ]]
printf 'KDE desktop config regression checks passed.\n'

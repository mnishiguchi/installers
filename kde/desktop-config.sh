#!/usr/bin/env bash
# Restore the selected, portable preferences of a Plasma 6 desktop.
set -Eeuo pipefail
IFS=$'\n\t'

usage() {
  cat <<'USAGE'
Usage: kde/desktop-config.sh [--check | --help]

Manage selected KDE Plasma 6 Wayland desktop preferences as the desktop user.
  --check  Report managed setting drift without writing configuration.
  --help   Show this help.

Default: apply only settings that differ. Log out and back in if changed.
Global shortcuts and the Fcitx5 input-method profile remain manual.
USAGE
}

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
check=false
case "${1:-}" in
  '') ;;
  --check) check=true ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
(($# <= 1)) || fail 'Expected at most one argument'
[[ "$(id -u)" != 0 ]] || fail 'Run as the desktop user, not root'
[[ "${XDG_CURRENT_DESKTOP:-}" == KDE && "${XDG_SESSION_TYPE:-}" == wayland ]] ||
  fail 'Run inside a KDE Wayland session'
for tool in kreadconfig6 kwriteconfig6 plasma-apply-colorscheme; do
  command -v "$tool" >/dev/null || fail "$tool is required (Plasma 6)"
done

# Use the installed service definition, not a machine-specific home path.
fcitx_desktop=''
IFS=: read -r -a data_dirs <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
for dir in "${data_dirs[@]}"; do
  [[ "$dir" == /* ]] || continue
  candidate="$dir/applications/org.fcitx.Fcitx5.desktop"
  if [[ -r "$candidate" ]]; then
    fcitx_desktop="$candidate"
    break
  fi
done
[[ -n "$fcitx_desktop" ]] || fail 'Fcitx5 desktop entry missing in XDG_DATA_DIRS'

# The only managed keys. Do not copy complete config files or desktop UUIDs.
# The delimiter keeps spaces and empty values intact.
readonly -a settings=(
  'kxkbrc|Layout|Options|caps:ctrl_shifted_capslock'
  'kxkbrc|Layout|ResetOldOptions|true'
  'kxkbrc|Layout|LayoutList|us'
  'kxkbrc|Layout|VariantList|'
  'kxkbrc|Layout|DisplayNames|'
  'kxkbrc|Layout|Use|true'
  'kwinrc|Desktops|Number|3'
  'kwinrc|Desktops|Rows|1'
  'kwinrc|Plugins|desktopchangeosdEnabled|true'
  'kwinrc|Plugins|slideEnabled|false'
  'kwinrc|Windows|RollOverDesktops|true'
  "kwinrc|Wayland|InputMethod|$fcitx_desktop"
  'kdeglobals|General|ColorScheme|BreezeDark'
)

drift=0
changed=0
for setting in "${settings[@]}"; do
  IFS='|' read -r file group key expected <<< "$setting"
  # Missing empty-valued settings already have the desired effective value.
  default='__desktop_config_missing__'
  [[ -n "$expected" ]] || default=''
  actual=$(kreadconfig6 --file "$file" --group "$group" --key "$key" --default "$default")
  label="$file [$group] $key"
  if [[ "$actual" == "$expected" ]]; then
    printf '  [ok] %s = %s\n' "$label" "$expected"
    continue
  fi
  drift=$((drift + 1))
  printf '  [review] %s: %q -> %q\n' "$label" "$actual" "$expected"
  "$check" && continue

  if [[ "$file" == kdeglobals ]]; then
    # Use Plasma's color scheme utility rather than writing just the name.
    plasma-apply-colorscheme "$expected"
  elif [[ "$key" == InputMethod ]]; then
    kwriteconfig6 --file "$file" --group "$group" --key "$key" --type path "$expected"
  else
    kwriteconfig6 --file "$file" --group "$group" --key "$key" "$expected"
  fi
  actual=$(kreadconfig6 --file "$file" --group "$group" --key "$key" --default "$default")
  [[ "$actual" == "$expected" ]] || fail "Could not persist $label"
  changed=$((changed + 1))
done

printf '\nManual: global shortcuts, Fcitx5 profile, and live session behavior.\n'
if "$check" && ((drift > 0)); then
  printf 'Managed KDE settings differ (%d).\n' "$drift"
  exit 1
fi
if ((changed > 0)); then
  printf 'Persisted %d changes. Log out and back in, then run --check again.\n' "$changed"
else
  printf 'Managed KDE settings are ready.\n'
fi

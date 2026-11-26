#!/usr/bin/env bash
# Capture, restore, or check the stable parts of this Cinnamon desktop setup.
set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly SCRIPT_DIR
readonly STATE_DIR="$SCRIPT_DIR/manifests/desktop"
readonly CINNAMON_STATE="$STATE_DIR/cinnamon.dconf"
readonly FCITX_PROFILE_STATE="$STATE_DIR/fcitx-profile"
readonly SPICES_MANIFEST="$STATE_DIR/cinnamon-spices.txt"
readonly SPICE_SETTINGS_MANIFEST="$STATE_DIR/cinnamon-spice-settings.txt"
readonly SPICE_SETTINGS_STATE="$STATE_DIR/cinnamon-spice-settings"
readonly CINNAMON_ROOT="/org/cinnamon/"
readonly SPICES_INDEX_URL="https://cinnamon-spices.linuxmint.com/json/applets.json"
readonly SPICES_HOME_URL="https://cinnamon-spices.linuxmint.com"

readonly CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
readonly STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
readonly FCITX_PROFILE="$CONFIG_HOME/fcitx/profile"
readonly CINNAMON_SPICE_CONFIG="$CONFIG_HOME/cinnamon/spices"
readonly USER_APPLETS_DIR="$DATA_HOME/cinnamon/applets"

readonly -a CINNAMON_ROOT_KEYS=(
  desktop-effects-workspace
  enabled-applets
  enabled-desklets
  enabled-extensions
  favorite-apps
  hotcorner-layout
  next-applet-id
  panel-edit-mode
  panel-launchers
  panel-scale-text-icons
  panel-zone-icon-sizes
  panel-zone-symbolic-icon-sizes
  panels-autohide
  panels-enabled
  panels-height
  panels-hide-delay
  panels-show-delay
  window-effect-speed
  workspace-expo-view-as-grid
)

readonly -a CINNAMON_PATHS=(
  cinnamon-session
  desktop/applications/calculator
  desktop/applications/terminal
  desktop/input-sources
  desktop/interface
  desktop/keybindings
  desktop/media-handling
  desktop/peripherals/keyboard
  desktop/peripherals/mouse
  desktop/peripherals/touchpad
  desktop/screensaver
  desktop/sound
  desktop/wm/preferences
  gestures
  launcher
  muffin
  settings-daemon/peripherals/keyboard
  settings-daemon/plugins/power
  theme
)

DRIFT=0
TEMP_DIR=""

say() { printf "\n\033[34m%s\033[0m\n" "$*"; }
ok() { printf " \033[32m✔ %s\033[0m\n" "$*"; }
warn() { printf " \033[33m⚠ %s\033[0m\n" "$*" >&2; }
fail() {
  printf " \033[31m✖ %s\033[0m\n" "$*" >&2
  exit 1
}

has() { command -v "$1" >/dev/null 2>&1; }

usage() {
  cat <<'EOF'
Usage: lm-desktop-settings.sh <command>

Manage the Git-tracked, non-sensitive portion of this Cinnamon desktop.

Commands:
  capture             Refresh the complete desktop snapshot.
  capture-keybindings Refresh only /org/cinnamon/desktop/keybindings/.
  restore             Back up current state, install missing applets, and apply snapshot.
  check               Report differences without changing the machine.
  check-keybindings   Check only /org/cinnamon/desktop/keybindings/.
  help                Show this help.

The full snapshot includes Cinnamon panels, themes, keybindings, gestures,
keyboard and pointer preferences, power settings, Fcitx/Mozc selection, and
Cinnamon applet settings. The focused keybinding commands update or compare
only /org/cinnamon/desktop/keybindings/; they do not capture input-source
layout settings, Fcitx, or applet preferences. The snapshot excludes monitor
layout, wallpaper paths, clipboard data, caches, session files, and Mozc
learned-history databases.
EOF
}

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf -- "$TEMP_DIR"
  fi
}

make_temp_dir() {
  [[ -z "$TEMP_DIR" ]] || return 0
  TEMP_DIR="$(mktemp -d)"
  trap cleanup EXIT
}

mark_drift() {
  warn "$*"
  DRIFT=1
}

require_file() {
  [[ -f "$1" ]] || fail "missing required state file: $1"
}

require_command() {
  has "$1" || fail "$1 is required"
}

require_cinnamon_schema() {
  require_command gsettings
  gsettings list-schemas | grep -Fx org.cinnamon >/dev/null ||
    fail "the org.cinnamon settings schema is unavailable"
}

normalize_stream() {
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    printf '%s\n' "${line//"$HOME"/@HOME@}"
  done
}

denormalize_stream() {
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    printf '%s\n' "${line//@HOME@/"$HOME"}"
  done
}

read_manifest() {
  local manifest="$1"
  local output_name="$2"
  local line
  local -n output="$output_name"

  require_file "$manifest"
  output=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -n "$line" ]] && output+=("$line")
  done <"$manifest"
  return 0
}

validate_relative_path() {
  case "$1" in
  "" | /* | .. | ../* | */../* | */..)
    fail "unsafe relative path in desktop state: $1"
    ;;
  esac
  return 0
}

validate_spice_uuid() {
  [[ "$1" =~ ^[A-Za-z0-9_.@+-]+$ && "$1" != "." && "$1" != ".." ]] ||
    fail "unsafe Cinnamon Spice UUID in desktop state: $1"
}

capture_cinnamon_to() {
  local destination="$1"
  local key path value

  require_command dconf
  require_cinnamon_schema

  {
    printf '[/]\n'
    for key in "${CINNAMON_ROOT_KEYS[@]}"; do
      value="$(dconf read "${CINNAMON_ROOT}${key}")"
      if [[ -n "$value" ]]; then
        printf '%s=%s\n' "$key" "$value"
      fi
    done

    for path in "${CINNAMON_PATHS[@]}"; do
      dconf dump "${CINNAMON_ROOT}${path}/" | awk -v prefix="$path" '
        /^\[\/\]$/ {
          print ""
          print "[" prefix "]"
          next
        }
        /^\[/ {
          print ""
          print "[" prefix "/" substr($0, 2)
          next
        }
        NF { print }
      '
    done
  } | normalize_stream >"$destination"
}

# Capture one Cinnamon subtree in the same section naming convention as the
# full snapshot, but without a leading separator. This lets a narrow capture
# replace only that subtree while preserving every unrelated snapshot section.
capture_cinnamon_path_to() {
  local relative_path="$1"
  local destination="$2"

  require_command dconf
  require_cinnamon_schema

  dconf dump "${CINNAMON_ROOT}${relative_path}/" | awk -v prefix="$relative_path" '
    /^\[\/\]$/ {
      if (seen) print ""
      print "[" prefix "]"
      seen = 1
      next
    }
    /^\[/ {
      if (seen) print ""
      print "[" prefix "/" substr($0, 2)
      seen = 1
      next
    }
    NF { print }
  ' | normalize_stream >"$destination"
}

extract_dconf_path_sections() {
  local relative_path="$1"
  local source="$2"
  local destination="$3"

  awk -v prefix="$relative_path" '
    function flush_pending() {
      if (pending != "") printf "%s", pending
      pending = ""
    }
    /^\[/ {
      section = substr($0, 2, length($0) - 2)
      next_keep = (section == prefix || index(section, prefix "/") == 1)
      if (keep && next_keep) {
        flush_pending()
        print
      } else if (!keep && next_keep) {
        pending = ""
        print
      } else {
        pending = ""
      }
      keep = next_keep
      next
    }
    keep {
      if ($0 ~ /^[[:space:]]*$/) {
        pending = pending $0 "\n"
      } else {
        flush_pending()
        print
      }
    }
  ' "$source" >"$destination"
}

replace_dconf_path_sections() {
  local relative_path="$1"
  local source="$2"
  local replacement="$3"
  local destination="$4"

  awk -v prefix="$relative_path" -v replacement_file="$replacement" '
    function emit_replacement( i) {
      for (i = 1; i <= replacement_count; i++) print replacement_lines[i]
    }
    BEGIN {
      while ((getline line < replacement_file) > 0) {
        replacement_lines[++replacement_count] = line
      }
      close(replacement_file)
      if (replacement_count == 0) exit 2
    }
    /^\[/ {
      section = substr($0, 2, length($0) - 2)
      matches = (section == prefix || index(section, prefix "/") == 1)
      if (matches) {
        if (!inserted) {
          emit_replacement()
          inserted = 1
        }
        skipping = 1
        keep = 0
        next
      }
      if (skipping) {
        print ""
        skipping = 0
      }
      if (!inserted && section > prefix) {
        emit_replacement()
        print ""
        inserted = 1
      }
      keep = 1
      print
      next
    }
    keep { print }
    END {
      if (!inserted) {
        print ""
        emit_replacement()
      }
    }
  ' "$source" >"$destination"
}

capture_keybindings() {
  local current_keybindings merged_snapshot tracked_keybindings

  [[ $EUID -ne 0 ]] || fail "run as your normal user, not with sudo"
  require_file "$CINNAMON_STATE"
  make_temp_dir
  current_keybindings="$TEMP_DIR/current-keybindings.dconf"
  merged_snapshot="$TEMP_DIR/cinnamon.dconf"
  tracked_keybindings="$TEMP_DIR/tracked-keybindings.dconf"

  say "Capturing Cinnamon keyboard shortcuts"
  capture_cinnamon_path_to "desktop/keybindings" "$current_keybindings"
  [[ -s "$current_keybindings" ]] ||
    fail "no Cinnamon keybinding values were returned; existing snapshot was left unchanged"

  replace_dconf_path_sections \
    "desktop/keybindings" \
    "$CINNAMON_STATE" \
    "$current_keybindings" \
    "$merged_snapshot"
  extract_dconf_path_sections \
    "desktop/keybindings" \
    "$merged_snapshot" \
    "$tracked_keybindings"
  cmp -s -- "$current_keybindings" "$tracked_keybindings" ||
    fail "could not verify the updated keybinding snapshot; original was left unchanged"

  if cmp -s -- "$CINNAMON_STATE" "$merged_snapshot"; then
    ok "Cinnamon keybinding snapshot is already current"
    return 0
  fi

  install -m 0644 "$merged_snapshot" "$CINNAMON_STATE"
  ok "Cinnamon keybinding snapshot refreshed in $CINNAMON_STATE"
  warn "only desktop/keybindings was updated; other desktop and applet snapshots were preserved"
}

check_keybindings() {
  local current_keybindings tracked_keybindings

  [[ $EUID -ne 0 ]] || fail "run as your normal user, not with sudo"
  require_file "$CINNAMON_STATE"
  make_temp_dir
  current_keybindings="$TEMP_DIR/current-keybindings.dconf"
  tracked_keybindings="$TEMP_DIR/tracked-keybindings.dconf"

  say "Checking Cinnamon keyboard shortcuts"
  capture_cinnamon_path_to "desktop/keybindings" "$current_keybindings"
  extract_dconf_path_sections \
    "desktop/keybindings" \
    "$CINNAMON_STATE" \
    "$tracked_keybindings"
  [[ -s "$tracked_keybindings" ]] ||
    fail "the managed snapshot has no desktop/keybindings sections"

  if cmp -s -- "$tracked_keybindings" "$current_keybindings"; then
    ok "Cinnamon keybindings match the managed snapshot"
    return 0
  fi

  mark_drift "Cinnamon keybindings differ from the managed snapshot"
  return 1
}

profile_value() {
  local profile="$1"
  local key="$2"
  sed -n "s/^${key}=//p" "$profile" | head -n 1
}

capture_fcitx_profile_to() {
  local destination="$1"
  local current_im enabled_line entry method
  local -a entries=()
  local -a enabled=()

  [[ -f "$FCITX_PROFILE" ]] || fail "Fcitx profile not found: $FCITX_PROFILE"
  current_im="$(profile_value "$FCITX_PROFILE" IMName)"
  enabled_line="$(profile_value "$FCITX_PROFILE" EnabledIMList)"
  [[ -n "$current_im" ]] || fail "Fcitx profile has no active input method"
  [[ "$current_im" =~ ^[A-Za-z0-9_.@+-]+$ ]] || fail "unsafe Fcitx input method name"

  IFS=',' read -r -a entries <<<"$enabled_line"
  for entry in "${entries[@]}"; do
    [[ "$entry" == *:True ]] || continue
    method="${entry%:True}"
    [[ "$method" =~ ^[A-Za-z0-9_.@+-]+$ ]] || fail "unsafe Fcitx input method name"
    enabled+=("${method}:True")
  done
  ((${#enabled[@]} > 0)) || fail "Fcitx profile has no enabled input methods"

  {
    printf '[Profile]\n'
    printf 'IMName=%s\n' "$current_im"
    local IFS=,
    printf 'EnabledIMList=%s\n' "${enabled[*]}"
  } >"$destination"
}

capture_spices_to() {
  local destination="$1"
  local settings_destination="$2"
  local settings_manifest="$3"
  local directory file relative

  : >"$destination"
  if [[ -d "$USER_APPLETS_DIR" ]]; then
    while IFS= read -r -d '' directory; do
      local uuid
      uuid="$(basename -- "$directory")"
      validate_spice_uuid "$uuid"
      printf '%s\n' "$uuid"
    done < <(find "$USER_APPLETS_DIR" -mindepth 1 -maxdepth 1 -type d -print0) |
      LC_ALL=C sort >"$destination"
  fi

  : >"$settings_manifest"
  [[ -d "$CINNAMON_SPICE_CONFIG" ]] || return 0
  while IFS= read -r -d '' file; do
    relative="${file#"$CINNAMON_SPICE_CONFIG/"}"
    validate_relative_path "$relative"
    mkdir -p -- "$settings_destination/$(dirname -- "$relative")"
    normalize_stream <"$file" >"$settings_destination/$relative"
    printf '%s\n' "$relative"
  done < <(find "$CINNAMON_SPICE_CONFIG" -type f -name '*.json' -print0) |
    LC_ALL=C sort >"$settings_manifest"
}

capture() {
  local relative
  local -a settings_files=()

  [[ $EUID -ne 0 ]] || fail "run as your normal user, not with sudo"
  make_temp_dir
  mkdir -p -- "$TEMP_DIR/spice-settings"

  say "Capturing desktop settings"
  capture_cinnamon_to "$TEMP_DIR/cinnamon.dconf"
  capture_fcitx_profile_to "$TEMP_DIR/fcitx-profile"
  capture_spices_to \
    "$TEMP_DIR/cinnamon-spices.txt" \
    "$TEMP_DIR/spice-settings" \
    "$TEMP_DIR/cinnamon-spice-settings.txt"

  mkdir -p -- "$STATE_DIR" "$SPICE_SETTINGS_STATE"
  install -m 0644 "$TEMP_DIR/cinnamon.dconf" "$CINNAMON_STATE"
  install -m 0644 "$TEMP_DIR/fcitx-profile" "$FCITX_PROFILE_STATE"
  install -m 0644 "$TEMP_DIR/cinnamon-spices.txt" "$SPICES_MANIFEST"
  install -m 0644 "$TEMP_DIR/cinnamon-spice-settings.txt" "$SPICE_SETTINGS_MANIFEST"

  read_manifest "$TEMP_DIR/cinnamon-spice-settings.txt" settings_files
  for relative in "${settings_files[@]}"; do
    validate_relative_path "$relative"
    install -D -m 0644 \
      "$TEMP_DIR/spice-settings/$relative" \
      "$SPICE_SETTINGS_STATE/$relative"
  done

  ok "desktop snapshot refreshed in $STATE_DIR"
  warn "review the Git diff before committing; applet settings can contain custom paths"
}

backup_current_state() {
  local backup_dir relative source
  local -a settings_files=()

  mkdir -p -- "$STATE_HOME/lm-desktop-settings/backups"
  backup_dir="$(mktemp -d "$STATE_HOME/lm-desktop-settings/backups/$(date +%Y%m%d-%H%M%S).XXXXXX")"
  dconf dump "$CINNAMON_ROOT" >"$backup_dir/cinnamon.dconf"

  if [[ -f "$FCITX_PROFILE" ]]; then
    install -D -m 0600 "$FCITX_PROFILE" "$backup_dir/fcitx/profile"
  fi

  read_manifest "$SPICE_SETTINGS_MANIFEST" settings_files
  for relative in "${settings_files[@]}"; do
    validate_relative_path "$relative"
    source="$CINNAMON_SPICE_CONFIG/$relative"
    [[ -f "$source" ]] || continue
    install -D -m 0600 "$source" "$backup_dir/cinnamon-spices/$relative"
  done
  printf '%s\n' "$backup_dir"
}

spice_is_installed() {
  validate_spice_uuid "$1"
  [[ -d "/usr/share/cinnamon/applets/$1" || -d "$USER_APPLETS_DIR/$1" ]]
}

install_spice() {
  local uuid="$1"
  local index="$2"
  local file_path archive extract_dir entry
  validate_spice_uuid "$uuid"

  file_path="$(jq -er --arg uuid "$uuid" '.[$uuid].file | select(type == "string")' "$index")" ||
    fail "Cinnamon Spices index has no applet named $uuid"
  [[ "$file_path" == /* ]] || fail "unexpected Cinnamon Spice URL for $uuid"

  archive="$TEMP_DIR/${uuid//[^A-Za-z0-9_.@+-]/_}.zip"
  extract_dir="$TEMP_DIR/${uuid//[^A-Za-z0-9_.@+-]/_}"
  curl -fsSLo "$archive" "${SPICES_HOME_URL}${file_path}"

  while IFS= read -r entry; do
    case "$entry" in
    /* | ../* | */../* | */..)
      fail "unsafe path in Cinnamon Spice archive for $uuid"
      ;;
    esac
    case "$entry" in
    "$uuid" | "$uuid"/*) ;;
    *) fail "unexpected archive layout for Cinnamon Spice $uuid" ;;
    esac
  done < <(unzip -Z1 "$archive")

  mkdir -p -- "$extract_dir" "$USER_APPLETS_DIR"
  unzip -q "$archive" -d "$extract_dir"
  [[ -f "$extract_dir/$uuid/metadata.json" ]] ||
    fail "downloaded Cinnamon Spice $uuid has no metadata"
  jq -e --arg uuid "$uuid" '.uuid == $uuid' "$extract_dir/$uuid/metadata.json" >/dev/null ||
    fail "downloaded Cinnamon Spice metadata does not match $uuid"
  cp -a -- "$extract_dir/$uuid" "$USER_APPLETS_DIR/$uuid"
  ok "installed Cinnamon applet: $uuid"
}

restore_spices() {
  local uuid
  local -a spices=()
  local -a missing=()

  read_manifest "$SPICES_MANIFEST" spices
  for uuid in "${spices[@]}"; do
    if spice_is_installed "$uuid"; then
      ok "Cinnamon applet available: $uuid"
    else
      missing+=("$uuid")
    fi
  done
  ((${#missing[@]} > 0)) || return 0

  require_command curl
  require_command jq
  require_command unzip
  make_temp_dir
  curl -fsSLo "$TEMP_DIR/applets.json" "$SPICES_INDEX_URL"
  for uuid in "${missing[@]}"; do
    install_spice "$uuid" "$TEMP_DIR/applets.json"
  done
}

restore_spice_settings() {
  local relative source destination
  local -a settings_files=()

  read_manifest "$SPICE_SETTINGS_MANIFEST" settings_files
  for relative in "${settings_files[@]}"; do
    validate_relative_path "$relative"
    source="$SPICE_SETTINGS_STATE/$relative"
    require_file "$source"
    destination="$CINNAMON_SPICE_CONFIG/$relative"
    mkdir -p -- "$(dirname -- "$destination")"
    denormalize_stream <"$source" >"$destination"
  done
  ok "Cinnamon applet settings restored"
}

reset_managed_cinnamon() {
  local key path

  for key in "${CINNAMON_ROOT_KEYS[@]}"; do
    dconf reset "${CINNAMON_ROOT}${key}"
  done
  for path in "${CINNAMON_PATHS[@]}"; do
    dconf reset -f "${CINNAMON_ROOT}${path}/"
  done
}

restore() {
  local backup_dir expanded_state

  [[ $EUID -ne 0 ]] || fail "run as your normal user, not with sudo"
  require_command dconf
  require_command im-config
  require_cinnamon_schema
  require_file "$CINNAMON_STATE"
  require_file "$FCITX_PROFILE_STATE"
  require_file "$SPICES_MANIFEST"
  require_file "$SPICE_SETTINGS_MANIFEST"
  make_temp_dir

  say "Backing up current desktop settings"
  backup_dir="$(backup_current_state)"
  ok "backup saved to $backup_dir"

  say "Restoring Cinnamon applets and settings"
  restore_spices
  restore_spice_settings

  say "Restoring Fcitx and Mozc selection"
  mkdir -p -- "$(dirname -- "$FCITX_PROFILE")"
  install -m 0600 "$FCITX_PROFILE_STATE" "$FCITX_PROFILE"
  im-config -n fcitx
  ok "Fcitx selected with the managed input-method profile"

  say "Restoring Cinnamon settings"
  expanded_state="$TEMP_DIR/cinnamon.dconf"
  denormalize_stream <"$CINNAMON_STATE" >"$expanded_state"
  reset_managed_cinnamon
  dconf load -f "$CINNAMON_ROOT" <"$expanded_state"
  ok "Cinnamon desktop settings restored"
  warn "log out and back in before evaluating input methods and the panel"
}

check_fcitx() {
  local expected_im expected_enabled actual_im actual_enabled entry
  local -a entries=()

  has im-config || mark_drift "im-config is not installed"
  has fcitx || mark_drift "Fcitx is not installed"

  if [[ ! -f "$HOME/.xinputrc" ]] ||
    ! grep -Eq '^[[:space:]]*run_im[[:space:]]+fcitx([[:space:]]|$)' "$HOME/.xinputrc"; then
    mark_drift "Fcitx is not selected by im-config"
  fi

  if [[ ! -f "$FCITX_PROFILE" ]]; then
    mark_drift "missing Fcitx profile: $FCITX_PROFILE"
    return
  fi

  expected_im="$(profile_value "$FCITX_PROFILE_STATE" IMName)"
  expected_enabled="$(profile_value "$FCITX_PROFILE_STATE" EnabledIMList)"
  actual_im="$(profile_value "$FCITX_PROFILE" IMName)"
  actual_enabled="$(profile_value "$FCITX_PROFILE" EnabledIMList)"

  [[ "$actual_im" == "$expected_im" ]] ||
    mark_drift "Fcitx active method is $actual_im; expected $expected_im"

  IFS=',' read -r -a entries <<<"$expected_enabled"
  for entry in "${entries[@]}"; do
    [[ ",$actual_enabled," == *",$entry,"* ]] ||
      mark_drift "Fcitx method is not enabled: ${entry%:True}"
  done
}

check_spices() {
  local uuid relative current_normalized
  local -a spices=()
  local -a settings_files=()

  read_manifest "$SPICES_MANIFEST" spices
  for uuid in "${spices[@]}"; do
    spice_is_installed "$uuid" || mark_drift "missing Cinnamon applet: $uuid"
  done

  read_manifest "$SPICE_SETTINGS_MANIFEST" settings_files
  for relative in "${settings_files[@]}"; do
    validate_relative_path "$relative"
    if [[ ! -f "$CINNAMON_SPICE_CONFIG/$relative" ]]; then
      mark_drift "missing Cinnamon applet settings: $relative"
      continue
    fi
    current_normalized="$TEMP_DIR/current-spice/$relative"
    mkdir -p -- "$(dirname -- "$current_normalized")"
    normalize_stream <"$CINNAMON_SPICE_CONFIG/$relative" >"$current_normalized"
    cmp -s -- "$SPICE_SETTINGS_STATE/$relative" "$current_normalized" ||
      mark_drift "Cinnamon applet settings differ: $relative"
  done
  return 0
}

check() {
  local current_cinnamon

  [[ $EUID -ne 0 ]] || fail "run as your normal user, not with sudo"
  require_file "$CINNAMON_STATE"
  require_file "$FCITX_PROFILE_STATE"
  require_file "$SPICES_MANIFEST"
  require_file "$SPICE_SETTINGS_MANIFEST"
  make_temp_dir

  say "Checking desktop settings"
  if ! has dconf || ! has gsettings ||
    ! gsettings list-schemas 2>/dev/null | grep -Fx org.cinnamon >/dev/null; then
    mark_drift "Cinnamon and dconf are not fully installed"
  else
    current_cinnamon="$TEMP_DIR/current-cinnamon.dconf"
    capture_cinnamon_to "$current_cinnamon"
    cmp -s -- "$CINNAMON_STATE" "$current_cinnamon" ||
      mark_drift "Cinnamon settings differ from the managed snapshot"
  fi

  check_fcitx
  check_spices

  if ((DRIFT != 0)); then
    warn "desktop settings drift detected"
    return 1
  fi
  ok "desktop settings match the managed snapshot"
}

main() {
  [[ $# -eq 1 ]] || {
    usage >&2
    exit 1
  }

  case "$1" in
  capture) capture ;;
  capture-keybindings) capture_keybindings ;;
  restore) restore ;;
  check) check ;;
  check-keybindings) check_keybindings ;;
  help | -h | --help) usage ;;
  *)
    usage >&2
    fail "unknown command: $1"
    ;;
  esac
}

main "$@"

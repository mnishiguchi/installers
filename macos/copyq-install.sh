#!/usr/bin/env bash
# Install/verify the official CopyQ macOS DMG with explicit signature recovery.
# Compatible with the macOS system Bash 3.2.
set -euo pipefail

readonly VERSION="17.0.0"
readonly RELEASE_BASE="https://github.com/hluk/CopyQ/releases/download/v${VERSION}"
readonly CHECKSUMS_ASSET="checksums-sha512.txt"
readonly APP_NAME="CopyQ.app"
readonly CLI_LINK_DEFAULT="$HOME/.local/bin/copyq"

say() { printf '%s\n' "$*"; }
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'USAGE'
Usage: copyq-install.sh [--check | install | repair-signature]

  --check  Verify the CopyQ app bundle and user-local CLI link without launching it.
  install  Open the official DMG download, verify SHA-512/quarantine, and install.
  repair-signature  Explicitly repair the known upstream nested-signature issue.

Normal installation preserves quarantine and does not modify code signatures.
The opt-in repair mode verifies the official DMG, compares the installed app
with that release bundle, then removes this app's quarantine marker and applies
a local ad-hoc signature. This is not Developer ID signing or notarization.
Environment overrides for testing/managed locations:
  COPYQ_APP_PATH   Full destination path for CopyQ.app.
  COPYQ_CLI_LINK   Destination path for the copyq CLI symlink.
  COPYQ_DMG_PATH   Path to a DMG downloaded by a browser (must carry quarantine).
USAGE
}

mode=--check
if [[ $# -gt 1 ]]; then usage >&2; exit 2; fi
if [[ $# -eq 1 ]]; then
  case "$1" in
    --check|check) mode=--check ;;
    install) mode=install ;;
    repair-signature) mode=repair-signature ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
fi

[[ "$(uname -s)" == Darwin ]] || fail 'macOS is required.'

cli_link=${COPYQ_CLI_LINK:-$CLI_LINK_DEFAULT}
if [[ -n "${COPYQ_APP_PATH:-}" ]]; then
  app_path=$COPYQ_APP_PATH
elif [[ -d "/Applications/$APP_NAME" ]]; then
  app_path="/Applications/$APP_NAME"
elif [[ -d "$HOME/Applications/$APP_NAME" ]]; then
  app_path="$HOME/Applications/$APP_NAME"
elif [[ -w /Applications ]]; then
  app_path="/Applications/$APP_NAME"
else
  app_path="$HOME/Applications/$APP_NAME"
fi
app_binary="$app_path/Contents/MacOS/CopyQ"
info_plist="$app_path/Contents/Info.plist"

read_app_version() {
  [[ -f "$info_plist" ]] || return 1
  defaults read "$app_path/Contents/Info" CFBundleShortVersionString 2>/dev/null
}

# macOS bundle metadata may omit a final zero patch component (17.0 vs 17.0.0).
version_matches() {
  [[ "$1" == "$VERSION" || ( "$VERSION" == *.0 && "$1" == "${VERSION%.0}" ) ]]
}

signature_is_valid() {
  command -v codesign >/dev/null 2>&1 || {
    say 'ERROR: codesign is unavailable; cannot verify CopyQ code signatures.'
    return 1
  }
  if ! codesign --verify --deep --strict "$app_path" >/dev/null 2>&1; then
    say 'ERROR: CopyQ nested code-signature integrity verification failed.'
    say 'The upstream release may contain the known macOS nested-signature issue.'
    say 'After verifying the official DMG, review: repair-signature'
    return 1
  fi
  local signature_details
  signature_details=$(codesign -dv --verbose=4 "$app_path" 2>&1 || true)
  if [[ "$signature_details" == *'Signature=adhoc'* ]]; then
    say 'OK: CopyQ code signature integrity passes (ad-hoc; not Developer ID signed or notarized).'
  else
    say 'OK: CopyQ code signature integrity passes.'
  fi
  if xattr -p com.apple.quarantine "$app_path" >/dev/null 2>&1; then
    say 'NOTICE: CopyQ still has a quarantine marker; macOS may require manual first-launch approval.'
  fi
}

check_installation() {
  local installed_version
  if [[ ! -x "$app_binary" ]]; then
    say "CopyQ application not found or not executable: $app_path"
    return 1
  fi
  installed_version=$(read_app_version) || {
    say "Cannot read CopyQ version from: $info_plist"
    return 1
  }
  if ! version_matches "$installed_version"; then
    say "CopyQ version mismatch: found $installed_version; expected $VERSION"
    return 1
  fi
  if [[ ! -L "$cli_link" || ! "$cli_link" -ef "$app_binary" ]]; then
    say "CopyQ CLI link is missing or incorrect: $cli_link"
    return 1
  fi
  say "OK: CopyQ $installed_version installed at $app_path"
  say "OK: copyq CLI link -> $app_binary"
  signature_is_valid
}

if [[ "$mode" == --check ]]; then
  check_installation
  exit $?
fi

[[ $EUID -ne 0 ]] || fail 'Run as your normal user, not with sudo.'
macos_version=$(sw_vers -productVersion) || fail 'Cannot determine macOS version.'
macos_major=${macos_version%%.*}
if [[ ! "$macos_major" =~ ^[0-9]+$ ]] || ((macos_major < 13)); then
  fail "CopyQ $VERSION requires macOS 13 or newer (found $macos_version)."
fi

if [[ "$mode" == install && -x "$app_binary" ]]; then
  installed_version=$(read_app_version) || fail "Cannot read existing CopyQ version: $app_path"
  version_matches "$installed_version" || fail "CopyQ $installed_version already exists at $app_path. Back it up or move it aside before installing $VERSION; this script will not overwrite it."
  if [[ -L "$cli_link" && "$cli_link" -ef "$app_binary" ]]; then
    say "CopyQ $VERSION is already installed."
    check_installation
    exit $?
  fi
  if [[ -e "$cli_link" || -L "$cli_link" ]]; then
    fail "Refusing to replace an existing CLI path: $cli_link"
  fi
  mkdir -p "$(dirname "$cli_link")"
  ln -s "$app_binary" "$cli_link"
  say "Created CLI link for existing CopyQ $VERSION: $cli_link"
  check_installation
  exit $?
elif [[ "$mode" == install && ( -e "$app_path" || -L "$app_path" ) ]]; then
  fail "Destination exists but is not a valid CopyQ app bundle: $app_path"
fi

case "$(uname -m)" in
  arm64) asset="CopyQ-${VERSION}-macos-13-m1.dmg" ;;
  x86_64) asset="CopyQ-${VERSION}-macos-13.dmg" ;;
  *) fail "Unsupported Mac architecture: $(uname -m)" ;;
esac

for tool in curl shasum hdiutil ditto defaults open xattr codesign diff pgrep; do
  command -v "$tool" >/dev/null 2>&1 || fail "Required macOS tool not found: $tool"
done

if [[ "$mode" == repair-signature ]]; then
  [[ -x "$app_binary" ]] || fail "CopyQ application not found or not executable: $app_path"
  installed_version=$(read_app_version) || fail "Cannot read CopyQ version from: $info_plist"
  version_matches "$installed_version" || fail "CopyQ version mismatch: found $installed_version; expected $VERSION"
  if signature_is_valid; then
    say 'No signature repair is needed; the existing bundle passes strict verification.'
    exit 0
  fi
  pgrep -x CopyQ >/dev/null 2>&1 && fail 'Quit CopyQ before signature repair; this script will not terminate it.'
  [[ -w "$app_path" ]] || fail "CopyQ application is not writable by the current user: $app_path"

  cat <<NOTICE
CopyQ signature repair is an explicit security exception.

It verifies the official DMG checksum, compares the installed app with the app
in that release, removes this CopyQ.app quarantine marker, and applies a local
ad-hoc signature. It does NOT create a Developer ID signature or notarize CopyQ.
The quarantine protection for this app will be removed. Do not proceed unless
you accept this application-specific security trade-off.

Application: $app_path
Source DMG:  ${COPYQ_DMG_PATH:-$HOME/Downloads/$asset}
NOTICE
  printf 'Type REPAIR COPYQ SIGNATURE to continue, or press Enter to cancel: '
  IFS= read -r confirmation
  [[ "$confirmation" == 'REPAIR COPYQ SIGNATURE' ]] || { say 'Cancelled.'; exit 0; }

  work_dir=$(mktemp -d "${TMPDIR:-/tmp}/copyq-repair.XXXXXX") || fail 'Cannot create temporary directory.'
  mount_point="$work_dir/mount"
  mounted=false
  # Called by the EXIT trap.
  # shellcheck disable=SC2317,SC2329
  cleanup() {
    if [[ "$mounted" == true ]]; then hdiutil detach -quiet "$mount_point" >/dev/null 2>&1 || true; fi
    if [[ -d "$work_dir" ]]; then rm -rf -- "$work_dir"; fi
  }
  trap cleanup EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  mkdir -p "$mount_point"

  dmg_path=${COPYQ_DMG_PATH:-"$HOME/Downloads/$asset"}
  case "$dmg_path" in \~/*) dmg_path="$HOME/${dmg_path#\~/}" ;; esac
  [[ -f "$dmg_path" ]] || fail "Official browser-downloaded DMG not found: $dmg_path (set COPYQ_DMG_PATH if stored elsewhere)."
  quarantine_value=$(xattr -p com.apple.quarantine "$dmg_path" 2>/dev/null) || fail 'The source DMG has no quarantine attribute; use the original browser-downloaded DMG.'
  [[ -n "$quarantine_value" ]] || fail 'The source DMG quarantine attribute is empty.'
  say 'Downloading the official SHA-512 checksum manifest...'
  curl --fail --location --proto '=https' --tlsv1.2 --retry 2 --silent --show-error \
    --output "$work_dir/$CHECKSUMS_ASSET" "$RELEASE_BASE/$CHECKSUMS_ASSET"
  expected_checksum=$(awk -v asset="$asset" '
    {
      first=$1; second=$2
      sub(/^\*/, "", second)
      if (second == asset) { print first; found=1; exit }
      if (first == asset && second != "") { print second; found=1; exit }
    }
    END { if (!found) exit 1 }
  ' "$work_dir/$CHECKSUMS_ASSET") || fail "No SHA-512 checksum found for $asset in the official manifest."
  [[ "$expected_checksum" =~ ^[[:xdigit:]]{128}$ ]] || fail 'The published SHA-512 checksum has an unexpected format.'
  printf '%s  %s\n' "$expected_checksum" "$dmg_path" | shasum -a 512 -c - || fail 'CopyQ DMG SHA-512 verification failed.'
  say 'Mounting the verified DMG read-only...'
  hdiutil attach -quiet -nobrowse -readonly -mountpoint "$mount_point" "$dmg_path"
  mounted=true
  app_source="$mount_point/$APP_NAME"
  [[ -d "$app_source" && -x "$app_source/Contents/MacOS/CopyQ" ]] || fail "CopyQ.app not found in the official DMG: $asset"
  source_version=$(defaults read "$app_source/Contents/Info" CFBundleShortVersionString 2>/dev/null) || fail 'Cannot read version from the downloaded CopyQ app.'
  version_matches "$source_version" || fail "Downloaded app version mismatch: $source_version"
  say 'Comparing installed CopyQ with the checksum-verified release bundle...'
  diff -qr "$app_source" "$app_path" >/dev/null || fail 'Installed CopyQ differs from the verified DMG. Reinstall from the official DMG before signature repair.'
  say 'OK: installed app contents match the checksum-verified release bundle.'
  hdiutil detach -quiet "$mount_point"
  mounted=false

  original_app_quarantine=''
  if original_app_quarantine=$(xattr -p com.apple.quarantine "$app_path" 2>/dev/null); then
    xattr -d com.apple.quarantine "$app_path" || fail 'Could not remove the CopyQ app quarantine attribute.'
  else
    say 'CopyQ app quarantine attribute is already absent.'
  fi
  say 'Applying the documented local ad-hoc signature workaround...'
  if ! codesign --force --deep --sign - "$app_path"; then
    if [[ -n "$original_app_quarantine" ]]; then
      xattr -w com.apple.quarantine "$original_app_quarantine" "$app_path" || true
    fi
    fail 'Ad-hoc signing failed. The original quarantine marker was restored when available; reinstall from the verified DMG if necessary.'
  fi
  if ! codesign --verify --deep --strict --verbose=2 "$app_path"; then
    if [[ -n "$original_app_quarantine" ]]; then
      xattr -w com.apple.quarantine "$original_app_quarantine" "$app_path" || true
    fi
    fail 'Post-repair nested signature verification failed. The original quarantine marker was restored when available.'
  fi
  signature_details=$(codesign -dv --verbose=4 "$app_path" 2>&1 || true)
  if [[ "$signature_details" != *'Signature=adhoc'* ]]; then
    if [[ -n "$original_app_quarantine" ]]; then
      xattr -w com.apple.quarantine "$original_app_quarantine" "$app_path" || true
    fi
    fail 'The repaired bundle does not report an ad-hoc signature as expected. The original quarantine marker was restored when available.'
  fi
  say 'OK: nested code signatures pass strict integrity verification.'
  say 'NOTE: CopyQ is ad-hoc signed, not Developer ID signed or Apple-notarized.'
  say 'The quarantine marker was removed only from this checksum-verified CopyQ.app bundle.'
  say 'Next: launch CopyQ manually and run the installer --check.'
  exit 0
fi

cat <<NOTICE
CopyQ $VERSION will be installed from the official hluk/CopyQ GitHub release.
The upstream macOS app is unsigned/not notarized and fails the Homebrew
Gatekeeper requirement. The installer does not bypass Gatekeeper. It requires
a browser-downloaded DMG with its quarantine attribute, verifies the official
SHA-512 checksum, and propagates that quarantine attribute to the copied app.
First launch may require right-click > Open; review the warning before approval.

Destination: $app_path
CLI link:    $cli_link
NOTICE
printf 'Type INSTALL COPYQ to continue, or press Enter to cancel: '
IFS= read -r confirmation
[[ "$confirmation" == 'INSTALL COPYQ' ]] || { say 'Cancelled.'; exit 0; }

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/copyq-install.XXXXXX") || fail 'Cannot create temporary directory.'
mount_point="$work_dir/mount"
staged_app=''
mounted=false
cleanup() {
  if [[ "$mounted" == true ]]; then hdiutil detach -quiet "$mount_point" >/dev/null 2>&1 || true; fi
  if [[ -n "${staged_app:-}" && -e "$staged_app" ]]; then rm -rf -- "$staged_app"; fi
  if [[ -n "${work_dir:-}" && -d "$work_dir" ]]; then rm -rf -- "$work_dir"; fi
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -p "$mount_point"

dmg_path=${COPYQ_DMG_PATH:-"$HOME/Downloads/$asset"}
if [[ ! -f "$dmg_path" ]]; then
  say "Opening the official DMG download in your browser: $asset"
  open "$RELEASE_BASE/$asset"
  printf 'Path to the browser-downloaded DMG [%s]: ' "$dmg_path"
  IFS= read -r supplied_path
  [[ -n "$supplied_path" ]] && dmg_path=$supplied_path
fi
case "$dmg_path" in
  \~/*) dmg_path="$HOME/${dmg_path#\~/}" ;;
esac
[[ -f "$dmg_path" ]] || fail "DMG file not found: $dmg_path"
quarantine_value=$(xattr -p com.apple.quarantine "$dmg_path" 2>/dev/null) || fail 'The DMG has no macOS quarantine attribute. Download it with a browser; refusing to install an unquarantined app.'
[[ -n "$quarantine_value" ]] || fail 'The DMG quarantine attribute is empty; refusing to install.'

say 'Downloading the official SHA-512 checksum manifest...'
curl --fail --location --proto '=https' --tlsv1.2 --retry 2 --silent --show-error \
  --output "$work_dir/$CHECKSUMS_ASSET" "$RELEASE_BASE/$CHECKSUMS_ASSET"

expected_checksum=$(awk -v asset="$asset" '
  {
    first=$1; second=$2
    sub(/^\*/, "", second)
    if (second == asset) { print first; found=1; exit }
    if (first == asset && second != "") { print second; found=1; exit }
  }
  END { if (!found) exit 1 }
' "$work_dir/$CHECKSUMS_ASSET") || fail "No SHA-512 checksum found for $asset in the official manifest."
[[ "$expected_checksum" =~ ^[[:xdigit:]]{128}$ ]] || fail 'The published SHA-512 checksum has an unexpected format.'
printf '%s  %s\n' "$expected_checksum" "$dmg_path" | shasum -a 512 -c - || fail 'CopyQ DMG SHA-512 verification failed.'

say 'Mounting the verified DMG read-only...'
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$mount_point" "$dmg_path"
mounted=true
app_source="$mount_point/$APP_NAME"
[[ -d "$app_source" && -x "$app_source/Contents/MacOS/CopyQ" ]] || fail "CopyQ.app not found in the official DMG: $asset"
source_version=$(defaults read "$app_source/Contents/Info" CFBundleShortVersionString 2>/dev/null) || fail 'Cannot read version from the downloaded CopyQ app.'
version_matches "$source_version" || fail "Downloaded app version mismatch: $source_version"

app_parent=$(dirname "$app_path")
mkdir -p "$app_parent" "$(dirname "$cli_link")"
# Stage beside the destination so the final rename stays on the same volume.
staged_app="$app_parent/.CopyQ.app.install.$$"
[[ ! -e "$staged_app" && ! -L "$staged_app" ]] || fail "Temporary destination already exists: $staged_app"
ditto "$app_source" "$staged_app"
# The browser-download quarantine marker is copied explicitly to the app bundle.
xattr -w com.apple.quarantine "$quarantine_value" "$staged_app"
copied_quarantine=$(xattr -p com.apple.quarantine "$staged_app" 2>/dev/null) || fail 'Could not verify the quarantine attribute on the staged app.'
[[ "$copied_quarantine" == "$quarantine_value" ]] || fail 'The staged app quarantine attribute does not match the browser-downloaded DMG.'
[[ ! -e "$app_path" && ! -L "$app_path" ]] || fail "Application destination appeared during installation: $app_path"

# Recover only the exact dangling link created by this installer. Never replace
# a regular file, a live link, or a symlink that points anywhere else.
if [[ -L "$cli_link" && ! -e "$cli_link" ]]; then
  existing_target=$(readlink "$cli_link") || fail "Cannot inspect existing CLI symlink: $cli_link"
  [[ "$existing_target" == "$app_binary" ]] || fail "Refusing to replace unrelated dangling CLI symlink: $cli_link -> $existing_target"
  say "Removing recognized stale CopyQ CLI symlink: $cli_link"
  unlink "$cli_link"
elif [[ -e "$cli_link" || -L "$cli_link" ]]; then
  fail "Refusing to replace an existing CLI path: $cli_link"
fi

mv "$staged_app" "$app_path"
staged_app=''
ln -s "$app_binary" "$cli_link"

say "Installed CopyQ $VERSION at $app_path"
say "Created CLI link: $cli_link"
say 'The browser quarantine marker was preserved; normal install did not modify code signatures.'
if ! codesign --verify --deep --strict "$app_path" >/dev/null 2>&1; then
  say 'NOTICE: this upstream release fails strict nested code-signature verification on this macOS build.'
  say 'If you accept the application-specific security exception, review: repair-signature'
fi
say 'Next: review macOS first-launch approval and Accessibility permission manually.'
say 'Add CopyQ under System Settings > General > Login Items if you want it to start at login.'

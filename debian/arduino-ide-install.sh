#!/bin/sh
#
# Install or update Arduino IDE 2 for the current user on Debian-based Linux.
#
# - Installs the official Linux ZIP under ~/.local/opt
# - Creates ~/.local/bin/arduino-ide
# - Installs a per-user desktop entry and themed icon
# - Does not require root privileges
#
set -eu

readonly RELEASES_URL="https://github.com/arduino/arduino-ide/releases/latest"
readonly RELEASES_API_URL="https://api.github.com/repos/arduino/arduino-ide/releases/tags"
readonly DOWNLOAD_BASE_URL="https://downloads.arduino.cc/arduino-ide"
readonly MANAGED_MARKER=".installed-by-mnishiguchi-installers"

version="${ARDUINO_IDE_VERSION:-}"
expected_sha256="${ARDUINO_IDE_SHA256:-}"
dry_run=false
temp_dir=""

usage() {
  cat <<'USAGE'
Usage: arduino-ide-install.sh [--version VERSION] [--dry-run]

Install or update the official Arduino IDE for the current user.

Options:
  --version VERSION  Install a specific version instead of the latest release
  --dry-run          Print the planned paths and URL without changing anything
  -h, --help         Show this help

Environment:
  ARDUINO_IDE_VERSION       Alternative way to specify the version
  ARDUINO_IDE_SHA256        Expected SHA-256 digest (overrides API discovery)
  ARDUINO_IDE_INSTALL_ROOT  Installation root (default: ~/.local/opt)
  ARDUINO_IDE_BIN_DIR       Command directory (default: ~/.local/bin)
  XDG_DATA_HOME             XDG data directory (default: ~/.local/share)
USAGE
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 ||
    die "required command not found: $1"
}

require_absolute_path() {
  case "$2" in
    /*) ;;
    *) die "$1 must be an absolute path: $2" ;;
  esac
}

canonicalize_path() {
  require_command readlink
  readlink -m -- "$1"
}

validate_sha256() {
  digest=$1

  case "$digest" in
    *[!0-9a-fA-F]*) return 1 ;;
  esac

  [ "${#digest}" -eq 64 ]
}

resolve_expected_sha256() {
  if [ -n "$expected_sha256" ]; then
    validate_sha256 "$expected_sha256" ||
      die "ARDUINO_IDE_SHA256 must contain exactly 64 hexadecimal characters"
    expected_sha256=$(printf '%s' "$expected_sha256" | tr '[:upper:]' '[:lower:]')
    return
  fi

  if ! command -v sha256sum >/dev/null 2>&1; then
    printf 'Warning: SHA-256 verification skipped; sha256sum was not found.\n' >&2
    return
  fi

  if ! command -v jq >/dev/null 2>&1; then
    printf 'Warning: SHA-256 verification skipped; jq was not found.\n' >&2
    return
  fi

  printf 'Finding the official SHA-256 digest...\n'

  if ! release_json=$(
    curl \
      --fail \
      --silent \
      --show-error \
      --location \
      "$RELEASES_API_URL/$version"
  ); then
    printf 'Warning: SHA-256 verification skipped; release metadata was unavailable.\n' >&2
    return
  fi

  release_digest=$(
    printf '%s\n' "$release_json" |
      jq -r --arg name "$archive_name" \
        '.assets[] | select(.name == $name) | .digest // empty' |
      head -n 1
  )

  case "$release_digest" in
    sha256:*) expected_sha256=${release_digest#sha256:} ;;
    *)
      printf 'Warning: SHA-256 verification skipped; the release has no digest for %s.\n' \
        "$archive_name" >&2
      return
      ;;
  esac

  validate_sha256 "$expected_sha256" ||
    die "the release API returned an invalid SHA-256 digest"
}

verify_archive_sha256() {
  archive_path=$1

  [ -n "$expected_sha256" ] || return
  require_command sha256sum

  actual_sha256=$(sha256sum "$archive_path")
  actual_sha256=${actual_sha256%% *}

  [ "$actual_sha256" = "$expected_sha256" ] ||
    die "SHA-256 mismatch for $archive_name"

  printf 'Verified SHA-256: %s\n' "$expected_sha256"
}

cleanup() {
  if [ -n "$temp_dir" ] && [ -d "$temp_dir" ]; then
    rm -rf -- "$temp_dir"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      [ "$#" -ge 2 ] || die "--version requires a value"
      version=$2
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[ "$(id -u)" -ne 0 ] ||
  die "do not run this per-user installer as root or with sudo"

[ "$(uname -s)" = "Linux" ] ||
  die "this script supports Linux only"

case "$(uname -m)" in
  x86_64 | amd64) ;;
  *)
    die "Arduino IDE 2 is distributed for Linux x86-64; this CPU is $(uname -m)"
    ;;
esac

if [ -z "$version" ]; then
  require_command curl

  printf 'Finding the latest Arduino IDE release...\n'

  latest_url=$(
    curl \
      --fail \
      --silent \
      --show-error \
      --location \
      --output /dev/null \
      --write-out '%{url_effective}' \
      "$RELEASES_URL"
  )

  version=${latest_url##*/}
fi

version=${version#v}

case "$version" in
  '' | *[!0-9.]* | .* | *. | *..*)
    die "invalid version: $version"
    ;;
esac

: "${HOME:?HOME must be set}"

data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
install_root=${ARDUINO_IDE_INSTALL_ROOT:-"$HOME/.local/opt"}
bin_dir=${ARDUINO_IDE_BIN_DIR:-"$HOME/.local/bin"}

require_absolute_path ARDUINO_IDE_INSTALL_ROOT "$install_root"
require_absolute_path ARDUINO_IDE_BIN_DIR "$bin_dir"
require_absolute_path XDG_DATA_HOME "$data_home"

install_root=$(canonicalize_path "$install_root")
bin_dir=$(canonicalize_path "$bin_dir")
data_home=$(canonicalize_path "$data_home")

[ "$install_root" != "$bin_dir" ] ||
  die "ARDUINO_IDE_INSTALL_ROOT and ARDUINO_IDE_BIN_DIR must be different directories"

install_dir="$install_root/arduino-ide-$version"
stable_link="$install_root/arduino-ide"
command_link="$bin_dir/arduino-ide"
desktop_dir="$data_home/applications"
desktop_file="$desktop_dir/arduino-ide.desktop"
icon_dir="$data_home/icons/hicolor/512x512/apps"
icon_path="$icon_dir/arduino-ide.png"
bundled_icon_path="$install_dir/resources/app/resources/icons/512x512.png"
marker_file="$install_dir/$MANAGED_MARKER"

archive_name="arduino-ide_${version}_Linux_64bit.zip"
download_url="$DOWNLOAD_BASE_URL/$archive_name"

printf '%s\n' \
  "Version:      $version" \
  "Download:     $download_url" \
  "Install to:   $install_dir" \
  "Stable link:  $stable_link" \
  "Command link: $command_link" \
  "App launcher: $desktop_file" \
  "App icon:     $icon_path"

[ "$dry_run" = false ] || exit 0

require_command curl
require_command find
require_command mktemp
require_command unzip

# Refuse to replace paths that are not managed as links by this installer.
if { [ -e "$stable_link" ] || [ -L "$stable_link" ]; } &&
  [ ! -L "$stable_link" ]; then
  die "will not replace non-symlink path: $stable_link"
fi

if { [ -e "$command_link" ] || [ -L "$command_link" ]; } &&
  [ ! -L "$command_link" ]; then
  die "will not replace non-symlink path: $command_link"
fi

desktop_is_managed=false

if [ -e "$desktop_file" ] || [ -L "$desktop_file" ]; then
  if [ ! -f "$desktop_file" ] || [ -L "$desktop_file" ]; then
    die "will not replace non-regular launcher: $desktop_file"
  fi

  if grep -Fqx 'X-Mnishiguchi-Installer=arduino-ide' "$desktop_file"; then
    desktop_is_managed=true
  else
    die "will not replace launcher not created by this installer: $desktop_file"
  fi
fi

if [ -e "$icon_path" ] || [ -L "$icon_path" ]; then
  if [ ! -f "$icon_path" ] || [ -L "$icon_path" ]; then
    die "will not replace non-regular icon: $icon_path"
  fi

  [ "$desktop_is_managed" = true ] ||
    die "will not replace icon not created by this installer: $icon_path"
fi

# Install the version into a temporary directory on the destination filesystem,
# then move it into place so an interrupted download cannot leave a partial app.
if [ -L "$install_dir" ]; then
  die "install path is a symlink: $install_dir"
elif [ -d "$install_dir" ]; then
  [ -f "$marker_file" ] ||
    die "install directory was not created by this installer: $install_dir"

  [ -x "$install_dir/arduino-ide" ] ||
    die "install directory exists but has no executable: $install_dir/arduino-ide"

  printf 'Reusing existing installation: %s\n' "$install_dir"
elif [ -e "$install_dir" ]; then
  die "install path exists but is not a directory: $install_dir"
else
  mkdir -p "$install_root"
  temp_dir=$(mktemp -d "$install_root/.arduino-ide-install.XXXXXX")
  trap cleanup EXIT
  trap 'exit 1' HUP INT TERM

  printf 'Downloading Arduino IDE %s...\n' "$version"

  resolve_expected_sha256

  curl \
    --fail \
    --location \
    --show-error \
    --retry 3 \
    --output "$temp_dir/$archive_name" \
    "$download_url"

  verify_archive_sha256 "$temp_dir/$archive_name"

  unzip -q -t "$temp_dir/$archive_name" ||
    die "downloaded archive failed its integrity test"

  mkdir -p "$temp_dir/extracted"
  unzip -q "$temp_dir/$archive_name" -d "$temp_dir/extracted"

  executable=$(
    find "$temp_dir/extracted" \
      -type f \
      -name arduino-ide \
      -perm -u+x \
      -print \
      -quit
  )

  [ -n "$executable" ] ||
    die "the archive does not contain an Arduino IDE executable"

  extracted_dir=${executable%/*}
  mv "$extracted_dir" "$install_dir"
fi

[ -x "$install_dir/arduino-ide" ] ||
  die "Arduino IDE executable is missing: $install_dir/arduino-ide"

[ -f "$bundled_icon_path" ] ||
  die "Arduino IDE icon is missing from: $install_dir"

# This marker lets the uninstaller distinguish our version directories from
# similarly named directories created by the user.
: >"$marker_file"

mkdir -p "$bin_dir" "$desktop_dir" "$icon_dir"
ln -sfn "$install_dir" "$stable_link"
ln -sfn "$stable_link/arduino-ide" "$command_link"
cp "$bundled_icon_path" "$icon_path"
chmod 0644 "$icon_path"

cat >"$desktop_file" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Arduino IDE
GenericName=Integrated Development Environment
Comment=Open-source electronics prototyping platform
Exec="$command_link" %U
TryExec=$command_link
Icon=arduino-ide
Terminal=false
Categories=Development;IDE;Electronics;
MimeType=text/x-arduino;
Keywords=embedded;electronics;avr;microcontroller;
StartupNotify=true
StartupWMClass=Arduino IDE
X-Mnishiguchi-Installer=arduino-ide
EOF

chmod 0644 "$desktop_file"

if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$desktop_file" ||
    die "generated desktop entry failed validation: $desktop_file"
fi

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$desktop_dir" ||
    printf 'Warning: could not refresh the desktop MIME cache.\n' >&2
fi

printf '\nInstalled Arduino IDE %s.\n' "$version"
printf 'Command:  arduino-ide\n'
printf 'Launcher: %s\n' "$desktop_file"

case ":$PATH:" in
  *:"$bin_dir":*) ;;
  *)
    printf '\nNote: add %s to PATH to use the command.\n' "$bin_dir"
    ;;
esac

#!/usr/bin/env bash
# Optional native ARM64 standalone 1Password installer for Fedora.
set -Eeuo pipefail

app_dir=/opt/1Password
launcher=/usr/bin/1password
key_fingerprint=3FEF9748469ADBE15DA7CA80AC2D62742012EA22
base_url=https://downloads.1password.com/linux
archive_url=$base_url/tar/stable/aarch64/1password-latest.tar.gz

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'HELP'
Usage: fedora/1password.sh [--check | --update | --help]
  (no option)  Install if absent; leave a healthy installation unchanged.
  --check      Verify local standalone layout and version; no network or sudo.
  --update     Verify and install a newer official stable ARM64 archive.
Run as your regular user. Quit 1Password completely before installing/updating.
HELP
}

native_binary() {
  local description
  description=$(LC_ALL=C file -bL -- "$1") || return 1
  [[ $description == 'ELF 64-bit'* && $description == *aarch64* ]]
}

installed_version() {
  local version
  [[ -d $app_dir && ! -L $app_dir && -f $app_dir/1password &&
    ! -L $app_dir/1password && -x $app_dir/1password &&
    -f $app_dir/after-install.sh && ! -L $app_dir/after-install.sh &&
    -x $app_dir/after-install.sh && -L $launcher &&
    $(readlink -- "$launcher") == "$app_dir/1password" ]] || return 1
  [[ $(stat -c '%u' -- "$app_dir") == 0 &&
    $(stat -c '%u' -- "$app_dir/1password") == 0 &&
    $(stat -c '%u' -- "$app_dir/after-install.sh") == 0 ]] || return 1
  native_binary "$app_dir/1password" || return 1
  version=$("$launcher" --version) || return 1
  [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  printf '%s\n' "$version"
}

ensure_closed() {
  if pgrep -x 1password >/dev/null || pgrep -f '^/opt/1Password/' >/dev/null; then
    fail 'Quit 1Password completely (including the tray) and retry.'
  fi
}

verify_archive() {
  local work=$1 fingerprints
  local -a gpg_cmd=(gpg --batch --no-options --homedir "$work/gnupg")
  mkdir -m 700 -- "$work/gnupg"
  # Require exactly the published primary key, not merely a matching key
  # somewhere in a downloaded bundle. Signing subkeys are allowed.
  fingerprints=$("${gpg_cmd[@]}" --with-colons --show-keys "$work/key.asc" |
    awk -F: '$1=="pub" { primary=1; next } $1=="fpr" && primary {print $10; primary=0}') ||
    fail 'Cannot inspect signing key.'
  [[ $fingerprints == "$key_fingerprint" ]] || fail 'Unexpected signing key fingerprint.'
  "${gpg_cmd[@]}" --import "$work/key.asc" || fail 'Signing key import failed.'
  "${gpg_cmd[@]}" --no-auto-key-retrieve --verify "$work/archive.sig" "$work/archive.tar.gz" ||
    fail 'Archive signature verification failed.'
}

install_tree() {
  local source=$1 previous=$2 expected=$3 stage actual
  stage=$(sudo mktemp -d /opt/.1password-stage.XXXXXXXX) || fail 'Cannot create installation staging directory.'
  printf 'Root-owned staging directory: %s\n' "$stage"
  # Keep the old tree intact until the new release is staged.
  sudo mkdir -- "$stage/new"
  sudo cp -a --no-preserve=ownership -- "$source/." "$stage/new/"
  ensure_closed
  if [[ -n $previous ]]; then
    sudo mv -T -- "$app_dir" "$stage/previous"
  fi
  if ! sudo mv -T -- "$stage/new" "$app_dir"; then
    if [[ -n $previous ]]; then sudo mv -T -- "$stage/previous" "$app_dir"; fi
    fail "Could not activate the new release; inspect $stage."
  fi
  if ! sudo "$app_dir/after-install.sh" || ! actual=$(installed_version) || [[ $actual != "$expected" ]]; then
    # Keep both trees for inspection on failure; restore the previous binaries.
    sudo mv -T -- "$app_dir" "$stage/failed"
    if [[ -n $previous ]]; then sudo mv -T -- "$stage/previous" "$app_dir"; fi
    fail "Installation/integration check failed. Inspect $stage; vendor integration side effects may need manual repair."
  fi
  sudo rm -rf -- "$stage"
  printf '1Password %s (native ARM64 standalone)\n' "$actual"
}

is_supported_fedora() {
  grep -Eq '^ID=(fedora|fedora-asahi-remix|"fedora"|"fedora-asahi-remix")$' "$1"
}

require_platform() {
  [[ $EUID != 0 ]] || fail 'Run as a regular user, not root.'
  [[ $(uname -s) == Linux && $(uname -m) == aarch64 ]] || fail 'This script supports Fedora ARM64 only.'
  is_supported_fedora /etc/os-release || fail 'This script supports Fedora and Fedora Asahi Remix only.'
}

main() {
  local mode=${1:-} current='' work candidate name rpm_status=0
  if (( $# > 1 )); then usage >&2; exit 2; fi
  case $mode in
    -h|--help) usage; return ;;
    ''|--check|--update) ;;
    *) usage >&2; exit 2 ;;
  esac
  require_platform
  local tool
  for tool in rpm file stat readlink; do command -v "$tool" >/dev/null || fail "Missing dependency: $tool"; done
  rpm -q 1password >/dev/null 2>&1 || rpm_status=$?
  [[ $rpm_status == 1 ]] || fail 'RPM installation found or RPM query failed; manage it separately with DNF.'
  if command -v flatpak >/dev/null && flatpak info com.onepassword.OnePassword >/dev/null 2>&1; then
    fail 'Flatpak installation found; manage it separately.'
  fi
  if [[ -e $app_dir || -L $app_dir || -e $launcher || -L $launcher ]]; then
    current=$(installed_version) || fail 'Existing installation has an unexpected layout or version; inspect manually.'
    printf '1Password %s (native ARM64 standalone)\n' "$current"
    if [[ $mode != --update ]]; then
      printf 'Existing installation is ready; no changes.\n'
      return
    fi
  elif [[ $mode == --check ]]; then
    fail '1Password standalone installation is missing.'
  fi
  for tool in curl gpg tar sudo pgrep mktemp sort; do command -v "$tool" >/dev/null || fail "Missing dependency: $tool"; done
  ensure_closed
  umask 077
  work=$(mktemp -d)
  # The path is captured now, not looked up after main's locals go out of scope.
  trap "rm -rf -- $(printf '%q' "$work")" EXIT
  local -a download=(curl --disable --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --retry 2)
  "${download[@]}" "$base_url/keys/1password.asc" -o "$work/key.asc"
  "${download[@]}" "$archive_url.sig" -o "$work/archive.sig"
  "${download[@]}" "$archive_url" -o "$work/archive.tar.gz"
  verify_archive "$work"
  mkdir -- "$work/extracted"
  # The private parent protects staging; preserve normal vendor read/execute modes.
  (umask 022; tar -xf "$work/archive.tar.gz" -C "$work/extracted" --no-same-owner --no-same-permissions)
  local -a entries
  shopt -s nullglob dotglob
  entries=("$work/extracted"/*)
  shopt -u nullglob dotglob
  (( ${#entries[@]} == 1 )) || fail 'Unexpected archive layout.'
  candidate=${entries[0]}
  name=${candidate##*/}
  [[ -d $candidate && ! -L $candidate && $name =~ ^1password-([0-9]+\.[0-9]+\.[0-9]+)\.arm64$ ]] ||
    fail 'Unexpected archive name; review the vendor format before updating.'
  local version=${BASH_REMATCH[1]}
  [[ -f $candidate/1password && ! -L $candidate/1password && -x $candidate/1password &&
    -f $candidate/after-install.sh && ! -L $candidate/after-install.sh && -x $candidate/after-install.sh ]] ||
    fail 'Archive is missing expected executable files.'
  native_binary "$candidate/1password" || fail 'Archive does not contain an ARM64 executable.'
  if [[ -n $current ]]; then
    if [[ $current == "$version" ]]; then printf 'Already on stable %s; no changes.\n' "$current"; return; fi
    [[ $(printf '%s\n' "$current" "$version" | sort -V | tail -n 1) == "$version" ]] || fail 'Refusing to downgrade.'
  fi
  install_tree "$candidate" "$current" "$version"
  printf 'Installation complete. Open 1Password as your regular user.\n'
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then main "$@"; fi

#!/usr/bin/env bash
# Offline tests; no real sudo, downloads or /opt changes.
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
# shellcheck source=fedora/1password.sh
source fedora/1password.sh
workdir=$(mktemp -d)
trap 'rm -rf -- "$workdir"' EXIT
fail_test() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
expect_failure() {
  # Expected failures use explicit fail exits; isolate them in a subshell.
  local result=0
  ( "$@" ) >"$workdir/error" 2>&1 || result=$?
  [[ $result != 0 ]] || fail_test "unexpected success: $*"
}

# Exercise the actual distribution predicate before mocking the platform guard.
for os_id in fedora fedora-asahi-remix '"fedora"' '"fedora-asahi-remix"'; do
  printf 'ID=%s\n' "$os_id" >"$workdir/os-release"
  is_supported_fedora "$workdir/os-release" || fail_test "rejected OS: $os_id"
done
for os_id in debian linuxmint fedora-other fedora-asahi-remix-extra '"fedora' 'fedora"'; do
  printf 'ID=%s\nID_LIKE=fedora\n' "$os_id" >"$workdir/os-release"
  expect_failure is_supported_fedora "$workdir/os-release"
done
printf 'ID_LIKE=fedora\n' >"$workdir/os-release"
expect_failure is_supported_fedora "$workdir/os-release"

# Exercise the real detached signature verification with a disposable test key.
mkdir -m 700 "$workdir/signer"
gpg --batch --homedir "$workdir/signer" --passphrase '' --quick-gen-key 'Fixture <fixture@example.invalid>' ed25519 sign 0 >/dev/null 2>&1
fixture_key=$(gpg --batch --homedir "$workdir/signer" --with-colons --list-keys | awk -F: '$1=="fpr" {print $10; exit}')
for case_name in good wrong tampered; do
  mkdir "$workdir/$case_name"
  printf 'fixture archive\n' >"$workdir/$case_name/archive.tar.gz"
  gpg --batch --homedir "$workdir/signer" --armor --export "$fixture_key" >"$workdir/$case_name/key.asc"
  gpg --batch --homedir "$workdir/signer" --detach-sign --output "$workdir/$case_name/archive.sig" "$workdir/$case_name/archive.tar.gz"
done
(key_fingerprint=$fixture_key; verify_archive "$workdir/good")
expect_failure verify_archive "$workdir/wrong"
printf 'modified\n' >>"$workdir/tampered/archive.tar.gz"
expect_failure bash -c 'source fedora/1password.sh; key_fingerprint=$1; verify_archive "$2"' _ "$fixture_key" "$workdir/tampered"

# Simulate Fedora, an absent RPM, and an existing native installation.
require_platform() { :; }
rpm() { return 1; }
flatpak() { return 1; }
sudo() { fail_test 'unexpected sudo'; }
curl() { fail_test 'unexpected download'; }
file() { printf 'ELF 64-bit LSB pie executable, ARM aarch64\n'; }
stat() { printf '0\n'; }
app_dir=$workdir/installed
launcher=$workdir/launcher
mkdir "$app_dir"
printf '#!/bin/sh\necho 8.12.48\n' >"$app_dir/1password"
printf '#!/bin/sh\nexit 0\n' >"$app_dir/after-install.sh"
chmod +x "$app_dir/1password" "$app_dir/after-install.sh"
ln -s "$app_dir/1password" "$launcher"
main --check
main
rm "$launcher"
expect_failure main --check
expect_failure main
ln -s "$app_dir/1password" "$launcher"
(rpm() { return 0; }; expect_failure main --check)
(file() { printf 'ELF 64-bit LSB executable, x86-64\n'; }; expect_failure main --check)
rm "$launcher"
rm -r "$app_dir"
expect_failure main --check

# Test staged replacement and failed vendor hook recovery in a fake /opt.
# Stub only privileged operations; the moves and copies actually happen.
(
  app_dir=$workdir/target
  launcher=$workdir/target-launcher
  stage_dir=$workdir/stage
  mkdir "$app_dir" "$workdir/new-release"
  printf '#!/bin/sh\necho 8.12.48\n' >"$app_dir/1password"
  printf '#!/bin/sh\nexit 0\n' >"$app_dir/after-install.sh"
  printf '#!/bin/sh\necho 8.12.49\n' >"$workdir/new-release/1password"
  printf '#!/bin/sh\nexit 1\n' >"$workdir/new-release/after-install.sh"
  chmod +x "$app_dir/"* "$workdir/new-release/"*
  ln -s "$app_dir/1password" "$launcher"
  ensure_closed() { :; }
  sudo() {
    if [[ $1 == mktemp ]]; then mkdir "$stage_dir"; printf '%s\n' "$stage_dir"; else "$@"; fi
  }
  expect_failure install_tree "$workdir/new-release" 8.12.48 8.12.49
  [[ $(installed_version) == 8.12.48 && -d $stage_dir/failed ]] || fail_test 'rollback'
  rm -r "$stage_dir"
  printf '#!/bin/sh\nexit 0\n' >"$workdir/new-release/after-install.sh"
  install_tree "$workdir/new-release" 8.12.48 8.12.49
  [[ $(installed_version) == 8.12.49 && ! -e $stage_dir ]] || fail_test 'replacement'
)
printf 'Fedora ARM64 1Password regression checks passed.\n'

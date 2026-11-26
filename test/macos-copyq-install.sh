#!/usr/bin/env bash
# Offline tests for the pinned CopyQ macOS installer. No network or real app changes.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
INSTALLER="$ROOT/macos/copyq-install.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/macos-copyq-test.XXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT

export HOME="$TMP/home"
export COPYQ_APP_PATH="$TMP/Applications/CopyQ.app"
export COPYQ_CLI_LINK="$HOME/.local/bin/copyq"
export MOCK_CODESIGN_VALID="$TMP/codesign-valid"
export MOCK_CHECKSUM_FILE="$TMP/checksums-sha512.txt"
export MOCK_DMGS="$TMP/dmgs"
mkdir -p "$HOME/.local/bin" "$TMP/mock" "$COPYQ_APP_PATH/Contents/MacOS" "$MOCK_DMGS"
printf '#!/bin/sh\nexit 0\n' > "$COPYQ_APP_PATH/Contents/MacOS/CopyQ"
touch "$COPYQ_APP_PATH/Contents/Info.plist" "$MOCK_CODESIGN_VALID"
chmod +x "$COPYQ_APP_PATH/Contents/MacOS/CopyQ"

cat > "$TMP/mock/uname" <<'MOCK'
#!/bin/sh
case "$1" in
  -s) echo Darwin ;;
  -m) echo arm64 ;;
  *) echo Darwin ;;
esac
MOCK
cat > "$TMP/mock/defaults" <<'MOCK'
#!/bin/sh
printf '%s\n' "${MOCK_COPYQ_VERSION:-17.0.0}"
MOCK
cat > "$TMP/mock/sw_vers" <<'MOCK'
#!/bin/sh
echo 26.7.3
MOCK
cat > "$TMP/mock/codesign" <<'MOCK'
#!/bin/bash
set -euo pipefail
case "$1" in
  --verify)
    [[ -f "$MOCK_CODESIGN_VALID" ]]
    ;;
  -dv)
    if [[ -f "$MOCK_CODESIGN_VALID" ]]; then echo 'Signature=adhoc'; else echo 'Signature=invalid'; fi
    ;;
  --force)
    [[ "${MOCK_CODESIGN_FAIL_SIGN:-0}" != 1 ]] || exit 1
    touch "$MOCK_CODESIGN_VALID"
    ;;
  *) exit 2 ;;
esac
MOCK
cat > "$TMP/mock/xattr" <<'MOCK'
#!/bin/bash
set -euo pipefail
case "$1" in
  -p)
    path=$3
    marker="$path.mock-quarantine"
    [[ -f "$marker" ]] || exit 1
    echo '0081;00000000;MockBrowser;'
    ;;
  -w)
    path=$4
    marker="$path.mock-quarantine"
    touch "$marker"
    ;;
  -d)
    path=$3
    marker="$path.mock-quarantine"
    rm -f "$marker"
    ;;
  *) exit 2 ;;
esac
MOCK
cat > "$TMP/mock/pgrep" <<'MOCK'
#!/bin/sh
exit 1
MOCK
cat > "$TMP/mock/open" <<'MOCK'
#!/bin/sh
exit 0
MOCK
cat > "$TMP/mock/curl" <<'MOCK'
#!/bin/bash
set -euo pipefail
output=''
while (($#)); do
  case "$1" in
    --output) output=$2; shift 2 ;;
    *) shift ;;
  esac
done
cp "$MOCK_CHECKSUM_FILE" "$output"
MOCK
cat > "$TMP/mock/hdiutil" <<'MOCK'
#!/bin/bash
set -euo pipefail
if [[ "$1" == attach ]]; then
  shift
  mount_point=''
  while (($#)); do
    if [[ "$1" == -mountpoint ]]; then mount_point=$2; shift 2; else shift; fi
  done
  mkdir -p "$mount_point/CopyQ.app/Contents/MacOS"
  printf '#!/bin/sh\nexit 0\n' > "$mount_point/CopyQ.app/Contents/MacOS/CopyQ"
  touch "$mount_point/CopyQ.app/Contents/Info.plist"
  chmod +x "$mount_point/CopyQ.app/Contents/MacOS/CopyQ"
elif [[ "$1" == detach ]]; then
  exit 0
else
  exit 2
fi
MOCK
cat > "$TMP/mock/ditto" <<'MOCK'
#!/bin/sh
cp -R "$1" "$2"
MOCK
cat > "$TMP/mock/mv" <<'MOCK'
#!/bin/bash
set -euo pipefail
source_path=$1
destination_path=$2
/bin/mv "$source_path" "$destination_path"
if [[ -f "$source_path.mock-quarantine" ]]; then
  /bin/mv "$source_path.mock-quarantine" "$destination_path.mock-quarantine"
fi
MOCK
chmod +x "$TMP/mock/"*
export PATH="$TMP/mock:$PATH"

# Existing app is not ready until the CLI link points to its exact executable.
status=0
output=$(bash "$INSTALLER" --check 2>&1) || status=$?
[[ "$status" == 1 && "$output" == *'CopyQ CLI link is missing or incorrect'* ]]
ln -s "$COPYQ_APP_PATH/Contents/MacOS/CopyQ" "$COPYQ_CLI_LINK"
output=$(bash "$INSTALLER" --check 2>&1)
[[ "$output" == *'OK: CopyQ 17.0.0 installed'* ]]
[[ "$output" == *'code signature integrity passes (ad-hoc'* ]]

# Strict signature verification is part of --check.
rm "$MOCK_CODESIGN_VALID"
status=0
output=$(bash "$INSTALLER" --check 2>&1) || status=$?
[[ "$status" == 1 && "$output" == *'nested code-signature integrity verification failed'* ]]
[[ "$output" == *'repair-signature'* ]]
touch "$MOCK_CODESIGN_VALID"

# macOS can omit the trailing zero in CFBundleShortVersionString.
output=$(MOCK_COPYQ_VERSION=17.0 bash "$INSTALLER" --check 2>&1)
[[ "$output" == *'OK: CopyQ 17.0 installed'* ]]

# A version mismatch is reported without changing the app or link.
status=0
output=$(MOCK_COPYQ_VERSION=16.0.0 bash "$INSTALLER" --check 2>&1) || status=$?
[[ "$status" == 1 && "$output" == *'version mismatch'* ]]
for version in 17.0.1 17.1 17 17.0.0-beta; do
  status=0
  output=$(MOCK_COPYQ_VERSION="$version" bash "$INSTALLER" --check 2>&1) || status=$?
  [[ "$status" == 1 && "$output" == *'version mismatch'* ]]
done
[[ -L "$COPYQ_CLI_LINK" && -x "$COPYQ_APP_PATH/Contents/MacOS/CopyQ" ]]

# Invalid options are rejected before any installation attempt.
status=0
bash "$INSTALLER" --unknown >/dev/null 2>&1 || status=$?
[[ "$status" == 2 ]]

if [[ $EUID -ne 0 ]]; then
  # The installer refuses to replace an unrelated CLI path.
  rm "$COPYQ_CLI_LINK"
  printf 'keep me\n' > "$COPYQ_CLI_LINK"
  status=0
  output=$(printf 'INSTALL COPYQ\n' | bash "$INSTALLER" install 2>&1) || status=$?
  [[ "$status" == 1 && "$output" == *'Refusing to replace an existing CLI path'* ]]
  [[ -f "$COPYQ_CLI_LINK" && ! -L "$COPYQ_CLI_LINK" ]]
  rm "$COPYQ_CLI_LINK"

  # Prepare a quarantined mock DMG and its official-style checksum manifest.
  export COPYQ_APP_PATH="$TMP/install/Applications/CopyQ.app"
  export COPYQ_CLI_LINK="$TMP/install/home/.local/bin/copyq"
  export COPYQ_DMG_PATH="$TMP/Downloads/CopyQ-17.0.0-macos-13-m1.dmg"
  rm -f "$MOCK_CODESIGN_VALID"
  mkdir -p "$(dirname "$COPYQ_DMG_PATH")"
  printf 'mock CopyQ DMG payload\n' > "$COPYQ_DMG_PATH"
  touch "$COPYQ_DMG_PATH.mock-quarantine"
  hash=$(shasum -a 512 "$COPYQ_DMG_PATH" | awk '{print $1}')
  printf '%s  %s\n' "$hash" "${COPYQ_DMG_PATH##*/}" > "$MOCK_CHECKSUM_FILE"

  # Install repairs only the exact stale symlink generated by this installer.
  mkdir -p "$(dirname "$COPYQ_CLI_LINK")"
  ln -s "$COPYQ_APP_PATH/Contents/MacOS/CopyQ" "$COPYQ_CLI_LINK"
  printf 'INSTALL COPYQ\n' | MOCK_COPYQ_VERSION=17.0 bash "$INSTALLER" install > "$TMP/install.log"
  grep -F 'Removing recognized stale CopyQ CLI symlink' "$TMP/install.log"
  [[ -x "$COPYQ_APP_PATH/Contents/MacOS/CopyQ" ]]
  [[ -L "$COPYQ_CLI_LINK" && "$COPYQ_CLI_LINK" -ef "$COPYQ_APP_PATH/Contents/MacOS/CopyQ" ]]
  [[ -f "$COPYQ_APP_PATH.mock-quarantine" && ! -f "$MOCK_CODESIGN_VALID" ]]

  # An unrelated dangling symlink is preserved and blocks installation.
  export COPYQ_APP_PATH="$TMP/unrelated/Applications/CopyQ.app"
  export COPYQ_CLI_LINK="$TMP/unrelated/home/.local/bin/copyq"
  mkdir -p "$(dirname "$COPYQ_CLI_LINK")"
  ln -s "$TMP/not-copyq" "$COPYQ_CLI_LINK"
  status=0
  output=$(printf 'INSTALL COPYQ\n' | bash "$INSTALLER" install 2>&1) || status=$?
  [[ "$status" == 1 && "$output" == *'Refusing to replace unrelated dangling CLI symlink'* ]]
  [[ -L "$COPYQ_CLI_LINK" && "$(readlink "$COPYQ_CLI_LINK")" == "$TMP/not-copyq" ]]

  # Signature repair requires a verified, quarantined release DMG and an exact
  # content match between the installed app and the release bundle.
  export COPYQ_APP_PATH="$TMP/install/Applications/CopyQ.app"
  export COPYQ_CLI_LINK="$TMP/install/home/.local/bin/copyq"
  rm -f "$MOCK_CODESIGN_VALID"
  cp "$COPYQ_APP_PATH/Contents/MacOS/CopyQ" "$TMP/CopyQ.original"
  printf '# unexpected modification\n' >> "$COPYQ_APP_PATH/Contents/MacOS/CopyQ"
  status=0
  output=$(printf 'REPAIR COPYQ SIGNATURE\n' | bash "$INSTALLER" repair-signature 2>&1) || status=$?
  [[ "$status" == 1 && "$output" == *'Installed CopyQ differs from the verified DMG'* ]]
  [[ -f "$COPYQ_APP_PATH.mock-quarantine" && ! -f "$MOCK_CODESIGN_VALID" ]]
  cp "$TMP/CopyQ.original" "$COPYQ_APP_PATH/Contents/MacOS/CopyQ"

  cp "$COPYQ_DMG_PATH" "$TMP/CopyQ-DMG.original"
  printf 'tampered\n' >> "$COPYQ_DMG_PATH"
  status=0
  output=$(printf 'REPAIR COPYQ SIGNATURE\n' | bash "$INSTALLER" repair-signature 2>&1) || status=$?
  [[ "$status" == 1 && "$output" == *'CopyQ DMG SHA-512 verification failed'* ]]
  [[ -f "$COPYQ_APP_PATH.mock-quarantine" && ! -f "$MOCK_CODESIGN_VALID" ]]
  cp "$TMP/CopyQ-DMG.original" "$COPYQ_DMG_PATH"

  status=0
  output=$(printf 'REPAIR COPYQ SIGNATURE\n' | MOCK_CODESIGN_FAIL_SIGN=1 bash "$INSTALLER" repair-signature 2>&1) || status=$?
  [[ "$status" == 1 && "$output" == *'Ad-hoc signing failed'* ]]
  [[ -f "$COPYQ_APP_PATH.mock-quarantine" && ! -f "$MOCK_CODESIGN_VALID" ]]

  printf 'REPAIR COPYQ SIGNATURE\n' | bash "$INSTALLER" repair-signature > "$TMP/repair.log"
  grep -F 'OK: installed app contents match the checksum-verified release bundle.' "$TMP/repair.log"
  grep -F 'OK: nested code signatures pass strict integrity verification.' "$TMP/repair.log"
  [[ -f "$MOCK_CODESIGN_VALID" ]]
  [[ ! -f "$COPYQ_APP_PATH.mock-quarantine" ]]
  output=$(bash "$INSTALLER" --check 2>&1)
  [[ "$output" == *'code signature integrity passes (ad-hoc'* ]]
  output=$(bash "$INSTALLER" repair-signature 2>&1)
  [[ "$output" == *'No signature repair is needed'* ]]

  # Repair refuses to run while CopyQ is active.
  cat > "$TMP/mock/pgrep" <<'MOCK'
#!/bin/sh
exit 0
MOCK
  chmod +x "$TMP/mock/pgrep"
  rm -f "$MOCK_CODESIGN_VALID"
  status=0
  output=$(printf 'REPAIR COPYQ SIGNATURE\n' | bash "$INSTALLER" repair-signature 2>&1) || status=$?
  [[ "$status" == 1 && "$output" == *'Quit CopyQ before signature repair'* ]]
else
  status=0
  output=$(printf 'INSTALL COPYQ\n' | bash "$INSTALLER" install 2>&1) || status=$?
  [[ "$status" == 1 && "$output" == *'Run as your normal user, not with sudo'* ]]
  printf '%s\n' 'Root detected; mock install/repair paths skipped (production installer refuses root).'
fi

printf '%s\n' 'macos-copyq-install_test: ok'

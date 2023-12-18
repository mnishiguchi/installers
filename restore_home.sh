#!/bin/bash
#
# Restore home directory from specified back-up disk.
#
# ## Examples
#
#   restore_home.sh "/media/mnishiguchi/USBBACKUP1/MBA-Debian/home-mnishiguchi"
#
set -e

SOURCE_DIR="$1"

if [ -z "$SOURCE_DIR" ] || [ ! -d "$SOURCE_DIR" ]; then
  echo "error: source directory \"$SOURCE_DIR\" not found -- aborting"
  find "/media/$USER" >/dev/null 2>&1
  exit 1
fi

TARGET_DIR="$HOME/"

LOG_DIR="$HOME/.rsync"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/restore-home-$(date +'%Y-%m').log"

RSYNC_ARGS=(
  -avhP
  --log-file="$LOG_FILE"
)

if echo "$*" | grep -q "dry-run"; then
  RSYNC_ARGS+=(--dry-run)
fi

RSYNC_ARGS+=(
  "$SOURCE_DIR"
  "$TARGET_DIR"
)

rsync "${RSYNC_ARGS[@]}"

#!/bin/bash
#
# Copy home directory to specified back-up disk.
#
# ## Examples
#
#   backup_home.sh "/media/$USER/USBBACKUP1"
#   backup_home.sh "/media/$USER/USBBACKUP1" --dry-run
#
set -e

BACKUP_DISK="$1"

if [ -z "$BACKUP_DISK" ] || [ ! -d "$BACKUP_DISK" ]; then
  echo "error: backup disk \"$BACKUP_DISK\" not found -- aborting"
  find "/media/$USER" >/dev/null 2>&1
  exit 1
fi

SOURCE_DIR="$HOME/"

TARGET_DIR="$BACKUP_DISK/backups/$(hostname)/home_$(whoami)/$(date +'%F')/"
mkdir -p "$TARGET_DIR"

LOG_DIR="$HOME/.rsync"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/backup_home.log"

RSYNC_ARGS=(
  -avhP
  --exclude={'.asdf','.cache','.hex','.mozilla','.oh-my-zsh','.vim','Downloads','tmp'}
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

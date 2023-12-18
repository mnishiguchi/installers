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
  find "/run/media/$USER" >/dev/null 2>&1
  exit 1
fi

SOURCE_DIR="$HOME"

get_hostname() {
  if command -v hostname >/dev/null 2>&1; then
    # debian
    hostname
  else
    # archlinux
    cat /proc/sys/kernel/hostname
  fi
}

# directory for synching per month
TARGET_DIR="$BACKUP_DISK/backups/$(get_hostname)/home-$(whoami)/$(date +'%Y-%m')"
mkdir -p "$TARGET_DIR"

# directory for changed files per sync
RSYNC_BACKUP_DIR="${TARGET_DIR}-backups"
mkdir -p "$RSYNC_BACKUP_DIR"

LOG_DIR="$HOME/.rsync"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/backup-home-$(date +'%Y-%m').log"

RSYNC_ARGS=(
  -avhP
  --exclude='.asdf/***'
  --exclude='.cache/***'
  --exclude='.mozilla/***'
  --exclude='.oh-my-zsh/***'
  --exclude='.var/***'
  --exclude='.vim/***'
  --exclude='Downloads/***'
  --exclude='nvim/***'
  --prune-empty-dirs
  --log-file="$LOG_FILE"
  --backup
  --backup-dir="$RSYNC_BACKUP_DIR"
  --suffix="~$(date +'%F-%H%M%S')"
  --delete
  --max-size=10M
)

if echo "$*" | grep -q "dry-run"; then
  RSYNC_ARGS+=(--dry-run)
fi

RSYNC_ARGS+=(
  "$SOURCE_DIR/"
  "$TARGET_DIR/"
)

rsync "${RSYNC_ARGS[@]}"

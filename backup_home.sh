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
  echo "maybe one of these?"
  [ -d "/media/$USER" ] && find "/media/$USER" -mindepth 1 -maxdepth 1 -type d
  [ -d "/run/media/$USER" ] && find "/run/media/$USER" -mindepth 1 -maxdepth 1 -type d
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
  --exclude='.*authority'
  --exclude='.cache/***'
  --exclude='.docker/***'
  --exclude='.*dump'
  --exclude='.*errors'
  --exclude='.gnupg/***'
  --exclude='.hex/***'
  --exclude='.*history'
  --exclude='.*hst'
  --exclude='.*hsts'
  --exclude='.links/***'
  --exclude='.mozilla/***'
  --exclude='.nerves/***'
  --exclude='.npm/***'
  --exclude='.oh-my-zsh/***'
  --exclude='.pki/***'
  --exclude='.rsync/***'
  --exclude='.ssh/***'
  --exclude='.subversion/***'
  --exclude='.var/***'
  --exclude='.vim*'
  --exclude='.vim/***'
  --exclude='.vscode/***'
  --exclude='.vscode-oss/***'
  --exclude='.yarn/***'
  --exclude='.z'
  --exclude='.z.*'
  --exclude='_build/***'
  --exclude='deps/***'
  --exclude='Downloads/***'
  --exclude='Music/***'
  --exclude='nerves_systems/***'
  --exclude='node_modules/***'
  --exclude='nvim/***'
  --exclude='VirtualBox VMs/***'
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

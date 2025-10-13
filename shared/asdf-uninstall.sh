#!/usr/bin/env bash
set -euo pipefail

# Minimal asdf uninstaller
# Usage:
#   ./asdf-uninstall.sh         # remove ~/.asdf/bin/asdf only
#   ./asdf-uninstall.sh --purge # remove the entire ASDF_DATA_DIR (plugins, shims, installs)
#   ./asdf-uninstall.sh --purge --yes  # skip confirmation

ASDF_DATA_DIR="${ASDF_DATA_DIR:-$HOME/.asdf}"
ASDF_BIN_DIR="$ASDF_DATA_DIR/bin"
ASDF_BIN="$ASDF_BIN_DIR/asdf"

log() { printf '\033[34m==>\033[0m %s\n' "$*"; }
ok() { printf '\033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*"; }
die() {
  printf '\033[31m✖ %s\033[0m\n' "$*" >&2
  exit 1
}

confirm() {
  local prompt="${1:-Are you sure?} [y/N]: "
  if [[ "${ASSUME_YES:-}" = "1" ]]; then return 0; fi
  read -r -p "$prompt" ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [--purge] [--yes]

Options:
  --purge   Remove the entire ASDF_DATA_DIR ($ASDF_DATA_DIR), including plugins,
            shims, and installed tool versions. Irreversible.
  --yes     Do not prompt for confirmation (use with --purge in CI).
  --help    Show this help.
EOF
}

PURGE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
  --purge) PURGE=1 ;;
  --yes) export ASSUME_YES=1 ;;
  --help | -h)
    usage
    exit 0
    ;;
  *) die "Unknown option: $1" ;;
  esac
  shift
done

# Guard rails
[[ -n "$ASDF_DATA_DIR" ]] || die "ASDF_DATA_DIR is empty"
case "$ASDF_DATA_DIR" in
"$HOME" | "/") die "Refusing to operate on dangerous path: $ASDF_DATA_DIR" ;;
esac

if ((PURGE)); then
  log "Requested full purge of $ASDF_DATA_DIR"
  confirm "This will DELETE $ASDF_DATA_DIR entirely. Proceed?" || die "Aborted."

  if [[ -d "$ASDF_DATA_DIR" ]]; then
    rm -rf "$ASDF_DATA_DIR"
    ok "Removed $ASDF_DATA_DIR"
  else
    warn "Nothing to remove: $ASDF_DATA_DIR does not exist"
  fi
else
  log "Removing asdf binary only"
  if [[ -x "$ASDF_BIN" ]]; then
    rm -f "$ASDF_BIN"
    ok "Removed $ASDF_BIN"
    # tidy empty bin dir
    rmdir "$ASDF_BIN_DIR" 2>/dev/null || true
  else
    # If asdf is on PATH elsewhere, tell the user
    if command -v asdf >/dev/null 2>&1; then
      warn "asdf is available at: $(command -v asdf)"
      warn "It wasn't installed at $ASDF_BIN; nothing removed."
    else
      warn "asdf binary not found. Nothing to do."
    fi
  fi
fi

cat <<EOF

Next steps (manual):
  • Remove any PATH lines from your shell config, e.g.:
      export ASDF_DATA_DIR="$ASDF_DATA_DIR"
      export PATH="$ASDF_BIN_DIR:\$PATH"
  • Restart your shell:  exec \$SHELL

EOF

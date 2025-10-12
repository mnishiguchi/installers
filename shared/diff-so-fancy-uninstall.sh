#!/usr/bin/env bash
#
# Uninstall diff-so-fancy:
# - Remove ~/.local/bin/diff-so-fancy symlink (or file, with backup)
# - Remove ~/.local/opt/diff-so-fancy repo
# - Show related Git config entries (for manual cleanup if desired)
#
set -euo pipefail

DSF_DIR="${HOME}/.local/opt/diff-so-fancy"
EXEC_PATH="${HOME}/.local/bin/diff-so-fancy"

echo_heading() { echo -e "\n\033[34m$1\033[0m"; }
echo_success() { echo -e " \033[32m✔ $1\033[0m"; }
echo_warn() { echo -e " \033[33m▲ $1\033[0m"; }
echo_failure() { echo -e " \033[31m✖ $1\033[0m"; }

main() {
  echo_heading "Removing launcher..."
  if [ -L "${EXEC_PATH}" ]; then
    rm -f "${EXEC_PATH}"
    echo_success "Removed symlink: ${EXEC_PATH}"
  elif [ -f "${EXEC_PATH}" ]; then
    local bak="${EXEC_PATH}.bak.$(date +%s)"
    mv "${EXEC_PATH}" "${bak}"
    echo_warn "Found a regular file at EXEC_PATH. Moved to: ${bak}"
  else
    echo_success "No symlink or file at: ${EXEC_PATH}"
  fi

  echo_heading "Removing cloned repository..."
  if [ -d "${DSF_DIR}" ]; then
    rm -rf "${DSF_DIR}"
    echo_success "Removed directory: ${DSF_DIR}"
  else
    echo_success "Directory not found: ${DSF_DIR}"
  fi

  echo_heading "Verifying command availability..."
  if command -v diff-so-fancy >/dev/null 2>&1; then
    echo_warn "diff-so-fancy is still on PATH (another install may exist)."
  else
    echo_success "diff-so-fancy not found on PATH."
  fi

  echo_heading "Related Git config (for manual cleanup if needed):"
  current_pager="$(git config --global core.pager 2>/dev/null || true)"
  current_diff_filter="$(git config --global interactive.diffFilter 2>/dev/null || true)"
  echo "  core.pager:             ${current_pager:-<unset>}"
  echo "  interactive.diffFilter: ${current_diff_filter:-<unset>}"
  echo
  echo "To unset:"
  echo "  git config --global --unset core.pager             # if it references diff-so-fancy"
  echo "  git config --global --unset interactive.diffFilter # if used before"

  echo_heading "Uninstall complete."
}

main "$@"

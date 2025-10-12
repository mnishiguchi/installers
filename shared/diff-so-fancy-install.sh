#!/usr/bin/env bash
#
# Install or update diff-so-fancy from source and symlink to ~/.local/bin
# - Repo goes to: ~/.local/opt/diff-so-fancy
# - Symlink at:  ~/.local/bin/diff-so-fancy
#
set -euo pipefail

DSF_REPO_URL="https://github.com/so-fancy/diff-so-fancy.git"
DSF_DIR="${HOME}/.local/opt/diff-so-fancy"
EXEC_PATH="${HOME}/.local/bin/diff-so-fancy"

echo_heading()  { echo -e "\n\033[34m$1\033[0m"; }
echo_success()  { echo -e " \033[32m✔ $1\033[0m"; }
echo_warn()     { echo -e " \033[33m▲ $1\033[0m"; }
echo_failure()  { echo -e " \033[31m✖ $1\033[0m"; }

main() {
  echo_heading "Preparing directories..."
  mkdir -p "${HOME}/.local/opt"
  mkdir -p "${HOME}/.local/bin"

  echo_heading "Cloning or updating diff-so-fancy..."
  if [ -d "${DSF_DIR}/.git" ]; then
    if git -C "${DSF_DIR}" pull --ff-only; then
      echo_success "Updated existing repo."
    else
      echo_failure "Failed to update repo. You can remove ${DSF_DIR} and retry."
      exit 1
    fi
  elif [ -d "${DSF_DIR}" ]; then
    echo_warn "${DSF_DIR} exists but is not a git repo. Backing it up."
    mv "${DSF_DIR}" "${DSF_DIR}.bak.$(date +%s)"
    git clone "${DSF_REPO_URL}" "${DSF_DIR}"
    echo_success "Cloned repo."
  else
    git clone "${DSF_REPO_URL}" "${DSF_DIR}"
    echo_success "Cloned repo."
  fi

  echo_heading "Creating symlink in ~/.local/bin..."
  if [ -L "${EXEC_PATH}" ] || [ -f "${EXEC_PATH}" ]; then
    if [ ! -L "${EXEC_PATH}" ]; then
      echo_warn "${EXEC_PATH} exists and is not a symlink. Backing it up."
      mv "${EXEC_PATH}" "${EXEC_PATH}.bak.$(date +%s)"
    else
      rm -f "${EXEC_PATH}"
    fi
  fi

  ln -s "${DSF_DIR}/diff-so-fancy" "${EXEC_PATH}"
  chmod +x "${DSF_DIR}/diff-so-fancy"
  echo_success "Symlinked: ${EXEC_PATH} -> ${DSF_DIR}/diff-so-fancy"

  echo_heading "Validating PATH and command..."
  if ! command -v diff-so-fancy >/dev/null 2>&1; then
    echo_warn "~/.local/bin may not be on your PATH."
    echo "Add this to your shell rc file if needed:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  else
    echo_success "diff-so-fancy is available on PATH."
  fi

  echo_heading "Done."
  echo "Try:  git diff --color | diff-so-fancy | less -R"
}

main "$@"


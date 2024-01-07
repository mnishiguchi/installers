#!/usr/bin/env bash
set -eu

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export ASDF_DIR="${ASDF_DIR:-$XDG_CONFIG_HOME/.asdf}"

if [[ -d "$ASDF_DIR" ]]; then
  echo "asdf already installed at ${ASDF_DIR}"
else
  git clone https://github.com/asdf-vm/asdf.git "${ASDF_DIR}" --branch v0.13.1
fi

# Note: be sure to do something similart in your .bashrc, .zshrc, etc
# See https://asdf-vm.com/guide/getting-started.html#_3-install-asdf
source "${ASDF_DIR}/asdf.sh"

# Verify that asdf command works
asdf version


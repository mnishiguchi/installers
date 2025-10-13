#!/bin/bash
#
# Uninstall Yazi installed by yazi-install.sh:
# - Removes ~/.local/bin/{yazi,ya}
# - Removes ~/.config/yazi (themes/config)
#
set -Eeuo pipefail

echo_heading() { echo -e "\n\033[34m$1\033[0m"; }
echo_success() { echo -e " \033[32m✔ $1\033[0m"; }
echo_failure() { echo -e " \033[31m✖ $1\033[0m"; }

die() {
  echo_failure "$*"
  exit 1
}

main() {
  local BIN_DIR="$HOME/.local/bin"
  local EXEC_YAZI="$BIN_DIR/yazi"
  local EXEC_YA="$BIN_DIR/ya"
  local CONFIG_DIR="$HOME/.config/yazi"

  echo_heading "Uninstalling Yazi"

  if [[ -f "$EXEC_YAZI" ]]; then
    rm -f "$EXEC_YAZI" && echo_success "Removed: $EXEC_YAZI"
  else
    echo_success "Not found: $EXEC_YAZI"
  fi

  if [[ -f "$EXEC_YA" ]]; then
    rm -f "$EXEC_YA" && echo_success "Removed: $EXEC_YA"
  else
    echo_success "Not found: $EXEC_YA"
  fi

  if [[ -d "$CONFIG_DIR" ]]; then
    rm -rf "$CONFIG_DIR" && echo_success "Removed: $CONFIG_DIR"
  else
    echo_success "Not found: $CONFIG_DIR"
  fi

  echo_heading "Yazi uninstallation complete"
}

main "$@"

#!/bin/sh
set -e

#
# This is a post-install script for setting up the Nerves firmware development
# environment on Ubuntu ARM 64-bit machines.
#

main() {
  # https://stackoverflow.com/a/246128/3837223
  SCRIPT_PATH="$(
    cd -- "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
  )"

  echo "current dir: $(pwd)"
  echo "script path: $SCRIPT_PATH"

  # get the latest package lists
  sudo apt update

  (
    cd "$SCRIPT_PATH"
    sh ./ubuntu/install_xubuntu_desktop.sh
    sh ./ubuntu/install_firefox.sh
    sh ./ubuntu_arm64/install_vs_code.sh
    sh ./ubuntu/install_zsh.sh
    sh ./ubuntu/chsh_zsh.sh
    sh ./ubuntu/install_ohmyzsh.sh
    sh ./install_asdf_zsh.sh
    sh ./install_erlang_and_elixir.sh
    sh ./install_nerves_systems.sh
  )

  echo "Done"
}

main "$@"

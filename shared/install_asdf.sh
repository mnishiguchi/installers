#!/bin/bash
set -e

ASDF_DIR="$HOME/.asdf"

if [ -d "$ASDF_DIR" ]; then
  echo "warning: asdf already installed -- skipping"
  exit 0
fi

git clone https://github.com/asdf-vm/asdf.git "$ASDF_DIR" --branch v0.13.0

[ command -v omz reload ] && omz reload

if ! command -v asdf >/dev/null 2>&1; then
  echo "error: asdf must be installed -- aborting"
  echo "Hints:"
  echo "* Verify installation by running ls ~/.asdf"
  echo "* Verify asdf command is available by running asdf --version"
  echo "* Log out and log back in again to use your new default shell"
  echo "* For more info, see https://asdf-vm.com/guide/getting-started.html"
  exit 1
fi

asdf --version
asdf update

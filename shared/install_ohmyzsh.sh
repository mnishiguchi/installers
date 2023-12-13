#!/bin/bash
set -e

# Install ohmyzsh following the official documentation.
# https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH

if ! command -v zsh >/dev/null 2>&1; then
  echo "error: zsh must be installed -- aborting"
  exit 1
fi

if ! echo "$SHELL" | grep -q "zsh"; then
  echo "error: default shell must be zsh: $SHELL - aborting"
  echo "Hints:"
  echo "* Verify installation by running zsh --version"
  echo "* Make it your default shell: chsh -s \$(which zsh)"
  echo "* Log out and log back in again to use your new default shell"
  echo "* For more info, see https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH"
  exit 1
fi

if [ -d "$ZSH" ]; then
  echo "warning: ohmyzsh already installed -- skipping"
  exit 0
fi

# Expected result: 'zsh 5.8' or similar
echo "$SHELL"
zsh --version

# https://ohmyz.sh/#install
# https://github.com/ohmyzsh/ohmyzsh/tree/master#unattended-install
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

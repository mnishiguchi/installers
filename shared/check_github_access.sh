#!/usr/bin/env bash
set -eu

# https://unix.stackexchange.com/questions/253376/open-command-to-open-a-file-in-an-application
if ! command -v open &>/dev/null; then
  open() {
    for i in "$@"; do
      setsid nohup xdg-open "$i" &>/dev/null
    done
  }
fi

# Exit code is expected to be 1 according to the Github documentation
# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection
if ! ssh -T git@github.com; then
  if [[ "$?" -ge 2 ]]; then
    echo "Please add the SSH public key to your GitHub profile's SSH key list at https://github.com/settings/keys"
    open https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup
    open https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
    open https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account
    open https://github.com/settings/keys
    exit 1
  fi
fi

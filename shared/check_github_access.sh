#!/bin/bash
set -eu

# Exit code is expected to be 1 according to the Github documentation, so
# ignore the error by using "|| true" and use the last result for branching.
# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/testing-your-ssh-connection
ssh -T git@github.com && result=0 || result=$?
true

if [ "$result" -lt 2 ]; then
  echo "ok"
  exit 0
fi

echo "error: Please add the SSH public key to your GitHub profile's SSH key list at https://github.com/settings/keys"
open https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup
open https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
open https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account
open https://github.com/settings/keys
exit 1

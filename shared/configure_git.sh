#!/bin/bash
set -eu

file="${HOME}/.gitconfig"
if [ ! -f "${file}" ]; then
  echo "${file} not found, creating one..."

  git config --global user.name "Masatoshi Nishiguchi"
  git config --global user.email "7563926+mnishiguchi@users.noreply.github.com"
  git config --global github.user "mnishiguchi"
  git config --global credential.helper "osxkeychain"
  git config --global core.excludesfile "${HOME}/.gitignore"
  git config --global core.ignorecase false
  git config --global core.pager "diff-so-fancy | less --tabs=4 -RFX"
  git config --global core.editor "nvim"
  git config --global init.defaultBranch "main"
  git config --global commit.template "${HOME}/.gitmessage"
  git config --global fetch.prune true
  git config --global interactive.diffFilter "diff-so-fancy --patch"

  open https://git-scm.com/book/en/v2/Getting-Started-First-Time-Git-Setup

  cat "${file}"
fi

file="${HOME}/.gitignore"
if [ ! -f "${file}" ]; then
  echo "${file} not found, creating one..."
  gitignore_src="https://gist.githubusercontent.com/mnishiguchi/e164a451269f8ffb9e9681bb532147f4/raw/539cd0dbbde46ef3ff2d964926813889dd28dc0c/gitignore_global"
  curl --output "${file}" --location "${gitignore_src}"
  cat "${file}"
fi

file="${HOME}/.gitmessage"
if [ ! -f "${file}" ]; then
  echo "${file} not found, creating one..."
  gitmessage_src="https://gist.githubusercontent.com/mnishiguchi/a96daf18ff6dd8b39da2aa4dd89be1fa/raw/9f08a6b0ed2beb6872b6db9c876860b9eaa43042/gitmessage.txt"
  curl --output "${file}" --location "${gitmessage_src}"
  cat "${file}"
fi

git config --global --list

